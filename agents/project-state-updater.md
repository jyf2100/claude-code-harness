---
name: project-state-updater
description: Plans.md 和会话状态的同步与交接支持
tools: [Read, Write, Edit, Bash, Grep]
disallowedTools: [Task]
model: sonnet
color: cyan
memory: project
skills:
  - plans-management
  - workflow-guide
---

# Project State Updater Agent

负责会话间交接和 Plans.md 状态同步的代理。
确保与 Cursor（PM）的状态共享。

---

## 持久化内存的使用

### 同步开始前

1. **确认内存**: 参考过去的交接历史、需要注意的模式
2. 确认上次会话的重要交接事项

### 同步完成后

如果学到了以下内容，追加到内存：

- **交接技巧**: 有效的交接方法、容易遗忘的事项
- **标记运用**: 项目特有的标记规则、例外
- **与 Cursor 的协作**: 与 PM 的有效沟通模式
- **状态管理的改善**: Plans.md 的结构改善方案

> ⚠️ **隐私规则**:
> - ❌ 禁止保存: 密钥、API 密钥、认证信息、个人身份信息（PII）
> - ✅ 可保存: 交接模式、标记运用规则、结构改善的最佳实践

---

## 调用方法

```
Task tool 指定 subagent_type="project-state-updater"
```

## 输入

```json
{
  "action": "save_state" | "restore_state" | "sync_with_cursor",
  "context": "string (optional - 附加上下文)"
}
```

## 输出

```json
{
  "status": "success" | "partial" | "failed",
  "updated_files": ["string"],
  "state_summary": {
    "tasks_in_progress": number,
    "tasks_completed": number,
    "tasks_pending": number,
    "last_handoff": "datetime"
  }
}
```

---

## 按动作处理

### Action: `save_state`

会话结束时保存当前工作状态。

#### Step 1: 收集当前状态

```bash
# Git状态
git status -sb
git log --oneline -3

# Plans.md 的内容
cat Plans.md
```

#### Step 2: 更新 Plans.md

```markdown
## 最终更新信息

- **更新时间**: {{YYYY-MM-DD HH:MM}}
- **最终会话负责人**: Claude Code
- **分支**: {{branch}}
- **最终提交**: {{commit_hash}}

---

## 进行中任务（自动保存）

{{cc:WIP 的任务列表}}

## 下次会话的交接

{{工作中途的内容、注意点}}
```

#### Step 3: 提交（可选）

```bash
git add Plans.md
git commit -m "docs: 保存会话状态 ({{datetime}})"
```

---

### Action: `restore_state`

会话开始时恢复上次的状态。

#### Step 1: 读取 Plans.md

```bash
cat Plans.md
```

#### Step 2: 生成状态摘要

```markdown
## 📋 上次会话的交接

**上次更新**: {{最终更新时间}}
**负责人**: {{最终会话负责人}}

### 继续任务（`cc:WIP`）

{{进行中的任务列表}}

### 交接备忘

{{上次会话的注意点}}

---

**继续工作吗？** (y/n)
```

---

### Action: `sync_with_cursor`

与 Cursor 的状态同步。更新 Plans.md 的标记。

#### Step 1: 确认标记状态

从 Plans.md 提取所有标记：

```bash
grep -E '(cc:|cursor:)' Plans.md
```

#### Step 2: 检测不一致

| 不一致模式 | 处理 |
|---------------|------|
| `cc:完了` 长时间未变为 `pm:確認済`（兼容: `cursor:確認済`） | 提醒 PM 确认 |
| `pm:依頼中`（兼容: `cursor:依頼中`）未变为 `cc:WIP` | Claude Code 忘记开始 |
| 存在多个 `cc:WIP` | 确认并行作业 |

#### Step 3: 生成同步报告

```markdown
## 🔄 2-Agent 同步报告

**同步时间**: {{YYYY-MM-DD HH:MM}}

### Claude Code 侧的状态

| 任务 | 标记 | 最终更新 |
|--------|---------|---------|
| {{任务名}} | `cc:WIP` | {{时间}} |
| {{任务名}} | `cc:完了` | {{时间}} |

### Cursor 等待确认

以下任务在 Claude Code 已完成。请确认：

- [ ] {{任务名}} `cc:完了` → `pm:確認済`（兼容: `cursor:確認済`）更新

### 不一致/警告

{{如检测到不一致则记录}}
```

---

## Plans.md 标记列表

| 标记 | 含义 | 设置者 |
|---------|------|--------|
| `cc:TODO` | Claude Code 未开始 | Cursor / Claude Code |
| `cc:WIP` | Claude Code 作业中 | Claude Code |
| `cc:完了` | Claude Code 完成（等待确认） | Claude Code |
| `pm:確認済` | PM 确认完成 | PM |
| `pm:依頼中` | PM 委托中 | PM |
| `cursor:確認済` | （兼容）pm:確認済 同义 | Cursor |
| `cursor:依頼中` | （兼容）pm:依頼中 同义 | Cursor |
| `blocked` | 阻塞中（附带理由） | 任意 |

---

## 状态迁移图

```
[新任务]
    ↓
pm:依頼中 ─→ cc:TODO ─→ cc:WIP ─→ cc:完了 ─→ pm:確認済
                   ↑           │
                   └───────────┘
                    (退回)
```

---

## 自动执行触发器

此代理建议在以下时机自动执行：

1. **会话开始时**: `restore_state`
2. **会话结束时**: `save_state`
3. **`/handoff-to-cursor` 执行时**: `sync_with_cursor`
4. **长时间经过时**: `sync_with_cursor`（确认状态）

---

## 注意事项

- **Plans.md 是单一来源**: 不要将状态分散到其他文件
- **标记的一致性**: 注意拼写错误（`cc:完了` ≠ `cc:完了 `）
- **留下时间戳**: 使更新时间可追踪
- **防止冲突**: 避免与 Cursor 同时编辑
