---
name: harness-review
description: "Harness v3 统一审查技能。代码・计划・范围多角度审查。以下启动: 审查、代码审查、计划审查、范围分析、安全、质量检查、harness-review。不用于实现・新功能・错误修复・设置・发布。"
description-en: "Unified review skill for Harness v3. Multi-angle code, plan, and scope review. Use when user mentions: review, code review, plan review, scope analysis, security, performance, quality checks, PRs, diffs, harness-review. Do NOT load for: implementation, new features, bug fixes, setup, or release."
description-ja: "Harness v3 统一审查技能。代码・计划・范围多角度审查。以下短语启动: 审查、代码审查、计划审查、范围分析、安全、质量检查、harness-review。不用于实现・新功能・错误修复・设置・发布。"
allowed-tools: ["Read", "Grep", "Glob", "Bash", "Task"]
argument-hint: "[code|plan|scope]"
context: fork
---

# Harness Review (v3)

Harness v3 的统一审查技能。
整合了以下旧技能:

- `harness-review` — 代码・计划・范围多角度审查
- `codex-review` — Codex CLI 第二意见
- `verify` — 构建验证・错误恢复・审查修正应用
- `troubleshoot` — 错误・故障的诊断和修复

## Quick Reference

| 用户输入 | 子命令 | 动作 |
|------------|------------|------|
| "审查" / "review" | `code`（自动） | 代码审查（最近的变更） |
| "`harness-plan` 执行后" | `plan`（自动） | 计划审查 |
| "范围确认" | `scope`（自动） | 范围分析 |
| `harness-review code` | `code` | 强制代码审查 |
| `harness-review plan` | `plan` | 强制计划审查 |
| `harness-review scope` | `scope` | 强制范围分析 |

## 审查类型自动判定

| 最近的活动 | 审查类型 | 观点 |
|--------------------|--------------|------|
| `harness-work` 后 | **Code Review** | Security, Performance, Quality, Accessibility, AI Residuals |
| `harness-plan` 后 | **Plan Review** | Clarity, Feasibility, Dependencies, Acceptance |
| 任务添加后 | **Scope Review** | Scope-creep, Priority, Feasibility, Impact |

## Code Review 流程

### Step 1: 收集变更差异

```bash
# 如果 harness-work 传入了 BASE_REF 则使用，否则回退到 HEAD~1
CHANGED_FILES="$(git diff --name-only --diff-filter=ACMR "${BASE_REF:-HEAD~1}")"
git diff ${BASE_REF:-HEAD~1} --stat
git diff ${BASE_REF:-HEAD~1} -- ${CHANGED_FILES}
```

### Step 1.5: AI Residuals 静态扫描

不只靠 LLM 的印象判断，而是以可重复执行的方式拾取残留候补。`scripts/review-ai-residuals.sh` 返回稳定的 JSON，将其结果作为审查依据。

```bash
# 基于差异
AI_RESIDUALS_JSON="$(bash scripts/review-ai-residuals.sh --base-ref "${BASE_REF:-HEAD~1}")"

# 想要明确指定目标文件时
bash scripts/review-ai-residuals.sh path/to/file.ts path/to/config.sh
```

### Step 2: 5 个观点审查

| 观点 | 检查内容 |
|------|------------|
| **Security** | SQL注入, XSS, 敏感信息泄露, 输入验证 |
| **Performance** | N+1查询, 不必要的重新渲染, 内存泄漏 |
| **Quality** | 命名, 单一职责, 测试覆盖率, 错误处理 |
| **Accessibility** | ARIA属性, 键盘导航, 颜色对比度 |
| **AI Residuals** | `mockData`, `dummy`, `fake`, `localhost`, `TODO`, `FIXME`, `it.skip`, `describe.skip`, `test.skip`, 硬编码的敏感信息/环境依赖 URL, 明显的临时实现注释 |

### Step 2.2: AI Residuals 的 severity 判定表

`AI Residuals` 首先确认 `scripts/review-ai-residuals.sh` 的 JSON，然后在 diff 上下文中最终判断"是否真的有发布风险"。

| 严重度 | 代表例 | 判定思路 |
|--------|--------|-------------|
| **major** | `localhost` / `127.0.0.1` / `0.0.0.0` 连接目标、`it.skip` / `describe.skip` / `test.skip`、疑似硬编码敏感信息的值、dev/staging 固定 URL | 容易导致生产事故、错误配置、验证遗漏。1 件即 `REQUEST_CHANGES` |
| **minor** | `mockData`, `dummy`, `fakeData`, `TODO`, `FIXME` | 残留可能性高但不一定会立即导致事故。建议修正但不改变 verdict |
| **recommendation** | `temporary implementation`, `replace later`, `placeholder implementation` 等临时实现注释 | 仅凭注释不能断定有 bug，但希望追踪和明确化 |

### Step 2.5: 基于阈值标准的 verdict 判定

将各指摘分类为以下严重度，**仅以此标准**决定 verdict。

| 严重度 | 定义 | 对 verdict 的影响 |
|--------|------|-----------------|
| **critical** | 安全漏洞、数据丢失风险、可能导致生产故障 | 1 件即 → REQUEST_CHANGES |
| **major** | 破坏现有功能、与规格明确矛盾、测试不通过 | 1 件即 → REQUEST_CHANGES |
| **minor** | 命名改进、注释不足、风格不统一 | 不影响 verdict |
| **recommendation** | 最佳实践建议、将来改进方案 | 不影响 verdict |

> **重要**: 仅 minor / recommendation 时 **必须返回 APPROVE**。
> "最好有的改进"不能作为 REQUEST_CHANGES 的理由。
> `AI Residuals` 也一样。只有"容易导致发布事故或错误配置的"才归入 `major`，单纯残留候补保持在 `minor` 或 `recommendation`。

### Step 3: 审查结果输出

```json
{
  "verdict": "APPROVE | REQUEST_CHANGES",
  "critical_issues": [],
  "major_issues": [],
  "observations": [
    {
      "severity": "critical | major | minor | recommendation",
      "category": "Security | Performance | Quality | Accessibility | AI Residuals",
      "location": "文件名:行号",
      "issue": "问题描述",
      "suggestion": "修正方案"
    }
  ],
  "recommendations": ["非必须的改进建议"]
}
```

### Step 4: 提交判定

- **APPROVE**: 执行自动提交（除非 `--no-commit`）
- **REQUEST_CHANGES**: 提示 critical/major 的指摘点和修正方向。在 `harness-work` 的修正循环中自动修正后再次审查（最多 3 次）

## Plan Review 流程

1. 读取 Plans.md
2. 以以下 **5 个观点** 审查:
   - **Clarity**: 任务说明是否明确
   - **Feasibility**: 技术上是否可实现
   - **Dependencies**: 任务间的依赖关系是否正确（Depends 列与实际依赖是否一致）
   - **Acceptance**: 完成条件（DoD 列）是否已定义且可验证
   - **Value**: 这个任务是否解决用户问题？
     - 是否明确了"谁的、什么问题"
     - 是否考虑了替代方案（不做的选项）
     - 是否存在 Elephant（所有人都注意到但被搁置的问题）
3. DoD / Depends 列的质量检查:
   - DoD 为空的任务 → 警告（"完成条件未定义"）
   - DoD 不可验证（"感觉不错"、"正常运行"等） → 警告 + 具体化建议
   - Depends 中存在不存在的任务编号 → 错误
   - 循环依赖 → 错误
4. 提出改进建议

## Scope Review 流程

1. 列出追加的任务/功能
2. 以以下观点分析:
   - **Scope-creep**: 偏离最初范围
   - **Priority**: 优先级是否适当
   - **Feasibility**: 现有资源是否可实现
   - **Impact**: 对现有功能的影响
3. 提示风险和推荐行动

## 异常检测

| 情况 | 动作 |
|------|----------|
| 安全漏洞 | 立即 REQUEST_CHANGES |
| 疑似测试篡改 | 警告 + 修正要求 |
| 尝试 force push | 拒绝 + 提出替代方案 |

## Codex Environment

在 Codex CLI 环境（`CODEX_CLI=1`）中，部分工具不可用，因此使用以下回退。

| 通常环境 | Codex 回退 |
|---------|-------------------|
| 用 `TaskList` 获取任务列表 | 用 `Read` 读取 Plans.md 确认 WIP/TODO 任务 |
| 用 `TaskUpdate` 更新状态 | 用 `Edit` 直接更新 Plans.md 标记（例: `cc:WIP` → `cc:完了`） |
| 将审查结果写入 Task | 将审查结果输出到 stdout |

### 检测方法

```bash
if [ "${CODEX_CLI:-}" = "1" ]; then
  # Codex 环境: 基于 Plans.md 的回退
fi
```

### Codex 环境中的审查输出

由于不支持 Task 工具，审查结果以 markdown 格式输出到标准输出。
Lead 代理或用户读取结果，判断下一步行动。

## 相关技能

- `harness-work` — 审查后实现修正
- `harness-plan` — 创建・修正计划
- `harness-release` — 审查通过后发布
