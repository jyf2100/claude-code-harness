---
description: opencode.ai 用にプロジェクトをセットアップ
---

# /opencode-setup - OpenCode セットアップ

現在のプロジェクトに opencode.ai 互換のコマンド、エージェント、設定ファイルを生成します。

## VibeCoder Quick Reference

- "**opencode でも使いたい**" → このコマンド
- "**GPT でも Harness 使いたい**" → opencode セットアップ
- "**マルチ LLM 開発したい**" → opencode 互換設定
- "**スキルも opencode で使いたい**" → このコマンドで自動対応

## Deliverables

- `.opencode/commands/` - opencode 用カスタムコマンド
- `.opencode/agents/` - opencode 用カスタムエージェント
- `AGENTS.md` - opencode 用ルールファイル（CLAUDE.md 全文）
- `opencode.json` - opencode 設定ファイル

---

## Usage

```bash
/opencode-setup
/opencode-setup --with-mcp    # MCP サーバー設定も含める
/opencode-setup --symlink     # スキルをシンボリックリンクで配置（開発者向け）
```

---

## OpenCode 設定ファイル仕様

> ⚠️ **重要**: opencode.json の形式は Claude Code の設定とは異なります。
>
> 公式スキーマ: https://opencode.ai/config.json
> 公式ドキュメント: https://opencode.ai/docs/config

### 有効なトップレベルキー

| キー | 説明 |
|------|------|
| `$schema` | JSON スキーマ URL |
| `theme` | テーマ名 |
| `model` | デフォルトモデル |
| `small_model` | 軽量タスク用モデル |
| `provider` | プロバイダー設定 |
| `mcp` | MCP サーバー設定 |
| `tools` | ツール有効/無効設定 |
| `agent` | カスタムエージェント定義 |
| `command` | カスタムコマンド定義 |
| `keybinds` | キーバインド設定 |
| `permission` | 権限設定 |
| `instructions` | 追加指示ファイル |

### 無効なキー（使用禁止）

以下のキーは opencode.json では**認識されません**:
- ❌ `name` - プロジェクト名
- ❌ `description` - プロジェクト説明
- ❌ `skills` - スキル設定（OpenCode では `agent` を使用）
- ❌ `commands` - コマンド設定（OpenCode では `command` を使用）

### MCP サーバー設定形式

**Remote MCP サーバー**（`url` が必須）:
```json
{
  "mcp": {
    "context7": {
      "type": "remote",
      "url": "https://mcp.context7.com/mcp",
      "enabled": true
    }
  }
}
```

**Local MCP サーバー**（`command` が必須）:
```json
{
  "mcp": {
    "harness": {
      "type": "local",
      "command": ["node", "./mcp-server/dist/index.js"],
      "enabled": true
    }
  }
}
```

---

## Execution Flow

### Step 1: 確認

> 🔧 **opencode.ai 互換ファイルを生成します**
>
> 以下のファイルが作成されます：
> - `.opencode/commands/` - Harness コマンド
> - `.opencode/agents/` - Harness エージェント
> - `AGENTS.md` - ルールファイル（CLAUDE.md 全文）
> - `opencode.json` - 設定ファイル
>
> 続行しますか？ (y/n)

**ユーザーの回答を待つ**

### Step 2: ディレクトリ作成

```bash
mkdir -p .opencode/commands
mkdir -p .opencode/agents
```

### Step 3: コマンドファイルをコピー

Harness プラグインの `opencode/commands/` からコピー:

```bash
# プラグインディレクトリを特定
PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(dirname $(dirname $0))}"

# コマンドをコピー
cp -r "$PLUGIN_DIR/opencode/commands/"* .opencode/commands/
```

### Step 4: エージェントファイルをコピー

Harness プラグインの `opencode/agents/` からコピー:

```bash
# エージェントをコピー
if [ -d "$PLUGIN_DIR/opencode/agents" ]; then
  cp -r "$PLUGIN_DIR/opencode/agents/"* .opencode/agents/
fi
```

### Step 5: AGENTS.md 生成

Harness プラグインの `opencode/AGENTS.md`（CLAUDE.md 全文コピー）をプロジェクトルートに配置:

```bash
# 既存の AGENTS.md がある場合はバックアップ
if [ -f "AGENTS.md" ]; then
  mv AGENTS.md "AGENTS.md.backup.$(date +%Y%m%d%H%M%S)"
  echo "既存の AGENTS.md をバックアップしました"
fi

# AGENTS.md をコピー
cp "$PLUGIN_DIR/opencode/AGENTS.md" AGENTS.md
```

### Step 6: opencode.json 生成

**基本設定を生成**:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": ["AGENTS.md"]
}
```

**`--with-mcp` オプション指定時は MCP 設定を追加**:

> 🔧 **MCP サーバーを設定します**
>
> 以下の MCP サーバーを追加しますか？
> 1. Context7（ドキュメント検索）
> 2. Harness MCP（ワークフローツール）- 要ビルド
> 3. スキップ
>
> 番号を選択 (1/2/3):

**選択に応じて生成**:

Context7 を選択した場合:
```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": ["AGENTS.md"],
  "mcp": {
    "context7": {
      "type": "remote",
      "url": "https://mcp.context7.com/mcp",
      "enabled": true
    }
  }
}
```

Harness MCP を選択した場合:
```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": ["AGENTS.md"],
  "mcp": {
    "harness": {
      "type": "local",
      "command": ["node", "<PLUGIN_DIR>/mcp-server/dist/index.js"],
      "enabled": true
    }
  }
}
```

### Step 7: .gitignore 更新（オプション）

> 🔧 **.gitignore に `.opencode/` を追加しますか？**
>
> `.opencode/` はローカル設定のため、Git から除外することを推奨します。
>
> 追加しますか？ (y/n)

**「y」の場合**:
```bash
echo "/.opencode/" >> .gitignore
```

### Step 8: 完了メッセージ

> ✅ **OpenCode セットアップ完了**
>
> 📁 **生成されたファイル:**
> - `.opencode/commands/` - Harness コマンド
> - `.opencode/agents/` - Harness エージェント
> - `AGENTS.md` - ルールファイル（CLAUDE.md 全文）
> - `opencode.json` - 設定ファイル
>
> **使い方:**
> ```bash
> # opencode を起動
> opencode
>
> # コマンドを実行（Tab キーでモード切替）
> /plan-with-agent  # Plan モード推奨
> /work
> /harness-review
> ```
>
> **参考:**
> - OpenCode ドキュメント: https://opencode.ai/docs/
> - Harness GitHub: https://github.com/Chachamaru127/claude-code-harness

---

## Notes

- 既存の `.opencode/` ディレクトリがある場合は上書き確認
- `AGENTS.md` が既存の場合はバックアップを作成
- MCP サーバーを使う場合は事前にビルドが必要
- **opencode.json の形式は Claude Code とは異なります**
  - `name`, `description`, `skills`, `commands` キーは使用不可
  - MCP の `remote` タイプには `url` が必須
  - MCP の `local` タイプには `command` が必須

---

## Troubleshooting

### "Invalid input mcp.*" エラー

MCP サーバー設定に `url`（remote）または `command`（local）が不足しています。

**修正例**:
```json
// ❌ 無効
{
  "mcp": {
    "my-server": {
      "type": "remote",
      "enabled": true,
      "description": "説明"  // description は無効
    }
  }
}

// ✅ 有効
{
  "mcp": {
    "my-server": {
      "type": "remote",
      "url": "https://example.com/mcp",
      "enabled": true
    }
  }
}
```

### "Unrecognized keys" エラー

opencode.json で認識されないキーを使用しています。

**修正例**:
```json
// ❌ 無効
{
  "name": "my-project",
  "description": "説明",
  "skills": {},
  "commands": {}
}

// ✅ 有効
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": ["AGENTS.md"]
}
```

---

## Related Commands

- `/mcp-setup` - MCP サーバーセットアップ
- `/harness-init` - Harness プロジェクト初期化
- `/harness-update` - Harness 更新
