# Harness for OpenCode

这是 Claude Code Harness 的 opencode.ai 兼容版。

## 设置方法

### 方法 1: 一键设置（推荐）

即使没有 Claude Code，也可以使用以下命令进行设置：

```bash
cd your-project
curl -fsSL https://raw.githubusercontent.com/Chachamaru127/claude-code-harness/main/scripts/setup-opencode.sh | bash
```

一次性设置包括 Unified Memory：

```bash
cd your-project
/path/to/claude-code-harness/scripts/harness-mem setup --platform opencode
```

### 方法 2: 从 Claude Code 设置

如果正在使用 Claude Code，一条命令即可设置：

```bash
# 在 Claude Code 内执行
/opencode-setup
```

### 方法 3: 手动设置

```bash
# 克隆 Harness
git clone https://github.com/Chachamaru127/claude-code-harness.git

# 复制 opencode 用命令
cp -r claude-code-harness/opencode/commands/ your-project/.opencode/commands/
cp claude-code-harness/opencode/AGENTS.md your-project/AGENTS.md
```

---

## MCP 服务器设置（可选）

使用 MCP 服务器可以直接从 opencode 调用 Harness 的工作流工具。

```bash
# 构建 MCP 服务器
cd claude-code-harness/mcp-server
npm install
npm run build

# 复制 opencode.json 到项目并调整路径
cp claude-code-harness/opencode/opencode.json your-project/
# 更改 opencode.json 内的路径为实际路径
```

同时使用 Unified memory daemon（共享DB）时：

```bash
# 启动 memory daemon
./scripts/harness-memd start

# 确认 health
./scripts/harness-mem-client.sh health
```

或使用 `harness-mem` 执行诊断：

```bash
/path/to/claude-code-harness/scripts/harness-mem doctor --platform opencode --fix
```

---

## 可用命令

| 命令 | 说明 |
|----------|------|
| `/harness-init` | 项目设置 |
| `/plan-with-agent` | 开发计划创建 |
| `/work` | 任务执行 |
| `/harness-review` | 代码审查 |
| `/sync-status` | 进度确认 |
| `/handoff-to-opencode` | 生成给 OpenCode PM 的完成报告 |

---

## PM 模式（在 OpenCode 中进行计划管理）

将 OpenCode 作为 PM (Project Manager) 使用时的命令：

| 命令 | 说明 |
|----------|------|
| `/start-session` | 会话开始（情况把握→计划） |
| `/plan-with-cc` | 计划创建（包含 Evals） |
| `/project-overview` | 项目概要把握 |
| `/handoff-to-claude` | 生成给 Claude Code 的委托 |
| `/review-cc-work` | 作业审查·批准 |

### 工作流（PM 模式）

```
OpenCode (PM)                    Claude Code (Impl)
    |                                   |
    | /start-session                    |
    | /plan-with-cc                     |
    | /handoff-to-claude ─────────────> |
    |                                   | /work
    |                                   | /handoff-to-opencode
    | <─────────────────────────────────|
    | /review-cc-work                   |
    |    ├── approve → 下一任务 ────────>|
    |    └── request_changes ──────────>|
```

---

## MCP 工具

通过 MCP 服务器可以使用以下工具：

| 工具 | 说明 |
|--------|------|
| `harness_workflow_plan` | 计划创建 |
| `harness_workflow_work` | 任务执行 |
| `harness_workflow_review` | 代码审查 |
| `harness_session_broadcast` | 会话间通知 |
| `harness_status` | 状态确认 |
| `harness_mem_resume_pack` | 获取恢复上下文 |
| `harness_mem_search` | 共享内存搜索 |
| `harness_mem_record_checkpoint` | 记录检查点 |
| `harness_mem_finalize_session` | 确定会话 |

---

## 使用方法

```bash
# 启动 opencode
cd your-project
opencode

# 执行命令
/plan-with-agent  # 计划创建
/work             # 任务执行
/harness-review   # 代码审查
```

---

## 限制事项

- Harness 插件系统（`.claude-plugin/`）在 opencode 中无法使用
- memory hooks 通过 `opencode/plugins/harness-memory/index.ts` 提供（`chat.message` / `session.idle` / `session.compacted`）
- `description-en` 字段会被自动删除

---

## 相关链接

- [Claude Code Harness](https://github.com/Chachamaru127/claude-code-harness)
- [OpenCode Documentation](https://opencode.ai/docs/)
- [OpenCode Commands](https://opencode.ai/docs/commands/)
