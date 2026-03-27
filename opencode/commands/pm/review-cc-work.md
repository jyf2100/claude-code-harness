---
description: 审查 Claude Code 的作业，并交接批准/修正指示
---

# /review-cc-work

你是 **OpenCode (PM)**。接收 Claude Code 的完成报告（/handoff-to-opencode 的输出），审查变更。

**重要**: 审查后，无论是批准还是修正，都会生成 **Hand off to Claude**。

## 步骤

### Step 1: 实施审查

1. 把握变更文件/差异要点（通过 `git diff` 或完成报告）
2. 对照验收条件进行判定
3. 从质量、安全、性能角度检查
4. **确认 Evals**: 确认是否提供了基于 Plans.md "评估（Evals）"的验证（测试/日志/基准等），结果是否合理

### Step 2: 判定

| 判定 | 条件 | 下一步行动 |
|------|------|---------------|
| **approve** | 满足验收条件 | 将 Plans.md 的相应任务更改为 `pm:确认済` → 提交指示 → **在此结束**（仅在用户明确要求时进行下一任务） |
| **request_changes** | 需要修正 | 汇总修正指示 → 生成交接 |

> **Commit Pending 的情况**: 如果完成报告包含"Commit Status: Pending PM Approval"，在 approve 时的交接中**必须包含提交指示**（参见下文的 approve 模板）。

### Step 3: 生成交接（必填）

无论哪种情况，都要生成传递给 Claude Code 的交接消息。

---

## 输出格式

### 判定摘要

```
## 审查结果

**判定**: approve / request_changes
**理由**:
- （1〜3点）

**Plans.md 更新**:
- `[任务名]` → 更改为 `pm:确认済`（approve 的情况）
```

### Hand off to Claude（必须输出）

#### approve 的情况则提交并结束

**默认行为**: approve 时提交变更并结束。仅在用户明确要求时才生成下一任务的交接。

##### 仅批准（默认）

批准 → 提交指示 → **在此结束**。不自动过渡到下一任务。

~~~markdown
/claude-code-harness:core:work
<!-- ultrathink: 来自 PM 的委托原则上为重要任务，因此始终指定 high effort -->
ultrathink

## 委托

上次的任务已批准。请提交变更。

### 提交指示
- 批准上次的变更。请提交。
- 提交后，工作完成。

### 参考
- 相关文件（如有）

提交完成后请用 `/handoff-to-opencode` 报告。
~~~

##### 仅在用户明确要求下一任务时

仅在用户明确表示"继续下一任务""继续"等时，使用以下模板：

从 @Plans.md 分析下一个 `cc:TODO` 或 `pm:依頼中` 任务，生成以下内容：

~~~markdown
/claude-code-harness:core:work
ultrathink

## 委托

上次的任务已批准。**先提交变更**，然后实现下一任务。

### 提交指示
- 批准上次的变更。提交后进入下一任务。

### 目标任务
- （从 Plans.md 提取下一任务）

### 背景
- 由于上一任务完成并批准，可以开始
- （如有依赖关系请记载）

### 约束
- 遵循现有代码风格
- 变更保持最小必要
- 确认测试/构建通过

### 验收条件
- （3〜5个，具体地）

### 参考
- 相关文件（如有）

完成后请用 `/handoff-to-opencode` 报告。
~~~

#### request_changes 的情况

生成包含修正指示的交接：

~~~markdown
/claude-code-harness:core:work
ultrathink

## 修正委托

审查结果显示需要以下修正。

### 修正目标任务
- （Plans.md 的相应任务）

### 指出事项
1. **[重要度: 高/中/低]** 指出内容
   - 相应位置: `文件名:行号`
   - 期望的修正: 具体的对应方法

2. **[重要度: 高/中/低]** 指出内容
   - 相应位置:
   - 期望的修正:

### 约束
- 不要破坏现有测试
- 不要修改指出位置以外的内容

### 验收条件（修正后）
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
pm:确认済   创建修正指示
   ↓         ↓
commit      生成交接
   ↓         ↓
 结束        ↓
(下一任务仅     ↓
 明确要求      ↓
 时)          ↓
   ↓         ↓
   └────┬────┘
        ↓
  粘贴到 Claude Code
        ↓
     /work 执行
```
