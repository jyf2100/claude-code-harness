---
description: CC 更新跟踪时的质量策略
globs: ["CLAUDE.md", "docs/CLAUDE-feature-table.md"]
---

# CC 更新跟踪策略

Claude Code 新版本对应时更新 Feature Table 的质量标准。

## 基本原则

Feature Table 的添加必须伴随**相应的实现更改**或**类别 C（CC 自动继承）的明确分类**。

不允许在"仅向 Feature Table 添加行"的状态下合并 PR。

## 3 类别分类

| 类别 | 定义 | PR 合并 |
|---------|------|----------|
| **(A) 有实现** | hooks / scripts / agents / skills / core 有相应的实现更改 | 可 |
| **(B) 仅书写** | 仅更改 Feature Table。无实现 | **不可** -- 必须提出实现方案 |
| **(C) CC 自动继承** | CC 本体的修复，Harness 侧无需更改（性能改进、错误修复等） | 可（在 Feature Table 中明确标注"CC 自动继承"） |

## 规则

### 1. Feature Table 添加必须伴随实现或分类

向 Feature Table 添加新行时，必须满足以下任一条件:

- **(A)** 同一 PR 中包含相应的实现文件更改
- **(C)** Feature Table 中明确标注为"CC 自动继承"

若均不符合，则该项目被判定为类别 B（仅书写）。

### 2. 检测到类别 B 时阻止 PR 并要求实现方案

若存在 1 件及以上类别 B 的项目:

- **阻止** PR 的合并
- 对每个类别 B 项目，要求提出包含以下内容的**实现方案**:
  - Harness 独有附加价值的说明
  - 变更目标文件和具体变更内容
  - 用户体验的改善（以前 / 以后）

实现方案获得批准后，创建包含实现的额外提交或后续 PR。

### 3. 推荐添加"附加价值"列

推荐在 Feature Table 中添加可视化 A / B / C 分类的"附加价值"列。

```markdown
| Feature | Skill | Purpose | 附加价值 |
|---------|-------|---------|---------|
| PostCompact 钩子 | hooks | 上下文再注入 | A: 有实现 |
| Streaming leak fix | all | 内存泄漏修复 | C: CC 自动继承 |
```

通过此列:
- 审查时可立即发现类别 B 的残留
- Feature Table 的各项目自我文档化"为什么在这里"
- 将来 CC 更新整合时可参照过去的判断

## 适用范围

本策略适用于以下文件的更改:

- `CLAUDE.md` 的 Feature Table 部分
- `docs/CLAUDE-feature-table.md`

不适用于通常的实现 PR、文档修正、发布作业。
