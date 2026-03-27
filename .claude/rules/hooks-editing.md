---
description: Rules for editing hook configuration (hooks.json)
paths: "**/hooks.json"
---

# Hooks Editing Rules

Rules applied when editing `hooks.json` files.

## Important: Dual hooks.json Sync (Required)

**Two hooks.json files exist and must always be in sync:**

```
hooks/hooks.json           ← Source file (for development)
.claude-plugin/hooks.json  ← For plugin distribution (sync required)
```

### Editing Flow

1. Edit `hooks/hooks.json`
2. Apply the same changes to `.claude-plugin/hooks.json`
3. Sync cache with `./scripts/sync-plugin-cache.sh`

```bash
# Always run after changes
./scripts/sync-plugin-cache.sh
```

## Hook Types

4 种类型可用: `command`（通用）、`http`（外部集成）、`prompt`（LLM 单次判断）、`agent`（LLM 代理判断）。后两者在 v2.1.63+ 支持所有事件。

> **CC v2.1.69+**: 添加了 `InstructionsLoaded` 事件、`agent_id` / `agent_type` 字段、`{"continue": false, "stopReason": "..."}` 响应。
>
> **CC v2.1.76+**: 添加了 `Elicitation`、`ElicitationResult`、`PostCompact` 事件。
> MCP Elicitation 在后台代理中无法进行 UI 交互，因此需要在钩子中自动处理。
> PostCompact 与 PreCompact 配对，用于压缩后的上下文再注入。
>
> **CC v2.1.77+**: 即使 PreToolUse 钩子返回 `"allow"`，settings.json 的 `deny` 规则也会优先。
> 在钩子内 allow 但如果有 deny 设置仍会被拒绝。设计 guardrail 时请注意这个优先级。
>
> **CC v2.1.78+**: 添加了 `StopFailure` 事件。在 API 错误（速率限制、认证失败等）
> 导致会话停止失败时触发。用于错误日志和恢复处理。

### command Type (General Purpose)

Available for all events:

```json
{
  "type": "command",
  "command": "node \"${CLAUDE_PLUGIN_ROOT}/scripts/run-script.js\" script-name",
  "timeout": 30
}
```

### prompt Type

**Official Support**: Available for all hook events (v2.1.63+)

```json
{
  "type": "prompt",
  "prompt": "Evaluation instructions...\n\n[IMPORTANT] Always respond in this JSON format:\n{\"ok\": true} or {\"ok\": false, \"reason\": \"reason\"}",
  "timeout": 30
}
```

**Response Schema (Required)**:
```json
{"ok": true}                          // Allow action
{"ok": false, "reason": "explanation"}  // Block action
```

⚠️ **Note**: If you don't explicitly instruct JSON format in the prompt, the LLM may return natural language and cause a `JSON validation failed` error

### agent Type (v2.1.63+)

将钩子的判断委托给 LLM 代理的新钩子形式。可以使用 Read, Grep, Glob 工具分析代码，判断允许/拒绝。

```json
{
  "type": "agent",
  "prompt": "Check if the code change introduces security vulnerabilities. $ARGUMENTS",
  "model": "haiku",
  "timeout": 60
}
```

#### agent hook 专用字段

| 字段 | 必需 | 说明 |
|-----------|------|------|
| `prompt` | Yes | 发送给代理的提示词。`$ARGUMENTS` 用于引用钩子输入 JSON |
| `model` | No | 使用的模型（默认: fast model）。为成本管理推荐 `haiku` |

#### 与 command hook 的主要区别

| 项目 | command hook | agent hook |
|------|-------------|-----------|
| 判断方式 | 基于规则（正则表达式·条件分支） | LLM 理解上下文后判断 |
| 工具 | Shell 命令 | Read, Grep, Glob（无副作用） |
| 成本 | 低（仅进程启动） | 高（LLM 推理 token 消耗） |
| 适用场景 | 确定性规则 | 依赖上下文的质量判断 |
| 异步 | 支持 `async: true` | 不支持 |

#### 成本管理指南

- 用 matcher 将目标限制到最小（例: 仅 `Write|Edit`）
- 用 `model: "haiku"` 抑制成本
- 每次推荐的 token 上限: 2,000
- 月度成本超支时考虑回滚到 command 型

### http Type (v2.1.63+)

将 JSON POST 到 URL 的新钩子形式。用于与外部服务集成。

```json
{
  "type": "http",
  "url": "http://localhost:8080/hooks/pre-tool-use",
  "timeout": 30,
  "headers": {
    "Authorization": "Bearer $MY_TOKEN"
  },
  "allowedEnvVars": ["MY_TOKEN"]
}
```

#### HTTP hook 专用字段

| 字段 | 必需 | 说明 |
|-----------|------|------|
| `url` | Yes | POST 目标 URL |
| `headers` | No | 额外 HTTP 头。`$VAR` / `${VAR}` 可展开环境变量 |
| `allowedEnvVars` | No | 允许在 `headers` 中展开的环境变量名列表。未指定时不展开 |

#### 响应规格

| 响应 | 行为 |
|-----------|------|
| `2xx` + 空主体 | 成功，继续 |
| `2xx` + JSON 主体 | 成功，JSON 以与 command hook 相同的 schema 解析 |
| `非 2xx` / 超时 | 非阻塞错误，继续执行 |

#### 与 command hook 的主要区别

| 项目 | command hook | http hook |
|------|-------------|-----------|
| 输入 | stdin (JSON) | POST body (JSON) |
| 成功判定 | exit code 0 | 2xx 状态码 |
| 阻塞 | exit 2 | 2xx + `permissionDecision: "deny"` 的 JSON |
| 异步执行 | 支持 `async: true` | 不支持 |
| `/hooks` 菜单 | 可添加 | 不可（仅 JSON 直接编辑） |
| 环境变量 | Shell 环境自动展开 | 需在 `allowedEnvVars` 中明确列出 |

#### 示例模板

**Slack 通知**:
```json
{
  "type": "http",
  "url": "https://hooks.slack.com/services/T00/B00/xxx",
  "timeout": 10
}
```

**指标收集**:
```json
{
  "type": "http",
  "url": "http://localhost:9090/metrics/hook",
  "timeout": 5,
  "headers": { "X-Source": "claude-code-harness" }
}
```

**外部仪表盘更新**:
```json
{
  "type": "http",
  "url": "https://dashboard.example.com/api/events",
  "timeout": 15,
  "headers": { "Authorization": "Bearer $DASHBOARD_TOKEN" },
  "allowedEnvVars": ["DASHBOARD_TOKEN"]
}
```

### Recommended Pattern

Execute command type via `run-script.js`:

```json
{
  "type": "command",
  "command": "node \"${CLAUDE_PLUGIN_ROOT}/scripts/run-script.js\" {script-name}",
  "timeout": 30
}
```

## Timeout Setting Guidelines

> **Claude Code v2.1.3+**: Maximum timeout for tool hooks extended from 60 seconds → 10 minutes

### Guidelines by Processing Nature

| Hook Type | Recommended Timeout | Notes |
|-----------|-------------------|-------|
| Lightweight check (guard) | 5-10s | File existence checks, etc. |
| Normal processing (cleanup) | 30-60s | File operations, git operations |
| Heavy processing (test) | 60-120s | Test execution, builds |
| External API integration | 60-180s | Codex reviews, etc. |
| agent hook（LLM判断） | 30-60s | 取决于模型和提示词量。haiku 30秒，sonnet 60秒 |
| http hook（外部集成） | 5-15s | 本地服务器 5 秒，外部服务 15 秒。超时时非阻塞 |

**Note**: Set timeouts according to processing nature. Don't make them unnecessarily long.

#### agent hook 实测指南（haiku 模型）

| 提示词量 | 预期延迟 | 推荐 timeout |
|------------|-------------|------------|
| 〜500 tokens | 3-8s | 15s |
| 〜1,000 tokens | 5-15s | 30s |
| 〜2,000 tokens | 10-25s | 45s |
| 2,000 tokens 以上 | 不推荐 | — |

成本参考（haiku）: 100次/日的会话约 $0.01-0.05/日。月度 $1-2 以下为正常范围。

### Recommended Values by Event Type

| Hook Type | Recommended | Reason |
|-----------|-------------|--------|
| InstructionsLoaded | 5-10s | 仅初始上下文的轻量验证 |
| SessionStart | 30s | Initialization may take time |
| SubagentStart/Stop | 10s | Tracking only, lightweight processing |
| TeammateIdle / TaskCompleted | 10-20s | 团队进度和停止判定（必要时 `continue:false`） |
| PreToolUse | 30s | Guard processing, file validation |
| PostToolUse | 5-30s | Depends on processing content |
| Stop | 20s | Ensure completion of termination processing |
| SessionEnd | 30s | 会话结束处理。可通过 `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` 控制 |
| UserPromptSubmit | 10-30s | Policy injection, tracking |
| Elicitation | 10s | MCP elicitation 拦截。Breezing 中自动跳过 |
| ElicitationResult | 5s | 仅结果日志记录，轻量处理 |
| PostCompact | 15s | 上下文再注入。包含 WIP 任务状态恢复 |
| StopFailure | 10s | 仅 API 错误日志记录。无需恢复处理（v2.1.78+） |
| ConfigChange | 10s | 设置变更的审计记录 |

### Special Considerations for Stop Hooks

Stop hooks execute at session termination, so:
- Too short timeouts may interrupt processing
- 20 seconds or more recommended (D14 decision)

### Special Considerations for SessionEnd Hooks

**CC v2.1.74+**: SessionEnd 钩子的超时可通过 `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` 环境变量控制。
以前无论 `hook.timeout` 设置如何，都固定 1.5 秒后 kill。

```bash
# Harness 推荐: 对 session-cleanup（timeout: 30s）设置 45 秒
export CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS=45000
```

- 为确保 Harness 的 `session-cleanup` 钩子（hooks.json 中 timeout: 30s）可靠完成，推荐 45 秒以上
- 不设置环境变量时，应用 CC 默认值（v2.1.74+ 尊重 hook.timeout 设置）

## Hook Structure

### Event Types

```json
{
  "hooks": {
    "PreToolUse": [],      // Before tool execution
    "PostToolUse": [],     // After tool execution
    "InstructionsLoaded": [], // Instruction load completed (v2.1.69+)
    "SessionStart": [],    // At session start
    "Stop": [],            // At session end
    "SubagentStart": [],   // Subagent start
    "SubagentStop": [],    // Subagent end
    "TeammateIdle": [],    // Teammate idle event (team mode)
    "TaskCompleted": [],   // Teammate task completion event (team mode)
    "WorktreeCreate": [],  // Worktree lifecycle start
    "WorktreeRemove": [],  // Worktree lifecycle end
    "UserPromptSubmit": [],// On user input
    "PermissionRequest": [], // On permission request
    "PreCompact": [],      // Before context compaction
    "PostCompact": [],     // After context compaction (v2.1.76+)
    "Elicitation": [],     // MCP elicitation request (v2.1.76+)
    "ElicitationResult": [], // MCP elicitation result (v2.1.76+)
    "Notification": [],    // On notification dispatch
    "StopFailure": [],     // API error during session stop (v2.1.78+)
    "ConfigChange": []     // Settings change event
  }
}
```

### Teammate Event Fields (v2.1.69+)

在 `TeammateIdle` / `TaskCompleted` / 相关事件中，优先处理以下字段:

- `agent_id`（推荐键）
- `agent_type`（worker/reviewer 等）
- `session_id`（向后兼容键）

不要仅假设 `session_id` 存在，推荐先引用 `agent_id` 再 fallback 的实现。

### Stop Response Pattern (v2.1.69+)

在团队事件中想停止处理时，返回以下格式:

```json
{"continue": false, "stopReason": "all_tasks_completed"}
```

如需像以前一样继续，可以返回 `{"decision":"approve"}`。

### matcher Patterns

```json
// Match specific tool
{ "matcher": "Write|Edit|Bash" }

// Match all
{ "matcher": "*" }

// Multiple tools
{ "matcher": "Skill|Task|SlashCommand" }
```

### once Option

Execute only once per session:

```json
{
  "type": "command",
  "command": "...",
  "timeout": 30,
  "once": true  // Recommended for SessionStart
}
```

## Prohibited

- ❌ Editing only one hooks.json
- ❌ Not instructing `{ok, reason}` schema for prompt type
- ❌ Hooks without timeout
- ❌ Absolute paths other than `${CLAUDE_PLUGIN_ROOT}`
- ❌ Commits without running sync-plugin-cache.sh

## Related Decisions

- **D14**: Hook timeout optimization
- **D15**: Stop hook prompt type official spec compliance (`{ok, reason}` schema)

Details: [.claude/memory/decisions.md](../memory/decisions.md)
