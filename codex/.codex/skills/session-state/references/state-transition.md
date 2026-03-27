---
name: state-transition
description: "Execute session state transitions using session-state.sh"
allowed-tools: [Read, Bash]
---

# State Transition

执行会话状态转换。

## 输入

workflow 变量:
- `target_state` (string): 目标状态
- `event_name` (string): 触发事件
- `event_data` (string, optional): 事件附加数据 (JSON)

## 有效状态

| 状态 | 说明 |
|------|------|
| `idle` | 会话未开始 |
| `initialized` | SessionStart 完成 |
| `planning` | Plan/Work 准备中 |
| `executing` | harness-work 执行中 |
| `reviewing` | review 执行中 |
| `verifying` | build/test 执行中 |
| `escalated` | 等待人工确认 |
| `completed` | 交付物已确定 |
| `failed` | 无法恢复 |
| `stopped` | Stop hook 到达 |

## 典型转换

| From | Event | To |
|------|-------|----|
| idle | session.start | initialized |
| initialized | plan.ready | planning |
| planning | work.start | executing |
| executing | work.task_complete | reviewing |
| reviewing | verify.start | verifying |
| verifying | verify.passed | completed |
| verifying | verify.failed | escalated |
| * | session.stop | stopped |
| stopped | session.resume | initialized |

## 执行

```bash
./scripts/session-state.sh --state <state> --event <event> [--data <json>]
```

### 示例: 转换到执行状态

```bash
./scripts/session-state.sh --state executing --event work.start
```

### 示例: 升级处理（带数据）

```bash
./scripts/session-state.sh --state escalated --event escalation.requested \
  --data '{"reason":"Build failed 3 times","retry_count":3}'
```

## 预期结果

- `.claude/state/session.json` 的 `state`, `updated_at`, `last_event_id`, `event_seq` 被更新
- `.claude/state/session.events.jsonl` 中追加事件记录
- 非法转换会输出错误到 stderr + 非零退出

## 错误处理

转换失败时（如非法转换）:
1. 将当前状态和允许的转换输出到 stderr
2. 返回非零退出码
3. 由调用方（workflow）进行升级处理
