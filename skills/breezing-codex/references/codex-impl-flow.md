# Codex Implementation Flow

Codex Implementer の詳細な実行フロー。Codex MCP 呼び出しから Quality Gates 検証までの全ステップ。

## Overview

```
Codex Implementer (Agent Teams Teammate)
    │
    ├─ 1. base-instructions 生成
    │     - .claude/rules/*.md 収集・連結
    │     - AGENTS.md 準拠指示
    │     - AGENTS_SUMMARY 証跡出力要求
    │     - owns ファイル制約
    │
    ├─ 2. Worktree 準備（Lead が worktree モード指示時）
    │     - git worktree add
    │     - cwd を worktree パスに設定
    │
    ├─ 3. Codex MCP 呼び出し
    │     → mcp__codex__codex({prompt, base-instructions, cwd, ...})
    │
    ├─ 4. AGENTS_SUMMARY 検証
    │     - 証跡抽出 + SHA256 ハッシュ照合
    │     - 欠落: 即失敗
    │     - 不一致: リトライ（最大3回）
    │
    ├─ 5. Quality Gates
    │     - lint, type-check, test, 改ざん検出
    │     - 失敗: Codex に修正指示 → 再呼び出し
    │
    └─ 6. マージ（worktree 使用時）
          - cherry-pick to main branch
          - worktree 削除
```

## Step 1: base-instructions 生成

### 収集対象

```bash
# .claude/rules/ 配下の全 .md ファイル
.claude/rules/test-quality.md
.claude/rules/implementation-quality.md
.claude/rules/skill-editing.md
...
```

### テンプレート

```markdown
## プロジェクトルール

{.claude/rules/*.md の連結内容}

## 必須: AGENTS.md 準拠

最初に AGENTS.md を読み、以下の形式で証跡を出力してください:
AGENTS_SUMMARY: <1行要約> | HASH:<SHA256先頭8文字>

証跡を出力せずに作業を開始しないでください。

## ファイル制約

以下のファイルのみ編集してください:
- {owns[0]}
- {owns[1]}
- ...

上記以外のファイルを編集しないでください。

## 禁止事項

- git commit は実行しない
- Codex の再帰呼び出し禁止
- eslint-disable の追加禁止
- テストの改ざん（it.skip, アサーション削除）禁止
```

## Step 2: Worktree 準備

Lead が worktree モードを指示した場合のみ実行。

```bash
# worktree 作成
git worktree add ../worktrees/codex-{task-id} HEAD

# cwd を worktree に設定
CWD="../worktrees/codex-{task-id}"
```

### owns: モードの場合

worktree を作成せず、プロジェクトルートを cwd として使用。
ファイル制約は base-instructions 内の「ファイル制約」セクションで制御。

## Step 3: Codex MCP 呼び出し

### パラメータ

```json
{
  "prompt": "{タスク説明}\n\n---\n\n{AGENTS_SUMMARY 証跡出力指示}",
  "base-instructions": "{Step 1 で生成した base-instructions}",
  "cwd": "{worktree パス or プロジェクトルート}",
  "approval-policy": "never",
  "sandbox": "workspace-write"
}
```

### prompt 構成

```markdown
## タスク

{TaskList から取得したタスク description}

## 対象ファイル

owns: {ファイルパターンリスト}

## 実装要件

- 既存コードのパターンに従うこと
- テストを追加または更新すること
- ビルドが通る状態にすること

---

## 必須出力

作業開始時に以下を出力してください:
AGENTS_SUMMARY: <AGENTS.md の1行要約> | HASH:<SHA256先頭8文字>
```

### 呼び出し例

```
mcp__codex__codex({
  prompt: "ログイン機能を実装してください。\n\nowns: src/auth/*, src/pages/login.tsx\n\n...",
  base-instructions: "## プロジェクトルール\n...",
  cwd: "../worktrees/codex-task-1",
  approval-policy: "never",
  sandbox: "workspace-write"
})
```

## Step 4: AGENTS_SUMMARY 検証

### 検証ロジック

```
1. Codex 出力から正規表現で証跡を抽出:
   /AGENTS_SUMMARY:\s*(.+?)\s*\|\s*HASH:([A-Fa-f0-9]{8})/

2. AGENTS.md の SHA256 ハッシュを計算:
   - BOM 除去
   - 全行 LF 正規化
   - SHA256 Hex 小文字
   - 先頭 8 文字

3. 照合
```

### 結果ハンドリング

| 結果 | アクション | リトライ |
|------|-----------|---------|
| 証跡あり + ハッシュ一致 | Step 5 へ | - |
| 証跡あり + ハッシュ不一致 | リトライ（指示を明確化） | 最大 3 回 |
| 証跡欠落 | 即失敗 → Lead にエスカレーション | なし |

### リトライ時の段階的指示

```
1回目: 通常の prompt で呼び出し
2回目: "AGENTS_SUMMARY を必ず最初に出力してください" と強調
3回目: "以下の形式で出力: AGENTS_SUMMARY: ... | HASH:..." と具体例追加
4回目: 失敗 → Lead にエスカレーション
```

## Step 5: Quality Gates

### Gate 実行順序

```
Gate 1: lint チェック
  │
  ├── pass → Gate 2 へ
  └── fail → Codex に修正指示 → 再呼び出し
  │
Gate 2: 型チェック
  │
  ├── pass → Gate 3 へ
  └── fail → Codex に修正指示 → 再呼び出し
  │
Gate 3: テスト実行
  │
  ├── pass → Step 6 へ
  └── fail → 改ざん検出チェック
       │
       ├── 改ざんあり → 即停止 → Lead にエスカレーション
       └── 改ざんなし → Codex に修正指示 → 再呼び出し
```

### 各 Gate の詳細

| Gate | コマンド | 失敗時 | 最大リトライ |
|------|---------|--------|------------|
| lint | `npm run lint` / `pnpm lint` | 自動修正指示 | 3 回 |
| type-check | `tsc --noEmit` | 型エラー修正指示 | 3 回 |
| test | `npm test` | テスト修正指示 | 3 回 |
| tamper | パターン検出 | 即停止 | 0（リトライなし） |

### 改ざん検出パターン

| パターン | 検出方法 |
|---------|---------|
| `it.skip()`, `test.skip()` | diff で新規追加を検出 |
| アサーション削除 | diff で `expect(` 行の減少を検出 |
| `eslint-disable` 追加 | diff で新規追加を検出 |
| ハードコード期待値 | 実装と期待値の一致パターン |

### Quality Gate 失敗時の Codex 再呼び出し

```json
{
  "prompt": "前回の実装で以下の問題が見つかりました。修正してください:\n\n{エラーログ}\n\n元のタスク: {タスク説明}",
  "base-instructions": "{同一の base-instructions}",
  "cwd": "{同一の cwd}",
  "approval-policy": "never",
  "sandbox": "workspace-write"
}
```

## Step 6: マージ（worktree 使用時）

### 手順

```bash
# 1. worktree でコミット作成（ローカルのみ）
cd ../worktrees/codex-{task-id}
git add -A
git commit -m "feat: {task description}"

# 2. メインブランチに cherry-pick
cd {project-root}
git cherry-pick {commit-hash}

# 3. worktree 削除
git worktree remove ../worktrees/codex-{task-id}
```

### 競合発生時

```
cherry-pick で競合発生
    ↓
Lead に SendMessage:
  "タスク X のマージで競合が発生しました。
   競合ファイル: {ファイルリスト}
   ユーザー判断が必要です。"
    ↓
Lead → ユーザーにエスカレーション
```

## エラーハンドリング総括

| エラー | 対応 | リトライ | エスカレーション先 |
|--------|------|---------|-----------------|
| AGENTS_SUMMARY 欠落 | 即失敗 | 0 | Lead |
| ハッシュ不一致 | 段階的指示で再呼び出し | 3 | Lead |
| lint 失敗 | 自動修正指示 | 3 | Lead |
| 型エラー | 修正指示 | 3 | Lead |
| テスト失敗 | 修正指示 | 3 | Lead |
| 改ざん検出 | 即停止 | 0 | Lead |
| マージ競合 | cherry-pick 中断 | 0 | Lead → ユーザー |
| Codex MCP 接続失敗 | 即失敗 | 0 | Lead → ユーザー |

## リテイク時の Codex 呼び出し

Reviewer の findings に基づく修正タスクを受け取った場合:

```json
{
  "prompt": "以下のレビュー指摘に対応してください:\n\n{findings JSON}\n\n---\n\n元の実装コンテキスト:\n{タスク説明}\n\n---\n\n{AGENTS_SUMMARY 証跡出力指示}",
  "base-instructions": "{同一の base-instructions}",
  "cwd": "{同一の cwd}",
  "approval-policy": "never",
  "sandbox": "workspace-write"
}
```

> **ポイント**: リテイク時は Reviewer の findings を prompt に含めることで、
> Codex が正確に修正箇所を把握できる。
