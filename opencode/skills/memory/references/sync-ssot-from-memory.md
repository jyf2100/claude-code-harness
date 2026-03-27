# Sync SSOT from Memory Reference

将内存系统（Harness Memory 或 Serena）中记录的重要观察提升到项目的 SSOT：
`.claude/memory/decisions.md` 和 `.claude/memory/patterns.md`。

---

## VibeCoder Phrases

- "**保存我们学到的内容供下次使用**" → 此命令
- "**将重要决策提升到 SSOT**" → 此命令
- "**分别整理决策（why）和方法（how）**" → 分别反映到 decisions/patterns
- "**不知道该保留什么**" → 按重要性过滤并只推荐候选项

---

## 支持的内存系统

| System | Detection | How to Get Observations |
|--------|-----------|------------------------|
| **Harness Memory** | `harness_mem_*` MCP 可用 | `harness_mem_search` / `harness_mem_timeline` |
| **Serena** | `.serena/memories/` | `mcp__serena__read_memory` |

执行时自动检测，使用可用的系统。

---

## Step 0: 内存系统检测

```bash
# Harness Memory 检查
if command -v harness_mem_search >/dev/null 2>&1; then
  MEMORY_SYSTEM="harness-mem"
fi

# Serena 检查
if [ -d ".serena/memories" ]; then
  MEMORY_SYSTEM="serena"
fi
```

**如果都不存在**: 切换到手动输入模式。

---

## Step 1: 提取 SSOT 提升候选项

**对于 Harness Memory**:
```
mem-search: type:decision
mem-search: type:discovery concepts:pattern
mem-search: type:bugfix concepts:gotcha
```

**对于 Serena**:
```
mcp__serena__list_memories
mcp__serena__read_memory (目标内存)
```

---

## Step 2: 按提升标准过滤

### 决策候选项（Why）→ `decisions.md`

| Observation Type | Concept | Criteria |
|------------------|---------|----------|
| `decision` | `why-it-exists`, `trade-off` | 技术选型理由 |
| `guard` | `test-quality`, `implementation-quality` | 护栏理由 |
| `discovery` | `user-intent` | 用户需求/约束 |

### 模式候选项（How）→ `patterns.md`

| Observation Type | Concept | Criteria |
|------------------|---------|----------|
| `bugfix` | `problem-solution` | 防止再发 |
| `discovery` | `pattern`, `how-it-works` | 可复用解决方案 |
| `feature`, `refactor` | `pattern` | 实现模式 |

### 排除项

- 进行中的粗糙笔记（低置信度）
- 个人/机密信息
- 一次性任务（不可复用）

---

## Step 3: 反映到 SSOT（去重）

### decisions.md 格式

```markdown
## D{N}: {Title}

**Date**: YYYY-MM-DD
**Tags**: #decision #{keywords}
**Observation ID**: #{original ID}

### 结论
{采用的结论}

### 背景
{为什么需要这个决策}

### 选项
1. {选项 A}: {优缺点}
2. {选项 B}: {优缺点}

### 采用理由
{为什么选择这个选项}

### 影响
{影响范围}

### 复审条件
{何时重新考虑}
```

### patterns.md 格式

```markdown
## P{N}: {Title}

**Date**: YYYY-MM-DD
**Tags**: #pattern #{keywords}
**Observation ID**: #{original ID}

### 问题
{这个解决了什么问题}

### 解决方案
{如何解决}

### 应用条件
{何时使用}

### 不应用条件
{何时不使用}

### 示例
{代码或步骤}

### 注意事项
{需要注意的陷阱}
```

---

## Step 4: 变更摘要

```markdown
## 📚 SSOT 提升结果

### 已添加/更新
| File | Item | Observation ID |
|------|------|----------------|
| decisions.md | D12: RBAC | #9602 |
| patterns.md | P8: CORS | #9584 |

### 待处理（需审查）
| ID | Title | Reason |
|----|-------|--------|
| #9590 | API Draft | 未最终确定 |

### 已排除
- 进行中: 5 项
- 重复: 2 项
```

---

## 防止重复

在 SSOT 条目中记录观察 ID 可防止重复提升。

---

## 失败时回退

如果内存系统无法访问：
1. 请求用户粘贴观察内容
2. 应用相同流程

```
> 无法访问内存系统。
> 请粘贴要提升的信息。
```
