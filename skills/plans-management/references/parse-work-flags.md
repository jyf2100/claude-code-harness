---
name: parse-work-flags
description: "Parse /work command flags from user_prompt. Extracts --full, --parallel, --isolation, --commit-strategy, --deploy, --max-iterations, --skip-cross-review, --resume, --fork options. Also supports magic keywords (ultrawork, quickwork)."
allowed-tools: ["Read"]
---

# Parse Work Flags

`/work`コマンドのフラグを解析し、実行モードとオプションを決定するスキル。

---

## 入力

- **user_prompt**: `/work`コマンドの入力文字列
  - 例: `/work --full --parallel 3 --isolation worktree`
  - 例: `/work ultrawork` (マジックキーワード)
  - 例: `/work ultrawork --parallel 5` (マジックキーワード + 上書き)

---

## 出力

以下の変数を必ず出力する（デフォルト値を明示）：

```json
{
  "full_mode": false,
  "parallel_count": 1,
  "isolation_mode": "lock",
  "commit_strategy": "task",
  "deploy_after_commit": false,
  "max_iterations": 3,
  "skip_cross_review": false,
  "resume_session_id": "",
  "resume_latest": false,
  "fork_session_id": "",
  "fork_reason": ""
}
```

---

## マジックキーワード

マジックキーワードを使用すると、複数のフラグを一括で設定できます。
明示的なフラグ指定で上書き可能です。

### キーワード定義

| キーワード | 展開されるフラグ | 用途 |
|-----------|-----------------|------|
| `ultrawork` | `--full --parallel 3 --isolation worktree --commit-strategy phase --max-iterations 3` | 最大効率の並列実行 |
| `quickwork` | `--full --parallel 1 --commit-strategy task` | 高速な単一タスク実行 |
| `deploywork` | `--full --parallel 2 --deploy --commit-strategy all` | デプロイ込みの実行 |

### マジックキーワード検出

```javascript
// マジックキーワードプリセット
const magicKeywords = {
  "ultrawork": {
    full_mode: true,
    parallel_count: 3,
    isolation_mode: "worktree",
    commit_strategy: "phase",
    max_iterations: 3
  },
  "quickwork": {
    full_mode: true,
    parallel_count: 1,
    isolation_mode: "lock",
    commit_strategy: "task",
    max_iterations: 3
  },
  "deploywork": {
    full_mode: true,
    parallel_count: 2,
    isolation_mode: "lock",
    commit_strategy: "all",
    deploy_after_commit: true,
    max_iterations: 3
  }
};

// 検出パターン
const keywordPattern = /\b(ultrawork|quickwork|deploywork)\b/i;
const match = user_prompt.match(keywordPattern);
if (match) {
  const preset = magicKeywords[match[1].toLowerCase()];
  // プリセットを適用後、明示的フラグで上書き
}
```

### 使用例

```
入力: "/work ultrawork"
出力:
  full_mode: true
  parallel_count: 3
  isolation_mode: "worktree"
  commit_strategy: "phase"
  max_iterations: 3

入力: "/work ultrawork --parallel 5"
出力:
  full_mode: true
  parallel_count: 5  ← 明示フラグで上書き
  isolation_mode: "worktree"
  commit_strategy: "phase"
  max_iterations: 3
```

---

## フラグ解析ルール

### `--full`
- 検出: `user_prompt`に`--full`が含まれる
- デフォルト: `false`
- 出力: `full_mode: true`

### `--parallel N`
- 検出: `--parallel`の後に数値が続く
- パターン: `--parallel\s+(\d+)` または `--parallel=(\d+)`
- デフォルト: `1`
- 出力: `parallel_count: N`（1-10の範囲、超過時は10に制限）

### `--isolation lock|worktree`
- 検出: `--isolation`の後に`lock`または`worktree`が続く
- パターン: `--isolation\s+(lock|worktree)` または `--isolation=(lock|worktree)`
- デフォルト: `lock`
- 出力: `isolation_mode: "lock"` または `"worktree"`

### `--commit-strategy task|phase|all`
- 検出: `--commit-strategy`の後に`task`/`phase`/`all`が続く
- パターン: `--commit-strategy\s+(task|phase|all)` または `--commit-strategy=(task|phase|all)`
- デフォルト: `task`
- 出力: `commit_strategy: "task"` / `"phase"` / `"all"`

### `--deploy`
- 検出: `user_prompt`に`--deploy`が含まれる
- デフォルト: `false`
- 出力: `deploy_after_commit: true`

### `--max-iterations N`
- 検出: `--max-iterations`の後に数値が続く
- パターン: `--max-iterations\s+(\d+)` または `--max-iterations=(\d+)`
- デフォルト: `3`
- 出力: `max_iterations: N`（1-10の範囲）

### `--skip-cross-review`
- 検出: `user_prompt`に`--skip-cross-review`が含まれる
- デフォルト: `false`
- 出力: `skip_cross_review: true`

### `--resume <session_id|latest>`
- 検出: `--resume`の後にIDまたは`latest`が続く
- パターン: `--resume\\s+(\\S+)` または `--resume=(\\S+)`
- デフォルト: `""`
- 出力:
  - `resume_session_id: <id>`（`latest`の場合は空）
  - `resume_latest: true`（`latest`の場合）

### `--fork <session_id|current> --reason <text>`
- 検出: `--fork`の後にIDまたは`current`が続く
- パターン: `--fork\\s+(\\S+)` または `--fork=(\\S+)`
- デフォルト: `""`
- 出力:
  - `fork_session_id: <id>`（`current`の場合は空）
  - `fork_reason: "<text>"`（省略時は空）

---

## 実行手順

### Step 1: user_promptの読み取り

```bash
# user_promptはワークフローから渡される
# 例: "/work --full --parallel 3"
```

### Step 2: フラグの抽出

正規表現または文字列検索で各フラグを検出：

```javascript
// 疑似コード例
const flags = {
  full_mode: /--full/.test(user_prompt),
  parallel_count: extractNumber(user_prompt, /--parallel[\s=]+(\d+)/) || 1,
  isolation_mode: extractString(user_prompt, /--isolation[\s=]+(lock|worktree)/) || "lock",
  commit_strategy: extractString(user_prompt, /--commit-strategy[\s=]+(task|phase|all)/) || "task",
  deploy_after_commit: /--deploy/.test(user_prompt),
  max_iterations: extractNumber(user_prompt, /--max-iterations[\s=]+(\d+)/) || 3,
  skip_cross_review: /--skip-cross-review/.test(user_prompt),
  resume_session_id: extractString(user_prompt, /--resume[\s=]+(\S+)/) || "",
  resume_latest: /--resume[\s=]+latest/.test(user_prompt),
  fork_session_id: extractString(user_prompt, /--fork[\s=]+(\S+)/) || "",
  fork_reason: extractString(user_prompt, /--reason[\s=]+(.+)/) || ""
};
```

### Step 3: バリデーション

- `parallel_count`: 1-10の範囲に制限
- `max_iterations`: 1-10の範囲に制限
- `isolation_mode`: `lock`または`worktree`のみ許可
- `commit_strategy`: `task`/`phase`/`all`のみ許可

### Step 4: 出力

ワークフロー変数として出力：

```yaml
output:
  variables:
    - full_mode
    - parallel_count
    - isolation_mode
    - commit_strategy
    - deploy_after_commit
    - max_iterations
    - skip_cross_review
```

---

## 使用例

### 例1: 基本的な`--full`
```
入力: "/work --full"
出力:
  full_mode: true
  parallel_count: 1
  isolation_mode: "lock"
  commit_strategy: "task"
  deploy_after_commit: false
  max_iterations: 3
  skip_cross_review: false
  resume_session_id: ""
  resume_latest: false
  fork_session_id: ""
  fork_reason: ""
```

### 例2: 並列実行指定
```
入力: "/work --full --parallel 5"
出力:
  full_mode: true
  parallel_count: 5
  isolation_mode: "lock"
  commit_strategy: "task"
  deploy_after_commit: false
  max_iterations: 3
  skip_cross_review: false
```

### 例3: 完全なオプション指定
```
入力: "/work --full --parallel 3 --isolation worktree --commit-strategy phase --deploy --max-iterations 5"
出力:
  full_mode: true
  parallel_count: 3
  isolation_mode: "worktree"
  commit_strategy: "phase"
  deploy_after_commit: true
  max_iterations: 5
  skip_cross_review: false
```

### 例4: 非`--full`モード（既存フロー）
```
入力: "/work"
出力:
  full_mode: false
  parallel_count: 1
  isolation_mode: "lock"
  commit_strategy: "task"
  deploy_after_commit: false
  max_iterations: 3
  skip_cross_review: false
```

---

## 注意事項

- **フラグの順序は問わない**: `--full --parallel 3`と`--parallel 3 --full`は同じ結果
- **大文字小文字を区別しない**: `--FULL`も`--full`として認識
- **未指定フラグはデフォルト値**: 明示的に指定されていないフラグはデフォルト値を使用
- **不正な値はデフォルトにフォールバック**: `--parallel abc`は`parallel_count: 1`になる
