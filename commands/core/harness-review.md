---
description: コードレビュー（組み込み review との衝突回避）
description-en: Code review (multi-perspective security/performance/quality)
context: fork
hooks:
  - event: PreCommandInvoke
    type: command
    command: "${CLAUDE_PLUGIN_ROOT}/scripts/check-codex.sh"
    once: true
---

# /harness-review - コードレビュー（ソロモード）

作成したコードの品質をチェックします。
複数の観点から分析し、改善点を提案します。

---

## 💡 バイブコーダー向けの使い方

**このコマンドは、技術的な知識がなくても高品質なコードレビューを受けられるように設計されています。**

- ✅ セキュリティの問題を自動検出
- ✅ パフォーマンスの改善点を提案
- ✅ コード品質を自動チェック
- ✅ アクセシビリティ対応を確認

**受託開発で重要**: クライアントに安心してもらうため、レビュー結果をレポートとして提出できます

---

## 🔧 自動呼び出しスキル（必須）

**このコマンドは以下のスキルを Skill ツールで明示的に呼び出すこと**：

| スキル | 用途 | 呼び出しタイミング |
|-------|------|------------------|
| `review` | レビュー（親スキル） | レビュー開始時 |
| `codex-review` | Codex セカンドオピニオン | Codex 有効時（オプション） |

**呼び出し方法**:
```
Skill ツールを使用:
  skill: "claude-code-harness:review"
```

**子スキル（自動ルーティング）**:
- `review-security` - セキュリティレビュー
- `review-performance` - パフォーマンスレビュー
- `review-quality` - コード品質レビュー
- `review-accessibility` - アクセシビリティレビュー
- `review-aggregate` - レビュー結果の集約

> ⚠️ **重要**: スキルを呼び出さずに進めると usage 統計に記録されません。必ず Skill ツールで呼び出してください。

---

## 🔧 LSP 機能の活用

レビューでは LSP（Language Server Protocol）を活用して、より精度の高い分析を行います。

### LSP Diagnostics によるコード品質チェック

```
📊 LSP 診断結果

ファイル: src/components/UserForm.tsx

| 行 | 重要度 | メッセージ |
|----|--------|-----------|
| 15 | Error | 型 'string' を型 'number' に割り当てることはできません |
| 23 | Warning | 'tempData' は宣言されていますが、使用されていません |
| 42 | Info | この async 関数には await がありません |

→ 型エラー・未使用変数を自動検出
```

### LSP Find-references による影響範囲分析

変更されたコードがどこで使われているかを LSP で分析：

```
🔍 変更の影響範囲

変更: src/utils/formatDate.ts

参照箇所:
├── src/components/DateDisplay.tsx:12
├── src/components/EventCard.tsx:45
├── src/pages/Dashboard.tsx:78
└── tests/utils/formatDate.test.ts:5

→ 4ファイルに影響
→ テストでカバーされていることを確認 ✅
```

### レビュー観点への統合

| レビュー観点 | LSP 活用 |
|-------------|---------|
| **品質** | Diagnostics で型エラー・未使用コードを検出 |
| **セキュリティ** | 参照分析で機密データの流れを追跡 |
| **パフォーマンス** | 定義ジャンプで重い処理の実装を確認 |

### VibeCoder 向けの言い方

| やりたいこと | 言い方 |
|-------------|--------|
| 型エラーをチェック | 「LSP診断を含めてレビューして」 |
| 変更の影響を知りたい | 「この変更がどこに影響するか調べて」 |

詳細: [docs/LSP_INTEGRATION.md](../../docs/LSP_INTEGRATION.md)

---

## このコマンドの目的

**受託開発の品質保証**を自動化します。

- クライアントに提出するコードの品質を担保
- セキュリティリスクを事前に検出
- パフォーマンス問題を早期発見
- アクセシビリティ対応を確認

---

## 実行フロー

### Step 0: Codex セカンドオピニオン確認（once hook で自動実行）

**初回実行時に `once: true` hook により Codex の有無を自動確認します。**

このコマンドの frontmatter に定義された hook:
```yaml
hooks:
  - event: PreCommandInvoke
    type: command
    command: "${CLAUDE_PLUGIN_ROOT}/scripts/check-codex.sh"
    once: true
```

**動作**:
- セッション内で最初の `/harness-review` 実行時のみ `check-codex.sh` が実行される
- Codex がインストールされていれば、有効化方法を案内
- 2回目以降は自動スキップ（`once: true` の効果）

**Codex を有効化する場合**:

プロジェクト設定ファイル（`.claude-code-harness.config.yaml`）に以下を追加:
```yaml
review:
  codex:
    enabled: true
```

> 💡 **手動で Codex レビューのみ実行したい場合**: `/codex-review` コマンドを使用してください

---

### Step 0.5: 残コンテキスト確認（Codex モード時）

Codex 並列レビューの前に**残コンテキストが 30%以下なら /compact を実行してから続行**してください。

> **注意**: /compact 後も余裕が少ない場合でも、Codex 並列レビューは継続します。

---

### Step 1: 変更ファイルの特定

```bash
# 直近の変更を確認
git diff --name-only HEAD~5 2>/dev/null || find . -name "*.ts" -o -name "*.tsx" -o -name "*.py" | head -20
```

### Step 2: 並列レビューの実行

以下の観点で並列レビューを実行します。**Task tool**を使用して複数のサブエージェントを同時に起動し、レビュー時間を短縮します。

**💡 非同期サブエージェントによる真の並列実行**:
各レビューを個別に実行し、`Ctrl+B`でバックグラウンドに送ることで、完全に並列で実行できます。詳細は[非同期サブエージェントガイド](../docs/ASYNC_SUBAGENTS.md)を参照してください。

**手動並列実行の手順**:
1. `/harness-review security` を実行 → `Ctrl+B` でバックグラウンドへ
2. `/harness-review performance` を実行 → `Ctrl+B` でバックグラウンドへ
3. `/harness-review quality` を実行 → `Ctrl+B` でバックグラウンドへ
4. `/harness-review accessibility` を実行 → `Ctrl+B` でバックグラウンドへ
5. 各サブエージェントが完了すると自動的に通知されます

**モード別の並列実行:**

#### Default モード（`review.mode: default`）- Task tool で code-reviewer を4並列起動

```
🔍 並列レビュー開始...

Task tool #1: subagent_type="code-reviewer" → セキュリティ観点
Task tool #2: subagent_type="code-reviewer" → パフォーマンス観点
Task tool #3: subagent_type="code-reviewer" → 品質観点
Task tool #4: subagent_type="code-reviewer" → アクセシビリティ観点

→ 4つのサブエージェントが並列実行
→ 結果を統合して総合評価を出力
```

#### Codex モード（`review.mode: codex`）- 必要なエキスパートのみ MCP 並列実行

**⚠️ 重要: 1回の呼び出しで複数エキスパートをまとめないこと**

```
🔍 Codex 並列レビュー開始...

1. 呼び出すエキスパートを判定（全部ではなく必要なもののみ）:
   - 設定で enabled: false → 除外
   - CLI/バックエンド → Accessibility, SEO 除外
   - ドキュメントのみ変更 → Quality, Architect, Plan Reviewer, Scope Analyst を優先

2. 有効なエキスパートの experts/*.md からプロンプトを個別に読み込む

3. 有効なエキスパートのみ mcp__codex__codex を1レスポンス内で並列実行:
   例: Webフロントエンドでコード変更あり → 6エキスパート並列
   mcp__codex__codex({prompt: security-expert.md})
   mcp__codex__codex({prompt: accessibility-expert.md})
   mcp__codex__codex({prompt: performance-expert.md})
   mcp__codex__codex({prompt: quality-expert.md})
   mcp__codex__codex({prompt: seo-expert.md})
   mcp__codex__codex({prompt: architect-expert.md})

→ 必要なエキスパートのみ並列実行（コスト最適化）
→ 各エキスパートの結果を統合して判定
```

**詳細**: `skills/codex-review/references/codex-parallel-review.md`

レビュー観点：

#### 🔒 セキュリティチェック

- [ ] 環境変数の適切な管理
- [ ] 入力のバリデーション
- [ ] SQLインジェクション対策
- [ ] XSS対策
- [ ] 認証・認可の実装

#### ⚡ パフォーマンスチェック

- [ ] 不要な再レンダリング
- [ ] N+1クエリ
- [ ] 重い計算の最適化
- [ ] 画像・アセットの最適化

#### 📐 コード品質チェック

- [ ] TypeScript型の適切な使用
- [ ] エラーハンドリング
- [ ] 命名規則の一貫性
- [ ] ファイル構成の適切さ

#### ♿ アクセシビリティチェック（Webの場合）

- [ ] セマンティックHTML
- [ ] altテキスト
- [ ] キーボード操作
- [ ] カラーコントラスト

### Step 2.5: 結果統合と Codex 検証（Codex 有効時）

**`codex.enabled: true` の場合、Claude が Codex のレビュー結果を検証し、修正が必要かどうかを判断します。**

```
📊 レビュー結果統合中...

1. Claude 4観点レビュー結果を集約
2. Codex レビュー結果を取得
3. Claude が Codex の指摘を検証
   - 妥当な指摘か？
   - 修正が必要か？
   - 優先度は？
```

**結果の統合と検証**:

```markdown
## 📊 レビュー結果比較

| 観点 | Claude | Codex | 一致 |
|------|--------|-------|------|
| セキュリティ | 2件 | 1件 | 1件共通 |
| パフォーマンス | 1件 | 2件 | 1件共通 |

### 🔴 両者が指摘（優先度高・修正推奨）
- SQL インジェクションの可能性（src/api/users.ts:45）
  → **Claude 検証**: 妥当。パラメータ化クエリに修正が必要

### 🟡 Claude のみ指摘
- 未使用変数（src/utils/helpers.ts:12）
  → **修正推奨**: 削除または使用

### 🟢 Codex のみ指摘（Claude 検証済み）
- N+1 クエリの可能性（src/api/posts.ts:30）
  → **Claude 検証**: 妥当。prefetch を追加すべき
```

**修正提案と承認フロー**:

```markdown
## 🔧 修正が必要な項目

以下の修正を Plans.md に追加して `/work` で実行しますか？

| # | 修正内容 | ファイル | 優先度 |
|---|---------|----------|--------|
| 1 | SQL インジェクション対策 | src/api/users.ts:45 | 高 |
| 2 | N+1 クエリ修正 | src/api/posts.ts:30 | 中 |
| 3 | 未使用変数削除 | src/utils/helpers.ts:12 | 低 |

**選択肢:**
1. すべて承認 → Plans.md に追加して `/work` 実行
2. 選択して承認 → 番号を指定（例: 1,2）
3. 今は修正しない → レポートのみ保存
```

**承認後のフロー**:

```
ユーザー承認
    ↓
Plans.md に修正タスクを追加
    ↓
/work を自動実行（または実行を提案）
    ↓
修正完了後に再レビュー（オプション）
```

> 💡 **Codex レビューのみを実行したい場合**: `/codex-review` コマンドを使用してください

---

### Step 3: レビュー結果の出力

> 📊 **コードレビュー結果**
>
> **総合評価**: {{A / B / C / D}}
>
> ---
>
> ### 🔒 セキュリティ: {{評価}}
> {{問題点または「問題なし」}}
>
> ### ⚡ パフォーマンス: {{評価}}
> {{問題点または「問題なし」}}
>
> ### 📐 コード品質: {{評価}}
> {{問題点または「問題なし」}}
>
> ### ♿ アクセシビリティ: {{評価}}
> {{問題点または「問題なし」}}
>
> ---
>
> ### 🔧 改善提案
>
> 1. {{具体的な改善点1}}
> 2. {{具体的な改善点2}}
>
> **自動で修正しますか？** (y / n / 選択)

### Step 4: 改善の実行（ユーザー承認後）

承認された改善を自動で実行：

```bash
# 例: ESLint自動修正
npx eslint --fix src/

# 例: Prettier適用
npx prettier --write src/
```

### Step 5: 完了報告

> ✅ **レビュー完了**
>
> **修正した項目:**
> - {{修正1}}
> - {{修正2}}
>
> **次にやること:**
> 「コミットして」または「次のフェーズへ」と言ってください。

### Step 6: コミットガード連携（コミット前レビュー必須化）

**レビュー結果が APPROVE の場合、コミットを許可する状態ファイルを生成します。**

この機能により、レビューなしでコミットしようとするとブロックされます。

**動作フロー**:
```
/harness-review 実行
    ↓
レビュー結果が APPROVE
    ↓
.claude/state/review-approved.json を生成
    ↓
git commit が許可される
    ↓
コミット成功後、review-approved.json をクリア
    ↓
次回のコミット前に再度レビューが必要
```

**状態ファイルの生成（APPROVE 時に自動実行）**:

```bash
# レビュー結果が APPROVE の場合、以下を実行
mkdir -p .claude/state
cat > .claude/state/review-approved.json << 'EOF'
{
  "judgment": "APPROVE",
  "approved_at": "{{ISO 8601 timestamp}}",
  "reviewed_files": ["{{changed_files}}"],
  "review_summary": "{{summary}}"
}
EOF
```

**コミットガードを無効化したい場合**:

`.claude-code-harness.config.yaml` に以下を追加:
```yaml
commit_guard: false
```

> 💡 **注意**: コミットガードを無効化すると、レビューなしでコミットできるようになります。品質保証のため、本番プロジェクトでは有効のままにすることを推奨します。

---

## レビュー観点の詳細

### セキュリティ

```typescript
// ❌ 悪い例
const apiKey = "sk-1234567890"  // ハードコード

// ✅ 良い例
const apiKey = process.env.API_KEY  // 環境変数
```

### パフォーマンス

```typescript
// ❌ 悪い例
const Component = () => {
  const data = heavyCalculation()  // 毎回計算
  return <div>{data}</div>
}

// ✅ 良い例
const Component = () => {
  const data = useMemo(() => heavyCalculation(), [])
  return <div>{data}</div>
}
```

### コード品質

```typescript
// ❌ 悪い例
function f(x: any) { return x.y.z }  // any型、エラーハンドリングなし

// ✅ 良い例
function getNestedValue(obj: NestedObject): string | null {
  return obj?.y?.z ?? null
}
```

---

## VibeCoder 向け簡易版

技術的な詳細が不要な場合：

> 📊 **チェック結果**
>
> - セキュリティ: ✅ OK
> - 速度: ✅ OK
> - コード品質: ⚠️ 2件の改善点
>
> 「直して」と言えば自動で修正します。

---

## オプション

```
/harness-review              # 全てチェック
/harness-review security     # セキュリティのみ
/harness-review performance  # パフォーマンスのみ
/harness-review quick        # 簡易チェック
```

---

## ⚡ 並列実行の判断ポイント

レビュー観点（セキュリティ/パフォーマンス/品質/アクセシビリティ/Codex）は**互いに独立**しているため、並列実行が効果的です。

### 並列実行すべき場合 ✅

| 条件 | 理由 |
|------|------|
| フルレビュー（4観点すべて） | 時間短縮効果が最大 |
| Codex 有効時（5観点） | Codex も並列で実行 |
| 変更ファイルが 5 つ以上 | 各観点の処理時間が長くなる |
| 急いで結果を知りたい | PR マージ前など |

**並列実行の効果（Codex 有効時）**:
```
🚀 並列レビュー開始...
├── [Security] 分析中... ⏳
├── [Performance] 分析中... ⏳
├── [Quality] 分析中... ⏳
├── [Accessibility] 分析中... ⏳
└── [Codex] セカンドオピニオン取得中... ⏳

⏱️ 所要時間: 35秒（Codex 逐次実行なら+30秒）
```

### 直列実行すべき場合 ⚠️

| 条件 | 理由 |
|------|------|
| 単一観点のみ（`/harness-review security`） | 並列化不要 |
| 変更ファイルが 1-2 つ | 各観点の処理が短い |
| 1つずつ問題を確認したい | 対話的に修正を進めたい |

### 自動判断ロジック

```
レビュー観点 >= 3 かつ 変更ファイル >= 5 → 並列実行（Task tool）
レビュー観点 < 3 または 変更ファイル < 5 → 直列実行
```

### 手動で並列実行する方法

```bash
# バックグラウンドで並列実行
/harness-review security     # → Ctrl+B でバックグラウンドへ
/harness-review performance  # → Ctrl+B でバックグラウンドへ
/harness-review quality      # → Ctrl+B でバックグラウンドへ
/harness-review accessibility # 最後は待機

# 結果を統合して報告
```
