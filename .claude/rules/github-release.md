# GitHub Release Notes Rules

Formatting rules applied when creating GitHub Release notes.

## Required Format

### Structure

```markdown
## What's Changed

**One-line description of the change's value**

### Before / After

| Before | After |
|--------|-------|
| Previous state | New state |
| ... | ... |

---

## Added

- **Feature name**: Description
  - Detail 1
  - Detail 2

## Changed

- **Change**: Description

## Fixed

- **Fix**: Description

## Requirements (if applicable)

- **Claude Code vX.X.X+** (recommended)
- Link: [Documentation](URL)

---

Generated with [Claude Code](https://claude.com/claude-code)
```

### Required Elements

| Element | Required | Description |
|---------|----------|-------------|
| `## What's Changed` | Yes | Section heading |
| **Bold summary** | Yes | One-line value description |
| `Before / After` table | Yes | User-facing changes |
| `Added/Changed/Fixed` | When applicable | Detailed changes |
| Footer | Yes | `Generated with [Claude Code](...)` |

### Language

- **GitHub Release**: English required（公開リポジトリのため）
- **CHANGELOG.md**: **日本語**で詳細な Before/After 形式（後述）
- Keep descriptions user-focused

## CHANGELOG フォーマット（日本語・詳細 Before/After）

CHANGELOG は各機能を「今まで → 今後」形式で具体的に記述する:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### テーマ: [変更全体を一言で]

**[ユーザーにとっての価値を1〜2文で]**

---

#### 1. [機能名]

**今まで**: [旧動作。ユーザーが体験していた不便を具体的に描写]

**今後**: [新動作。何が解決するか + 具体例]

```出力例やコマンド例```

#### 2. [次の機能名]

**今まで**: ...
**今後**: ...
```

**書き方ルール**:
- 各機能を `#### N. 機能名` で独立セクションにする
- 「今まで」は**課題描写**（「〜する必要がありました」形式）
- 「今後」は**解決の具体像**（コマンド例・出力例を含める）
- 長くてOK。読みやすさが最優先
- テクニカル詳細（ファイル名、ステップ番号）は「今後」の補足として最小限に

## Prohibited

- No skipping the Before / After (CHANGELOG) or Before / After table (GitHub Release)
- No skipping the footer (GitHub Release)
- No technical-only descriptions (user perspective required)
- No bare change lists without value explanation

## Good Example (GitHub Release — English)

```markdown
## What's Changed

**`/work --full` now automates implement -> self-review -> improve -> commit in parallel**

### Before / After

| Before | After |
|--------|-------|
| `/work` executes tasks one at a time | `/work --full --parallel 3` runs in parallel |
| Reviews required separate manual step | Each task-worker self-reviews autonomously |
```

## Good Example (CHANGELOG — Japanese)

```markdown
#### 1. 失敗タスクの自動再チケット化

**今まで**: テスト/CI が失敗すると3回リトライして止まるだけでした。
止まった後は「何が原因だったか」を自分で調べ、Plans.md に手動で修正タスクを追加する必要がありました。

**今後**: 3回失敗で止まるとき、Harness が失敗原因を分類し、修正タスク案を自動生成します。
承認すると Plans.md に `.fix` タスクとして自動追加されます。
```

## Bad Example

```markdown
## What's New

### Added
- Added task-worker.md
- Added --full option
```

-> Doesn't communicate user value

## Release Creation Command

```bash
gh release create vX.X.X \
  --title "vX.X.X - Title" \
  --notes "$(cat <<'EOF'
## What's Changed
...
EOF
)"
```

## Editing Past Releases

```bash
gh release edit vX.X.X --notes "$(cat <<'EOF'
...
EOF
)"
```

## Reference

- Good examples: v2.8.0, v2.8.2, v2.9.1
- Keep consistent with CHANGELOG
