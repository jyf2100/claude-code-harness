# 命令参考

双代理工作流中使用的命令详情。

---

## Claude Code 侧命令

### /setup

项目初始设置（原 `/harness-init`）。

```
/setup
```

**生成的文件**:
- Plans.md - 任务管理
- AGENTS.md - 角色分工定义
- CLAUDE.md - Claude Code 设置
- .claude/rules/ - 项目规则

---

### /setup codex

将 Codex CLI 的 Harness 设置**以用户级别**（`${CODEX_HOME:-~/.codex}`）导入/更新。

```
/setup codex
```

**生成的文件（默认）**:
- ${CODEX_HOME:-~/.codex}/skills/
- ${CODEX_HOME:-~/.codex}/rules/
- (optional) ${CODEX_HOME:-~/.codex}/config.toml

**仅 project 模式时**:
- .codex/skills/
- .codex/rules/
- AGENTS.md

---

### /plan-with-agent

任务计划/分解。

```
/plan-with-agent [任务说明]
```

**示例**:
```
/plan-with-agent 实现用户认证功能
```

**输出**: 任务添加到 Plans.md

---

### /work

执行 Plans.md 的任务。

```
/work
```

**功能**:
- 自动检测 `cc:TODO` 或 `pm:依頼中` 的任务
- 支持多个任务并行执行
- 完成时自动更新为 `cc:完了`

---

### /sync-status

输出当前状态摘要。

```
/sync-status
```

**输出示例**:
```
📊 当前状态
- 进行中: 2件
- 未开始: 5件
- 完成（待确认）: 1件
```

---

### /handoff-to-cursor

向 Cursor PM 的完成报告。

```
/handoff-to-cursor
```

**包含的信息**:
- 完成的任务列表
- 变更的文件
- 测试结果
- 下一步行动建议

---

## Cursor 侧命令（参考）

### /handoff-to-claude

向 Claude Code 的任务请求。

### /review-cc-work

审查 Claude Code 的完成报告。
如果无法批准（request_changes）则更新 Plans.md，**用 `/claude-code-harness/handoff-to-claude` 生成修正请求文并直接传递**。

---

## 技能（会话中自动启动）

### handoff-to-pm

**触发**: 「向PM完成报告」「报告工作完成」

生成 Worker → PM 的完成报告。

### handoff-to-impl

**触发**: 「交给实现者」「向 Claude Code 请求」

整理 PM → Worker 的任务请求。

---

## 命令使用流程

```
[会话开始]
    │
    ▼
/sync-status  ←── 确认现状
    │
    ▼
/work  ←── 执行任务
    │
    ▼
/handoff-to-cursor  ←── 完成报告
    │
    ▼
[会话结束]
```
