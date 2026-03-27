---
name: session-control
description: "Apply harness-work --resume/--fork flags by updating session state files."
allowed-tools: ["Read", "Bash", "Write", "Edit"]
---

# Session Control

## 输入

workflow 变量:
- `resume_session_id` (string)
- `resume_latest` (boolean)
- `fork_session_id` (string)
- `fork_reason` (string)

## 执行

### 1) 参数决定
- resume:
  - `resume_latest == true` → `--resume latest`
  - 否则若有 `resume_session_id` 则 `--resume <id>`
- fork:
  - 若有 `fork_session_id` 则 `--fork <id>`，否则 `--fork current`
  - 若有 `fork_reason` 则 `--reason "<text>"`

### 2) 脚本执行
```bash
./scripts/session-control.sh --resume <id|latest>
./scripts/session-control.sh --fork <id|current> --reason "<text>"
```

## 预期结果
- `.claude/state/session.json` 被更新
- `.claude/state/session.events.jsonl` 追加 `session.resume` 或 `session.fork`
- 错误时 stderr 输出原因
