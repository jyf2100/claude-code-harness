---
_harness_template: rules/skill-hierarchy.md
_harness_version: 2.6.1
---

# Skill 层次结构指南

## 概要

claude-code-harness 的技能采用 **父技能（类别）** 和 **子技能（具体功能）** 的2层结构。

```
skills/
├── impl/                      # 父技能（SKILL.md）
│   ├── SKILL.md              # 类别概要・路由
│   └── work-impl-feature/    # 子技能
│       └── doc.md            # 具体步骤
├── harness-review/
│   ├── SKILL.md
│   ├── code-review/
│   │   └── doc.md
│   └── security-review/
│       └── doc.md
...
```

## 必须规则

### 1. 读取父技能后，也要读取子技能

使用 Skill 工具启动父技能后，**必须用 Read 工具读取与用户意图对应的子技能（doc.md）**。

```
✅ 正确流程:
1. 用 Skill 工具启动 "impl" → 获取 SKILL.md 内容
2. 判断用户意图（例: 功能实现）
3. 用 Read 工具读取 work-impl-feature/doc.md
4. 按照 doc.md 的步骤作业

❌ 错误:
1. 用 Skill 工具启动 "impl"
2. 只读 SKILL.md 就开始作业（忽略子技能）
```

### 2. 子技能的选择方法

| 用户意图 | 启动的技能 | 应读取的子技能 |
|---------------|---------------|-----------------|
| "实现功能" | impl | work-impl-feature/doc.md |
| "进行代码审查" | harness-review | code-review/doc.md |
| "安全检查" | harness-review | security-review/doc.md |
| "构建验证" | verify | build-verify/doc.md |

### 3. 多个子技能都适用时

向用户确认，或选择最相关的1个开始。

---

## 为什么重要？

- 父 SKILL.md 只有"概要和路由"
- 子 doc.md 包含"具体步骤、检查清单、模式集"
- 不读取子技能会导致作业不完整

---

## 与 PostToolUse Hook 的联动

Skill 工具使用后会自动显示提醒。
从显示的子技能列表中，用 Read 读取相应的技能。
