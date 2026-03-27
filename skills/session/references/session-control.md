---
name: session-control
description: "通过更新会话状态文件应用 /work --resume/--fork 标志。"
allowed-tools: ["Read", "Bash", "Write", "Edit"]
---

# Session Control

## 输入

workflow 变量：
- `resume_session_id` (string)
- `resume_latest` (boolean)
- `fork_session_id` (string)
- `fork_reason` (string)

## 执行

### 1) 决定参数
- resume：
  - `resume_latest == true` → `--resume latest`
  - 否则如果有 `resume_session_id` 则 `--resume <id>`
- fork：
  - 如果有 `fork_session_id` 则 `--fork <id>`，否则 `--fork current`
  - 如果有 `fork_reason` 则 `--reason "<text>"`

### 2) 执行脚本
```bash
./scripts/session-control.sh --resume <id|latest>
./scripts/session-control.sh --fork <id|current> --reason "<text>"
```

## 期望的结果
- `.claude/state/session.json` 被更新
- `.claude/state/session.events.jsonl` 中追加 `session.resume` 或 `session.fork`
- 错误时在 stderr 输出原因
