---
name: harness-review
description: "Harness v3 统一审查技能。多角度审查代码、计划、范围。触发短语：审查、代码审查、计划审查、范围分析、安全、性能、质量检查、PR、diff、harness-review。不用于：实现、新功能、bug 修复、设置或发布。"
description-en: "Unified review skill for Harness v3. Multi-angle code, plan, and scope review. Use when user mentions: review, code review, plan review, scope analysis, security, performance, quality checks, PRs, diffs, harness-review. Do NOT load for: implementation, new features, bug fixes, setup, or release."
description-zh: "Harness v3 统一审查技能。多角度审查代码、计划、范围。触发短语：审查、代码审查、计划审查、范围分析、安全、性能、质量检查、PR、diff、harness-review。不用于：实现、新功能、bug 修复、设置或发布。"
allowed-tools: ["Read", "Grep", "Glob", "Bash", "Task"]
argument-hint: "[code|plan|scope]"
context: fork
---

# Harness Review (v3)

Harness v3 的统一审查技能。
整合了以下旧技能：

- `harness-review` — 代码、计划、范围多角度审查
- `codex-review` — Codex CLI 第二意见
- `verify` — 构建验证、错误恢复、审查修改应用
- `troubleshoot` — 错误、故障诊断和修复

## 快速参考

| 用户输入 | 子命令 | 操作 |
|---------|-------|------|
| "审查" / "review" | `code`（自动） | 代码审查（最近变更） |
| "`harness-plan` 执行后" | `plan`（自动） | 计划审查 |
| "范围确认" | `scope`（自动） | 范围分析 |
| `harness-review code` | `code` | 强制代码审查 |
| `harness-review plan` | `plan` | 强制计划审查 |
| `harness-review scope` | `scope` | 强制范围分析 |

## 审查类型自动判断

| 最近的活动 | 审查类型 | 观点 |
|-----------|---------|------|
| `harness-work` 后 | **Code Review** | Security, Performance, Quality, Accessibility, AI Residuals |
| `harness-plan` 后 | **Plan Review** | Clarity, Feasibility, Dependencies, Acceptance |
| 任务添加后 | **Scope Review** | Scope-creep, Priority, Feasibility, Impact |

## Code Review 流程

### Step 1: 收集变更差异

```bash
# 如果 harness-work 传递了 BASE_REF 则使用，否则回退到 HEAD~1
CHANGED_FILES="$(git diff --name-only --diff-filter=ACMR "${BASE_REF:-HEAD~1}")"
git diff ${BASE_REF:-HEAD~1} --stat
git diff ${BASE_REF:-HEAD~1} -- ${CHANGED_FILES}
```

### Step 1.5: AI Residuals 静态扫描

不只靠 LLM 印象判断，以可重复执行的形式收集残留候选。`scripts/review-ai-residuals.sh` 返回稳定的 JSON，所以可以作为审查依据。

```bash
# 基于差异
AI_RESIDUALS_JSON="$(bash scripts/review-ai-residuals.sh --base-ref "${BASE_REF:-HEAD~1}")"

# 想明确指定目标文件时
bash scripts/review-ai-residuals.sh path/to/file.ts path/to/config.sh
```

### Step 2: 5 个观点审查

| 观点 | 检查内容 |
|-----|---------|
| **Security** | SQL 注入、XSS、敏感信息泄露、输入验证 |
| **Performance** | N+1 查询、不必要的重新渲染、内存泄漏 |
| **Quality** | 命名、单一职责、测试覆盖率、错误处理 |
| **Accessibility** | ARIA 属性、键盘导航、颜色对比度 |
| **AI Residuals** | `mockData`, `dummy`, `fake`, `localhost`, `TODO`, `FIXME`, `it.skip`, `describe.skip`, `test.skip`, 硬编码的机密信息/环境依赖 URL、明显的临时实现注释 |

### Step 2.2: AI Residuals 严重度判定表

对于 `AI Residuals`，首先确认 `scripts/review-ai-residuals.sh` 的 JSON，然后在 diff 上下文中最终判断"是否真的有发布风险"。

| 严重度 | 代表例 | 判定思路 |
|-------|-------|---------|
| **major** | `localhost` / `127.0.0.1` / `0.0.0.0` 连接目标、`it.skip` / `describe.skip` / `test.skip`、疑似硬编码机密信息、dev/staging 固定 URL | 容易导致生产事故、误配置、验证遗漏。1 件即 `REQUEST_CHANGES` |
| **minor** | `mockData`, `dummy`, `fakeData`, `TODO`, `FIXME` | 残留可能性高，但不一定立即出事故。建议修复但不改变 verdict |
| **recommendation** | `temporary implementation`, `replace later`, `placeholder implementation` 等临时实现注释 | 仅注释无法立即断定为 bug，但希望跟踪和明确化 |

### Step 2.5: 基于阈值的 verdict 判定

将各指摘分类为以下严重度，**仅按此标准**决定 verdict。

| 严重度 | 定义 | 对 verdict 的影响 |
|-------|------|-----------------|
| **critical** | 安全漏洞、数据丢失风险、生产环境故障可能性 | 1 件即 → REQUEST_CHANGES |
| **major** | 现有功能破坏、与规格明显矛盾、测试不通过 | 1 件即 → REQUEST_CHANGES |
| **minor** | 命名改进、注释不足、风格不统一 | 不影响 verdict |
| **recommendation** | 最佳实践建议、未来改进方案 | 不影响 verdict |

> **重要**: 仅 minor / recommendation 时**必须返回 APPROVE**。
> "有更好"不是 REQUEST_CHANGES 的理由。
> `AI Residuals` 也一样。只有"容易导致发布事故和误配置的"才归入 `major`，单纯的残留候选保留在 `minor` 或 `recommendation`。

### Step 3: 输出审查结果

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
      "suggestion": "修复建议"
    }
  ],
  "recommendations": ["非必需的改进建议"]
}
```

### Step 4: 提交判定

- **APPROVE**: 执行自动提交（除非 `--no-commit`）
- **REQUEST_CHANGES**: 提示 critical/major 指摘点和修复方向。在 `harness-work` 的修复循环中自动修复后再次审查（最多 3 次）

## Plan Review 流程

1. 读取 Plans.md
2. 从以下 **5 个观点**审查：
   - **Clarity**: 任务说明是否清晰
   - **Feasibility**: 技术上是否可行
   - **Dependencies**: 任务间依赖关系是否正确（Depends 列与实际依赖是否一致）
   - **Acceptance**: 完成条件（DoD 列）是否已定义且可验证
   - **Value**: 这个任务是否解决用户问题？
     - 是否明确了"谁的、什么问题"
     - 是否考虑了替代方案（不做的选择）
     - 是否有 Elephant（所有人都知道但被忽视的问题）
3. DoD / Depends 列质量检查：
   - DoD 为空的任务 → 警告（"完成条件未定义"）
   - DoD 不可验证（"感觉不错"、"正常运行"等） → 警告 + 具体化建议
   - Depends 中有不存在的任务编号 → 错误
   - 循环依赖 → 错误
4. 提出改进建议

## Scope Review 流程

1. 列出添加的任务/功能
2. 从以下观点分析：
   - **Scope-creep**: 偏离最初范围
   - **Priority**: 优先级是否合适
   - **Feasibility**: 当前资源是否可实现
   - **Impact**: 对现有功能的影响
3. 提示风险和推荐操作

## 异常检测

| 情况 | 操作 |
|-----|------|
| 安全漏洞 | 立即 REQUEST_CHANGES |
| 疑似测试篡改 | 警告 + 修复要求 |
| 尝试 force push | 拒绝 + 提供替代方案 |

## Codex 环境

Codex CLI 环境（`CODEX_CLI=1`）中部分工具不可用，使用以下回退方案。

| 通常环境 | Codex 回退 |
|---------|-----------|
| `TaskList` 获取任务列表 | `Read` Plans.md 确认 WIP/TODO 任务 |
| `TaskUpdate` 更新状态 | `Edit` 直接更新 Plans.md 标记（例: `cc:WIP` → `cc:完了`） |
| 将审查结果写入 Task | 将审查结果输出到 stdout |

### 检测方法

```bash
if [ "${CODEX_CLI:-}" = "1" ]; then
  # Codex 环境: 基于 Plans.md 的回退
fi
```

### Codex 环境中的审查输出

由于不支持 Task 工具，审查结果以 markdown 格式输出到标准输出。
由 Lead 代理或用户读取结果，判断下一步操作。

## 相关技能

- `harness-work` — 审查后实施修复
- `harness-plan` — 创建和修改计划
- `harness-release` — 审查通过后发布
