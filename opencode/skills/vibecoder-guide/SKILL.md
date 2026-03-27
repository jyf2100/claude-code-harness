---
name: vibecoder-guide
description: "指导 VibeCoder（非技术用户）进行自然语言开发。Use when user asks what to do next, how to use the system, needs help, or is stuck. Do NOT load for: technical-user work, direct implementation requests, or reviews."
description-en: "Guides VibeCoder (non-technical users) through natural language development. Use when user asks what to do next, how to use the system, needs help, or is stuck. Do NOT load for: technical-user work, direct implementation requests, or reviews."
description-ja: "指导 VibeCoder（非技术用户）进行自然语言开发。Use when user asks what to do next, how to use the system, needs help, or is stuck. Do NOT load for: technical-user work, direct implementation requests, or reviews."
allowed-tools: ["Read"]
user-invocable: false
---

# VibeCoder Guide Skill

指导 VibeCoder（非技术人员）仅用自然语言进行开发的技能。
自动响应「该怎么做？」「接下来做什么？」等问题。

---

## 触发短语

此技能在以下短语下自动启动：

- 「该怎么做？」「应该怎么做？」
- 「接下来做什么？」「接下来？」
- 「能做什么？」「应该做什么？」
- 「遇到困难」「不明白」「帮帮我」
- 「告诉我使用方法」
- "what should I do?", "what's next?", "help"

---

## 概要

VibeCoder 不需要了解技术命令或工作流，
只需用自然的中文提问就能知道下一步行动。

---

## 响应模式

### 模式1: 没有项目时

> 🎯 **首先开始一个项目吧！**
>
> **说法示例：**
> - 「我想做一个博客」
> - 「我想做一个任务管理应用」
> - 「我想做一个作品集网站」
>
> 粗略的描述也可以。请告诉我你想做什么。

### 模式2: 有 Plans.md 但没有进行中任务

> 📋 **有计划。让我们开始工作吧！**
>
> **当前计划：**
> - Phase 1: 基础搭建
> - Phase 2: 核心功能
> - ...
>
> **说法示例：**
> - 「开始 Phase 1」
> - 「做第一个任务」
> - 「全部做」

### 模式3: 任务进行中

> 🔧 **工作中**
>
> **当前任务：** {{任务名}}
> **进度：** {{完成数}}/{{总数}}
>
> **说法示例：**
> - 「继续」
> - 「下一个任务」
> - 「现在进展到哪里了？」

### 模式4: Phase 完成后

> ✅ **Phase 完成了！**
>
> **接下来可以做的：**
> - 「确认运行」→ 启动开发服务器
> - 「审查」→ 代码质量检查
> - 「进入下一个 Phase」→ 开始下一个工作
> - 「提交」→ 保存变更

### 模式5: 发生错误时

> ⚠️ **发生了问题**
>
> **情况：** {{错误摘要}}
>
> **说法示例：**
> - 「修复」→ 尝试自动修复
> - 「说明」→ 说明问题详情
> - 「跳过」→ 进入下一个任务

---

## 常用短语对应表

| 想做的事 | 说法 |
|-------------|--------|
| 开始项目 | 「我想做某某」 |
| 查看计划 | 「给我看计划」「现在情况如何？」 |
| 开始工作 | 「开始」「做」「做 Phase 1」 |
| 继续工作 | 「继续」「下一个」 |
| 确认运行 | 「运行」「给我看」 |
| 确认代码 | 「审查」「检查」 |
| 保存 | 「提交」「保存」 |
| 遇到困难时 | 「该怎么做？」「帮帮我」 |
| 全部委托 | 「全部做」「交给你」 |

---

## 上下文判断

此技能确认以下内容并选择适当的响应：

1. **AGENTS.md 是否存在** → 项目是否已初始化
2. **Plans.md 的内容** → 是否有计划、进度情况
3. **当前任务状态** → 是否有 `cc:WIP` 标记
4. **最近的错误** → 是否发生了问题

---

## 实现说明

此技能启动后：

1. 分析当前状态
2. 选择适当的模式
3. 提供具体的「说法示例」
4. 等待用户的下一步行动

**重要**: 避免使用技术术语，用平易的中文说明
