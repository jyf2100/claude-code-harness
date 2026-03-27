---
description: 审查Claude Code的工作，并交接批准/修改指示
---

# /review-cc-work

你是 **OpenCode (PM)**。接收 Claude Code 的完成报告（/handoff-to-opencode 的输出），并审查变更。

**重要**: 审查后，无论是批准还是需要修改，都要生成 **Hand off to Claude**。

## 步骤

### Step 1: 执行审查

1. 把握变更文件/差异要点（`git diff` 或从完成报告获取）
2. 对照验收条件进行判定
3. 从质量、安全、性能角度进行检查
4. **确认 Evals**: Plans.md 的"评价（Evals）"所基于的验证（测试/日志/基准等）是否已提供，结果是否合理

### Step 2: 判定

| 判定 | 条件 | 下一步行动 |
|------|------|------------|
| **approve** | 满足验收条件 | 将 Plans.md 的相应任务改为 `pm:已确认` → 提交指示 → **在此结束**（仅在用户明确要求时才进行下一任务） |
| **request_changes** | 需要修改 | 汇总修改指示 → 生成交接 |

> **Commit Pending 的情况**: 如果完成报告中包含"Commit Status: Pending PM Approval"，approve 时的交接 **必须包含提交指示**（参见后面的 approve 模板）。

### Step 3: 生成交接（必须）

无论哪种情况，都要生成传递给 Claude Code 的交接消息。

---

## 输出格式

### 判定摘要

```
## 审查结果

**判定**: approve / request_changes
**理由**:
- （1-3点）

**Plans.md 更新**:
- `[任务名]` → 改为 `pm:已确认`（approve 时）
```

### Hand off to Claude（必须输出）

#### approve 时提交并结束

**默认行为**: approve 时提交变更并结束。仅在用户明确要求时才生成下一任务的交接。

##### 仅批准（默认）

批准 → 提交指示 → **在此结束**。不自动过渡到下一任务。

~~~markdown
/claude-code-harness:core:work
<!-- ultrathink: PM 的请求原则上都是重要任务，因此始终指定 high effort -->
ultrathink

## 请求

上一个任务已批准。请提交更改。

### 提交指示
- 批准上次的更改。请提交。
- 提交后，工作即完成。

### 参考
- 相关文件（如有）

提交完成后请用 `/handoff-to-opencode` 报告。
~~~

##### 仅当用户明确要求下一任务时

仅当用户明确说"进行下一任务""继续"等时，使用以下模板：

从 @Plans.md 分析下一个 `cc:TODO` 或 `pm:请求中` 任务，生成以下内容：

~~~markdown
/claude-code-harness:core:work
ultrathink

## 请求

上一个任务已批准。**请先提交更改**，然后实现下一个任务。

### 提交指示
- 批准上次的更改。请先提交再进入下一个任务。

### 目标任务
- （从 Plans.md 提取下一个任务）

### 背景
- 由于上个任务完成并批准，现在可以开始
- （如有依赖关系请说明）

### 约束
- 遵循现有代码风格
- 更改保持在最小限度
- 确保测试/构建通过

### 验收条件
- （3-5个，具体地）

### 参考
- 相关文件（如有）

完成后请用 `/handoff-to-opencode` 报告。
~~~

#### request_changes 时

生成包含修改指示的交接：

~~~markdown
/claude-code-harness:core:work
ultrathink

## 修改请求

审查结果需要进行以下修改。

### 修改目标任务
- （Plans.md 的相关任务）

### 指出事项
1. **[重要度: 高/中/低]** 指出内容
   - 相关位置: `文件名:行号`
   - 期待修改: 具体对应方法

2. **[重要度: 高/中/低]** 指出内容
   - 相关位置:
   - 期待修改:

### 约束
- 不要破坏现有测试
- 不要更改指出位置以外的内容

### 验收条件（修改后）
- 上述指出事项全部解决
- 测试/构建通过
- （如有追加条件）

完成后请用 `/handoff-to-opencode` 报告。
~~~

---

## 工作流图

```
Claude Code 完成报告
        ↓
  /review-cc-work
        ↓
   ┌────┴────┐
   ↓         ↓
approve   request_changes
   ↓         ↓
pm:已确认   创建修改指示
   ↓         ↓
commit      生成交接
   ↓         ↓
 结束        ↓
(下一任务     ↓
 明确要求     ↓
 时才进行)    ↓
   ↓         ↓
   └────┬────┘
        ↓
  粘贴到 Claude Code
        ↓
     /work 执行
```
