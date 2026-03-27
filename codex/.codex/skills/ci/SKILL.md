---
name: ci
description: "CI 变红就叫我。管道消防队，出动。Use when user mentions CI failures, build errors, test failures, or pipeline issues. Do NOT load for: local builds, standard implementation work, reviews, or setup."
description-en: "CI red? Call us. Pipeline fire brigade deploys. Use when user mentions CI failures, build errors, test failures, or pipeline issues. Do NOT load for: local builds, standard implementation work, reviews, or setup."
description-ja: "CIが赤くなったら呼んで。パイプライン消防隊、出動します。Use when user mentions CI failures, build errors, test failures, or pipeline issues. Do NOT load for: local builds, standard implementation work, reviews, or setup."
allowed-tools: ["Read", "Grep", "Bash", "Task"]
user-invocable: false
context: fork
argument-hint: "[analyze|fix|run]"
---

# CI/CD Skills

解决 CI/CD 管道相关问题的技能群。

---

## 触发条件

- "CI 失败了"、"GitHub Actions 失败"
- "构建错误"、"测试不通过"
- "修好管道"

---

## 功能详情

| 功能 | 详情 | 触发 |
|------|------|----------|
| **失败分析** | See [references/analyzing-failures.md](${CLAUDE_SKILL_DIR}/references/analyzing-failures.md) | "看日志"、"调查原因" |
| **测试修正** | See [references/fixing-tests.md](${CLAUDE_SKILL_DIR}/references/fixing-tests.md) | "修测试"、"提修正方案" |

---

## 执行步骤

1. **测试 vs 实现判定**（Step 0）
2. 分类用户意图（分析或修正）
3. 判定复杂度（见下）
4. 从上述"功能详情"读取适当的参考文件，或启动 ci-cd-fixer 子代理
5. 确认结果，必要时重新运行

### Step 0: 测试 vs 实现判定（质量判定关卡）

CI 失败时，首先区分原因：

```
CI 失败报告
    ↓
┌─────────────────────────────────────────┐
│           测试 vs 实现判定             │
├─────────────────────────────────────────┤
│  分析错误原因:                    │
│  ├── 实现错误 → 修正实现          │
│  ├── 测试过时 → 向用户确认      │
│  └── 环境问题 → 修正环境                │
└─────────────────────────────────────────┘
```

#### 禁止事项（篡改防止）

```markdown
⚠️ CI 失败时的禁止事项

以下"解决方案"是禁止的：

| 禁止 | 例 | 正确对应 |
|------|-----|-----------|
| 跳过测试 | `it.skip(...)` | 修正实现 |
| 删除断言 | 删除 `expect()` | 确认期望值 |
| 绕过 CI 检查 | `continue-on-error` | 修复根本原因 |
| 放宽 lint 规则 | `eslint-disable` | 修正代码 |
```

#### 判断流程

```markdown
🔴 CI 失败了

**需要判断**:

1. **实现错误** → 修正实现 ✅
2. **测试期望值过时** → 请求用户确认
3. **环境问题** → 修正环境设置

⚠️ 禁止篡改测试（跳过、删除断言）

属于哪种情况？
```

#### 需要批准的情况

不得已需要更改测试/设置时：

```markdown
## 🚨 测试/设置变更批准请求

### 理由
[为什么需要此变更]

### 变更内容
[差异]

### 替代方案讨论
- [ ] 已确认无法通过修正实现解决

等待用户明确批准
```

### 利用 Git log 扩展标志（CC 2.1.49+）

CI 失败时利用结构化日志定位原因提交。

#### 定位原因提交

```bash
# 用结构化格式分析提交
git log --format="%h|%s|%an|%ad" --date=short -10

# 用拓扑顺序进行时序分析
git log --topo-order --oneline -20

# 关联变更文件和原因
git log --raw --oneline -5
```

#### 主要使用场景

| 用途 | 标志 | 效果 |
|------|--------|------|
| **定位失败原因** | `--format="%h|%s"` | 结构化提交列表 |
| **时序追踪** | `--topo-order` | 考虑合并顺序的追踪 |
| **把握变更影响** | `--raw` | 详细显示文件变更 |
| **排除合并分析** | `--cherry-pick --no-merges` | 仅提取实际提交 |

#### 输出示例

```markdown
🔍 CI 失败原因分析

最近提交（结构化）:
| Hash | Subject | Author | Date |
|------|---------|--------|------|
| a1b2c3d | feat: update API | Alice | 2026-02-04 |
| e4f5g6h | test: add tests | Bob | 2026-02-03 |

变更文件（--raw）:
├── src/api/endpoint.ts (Modified) ← 发生类型错误
├── tests/api.test.ts (Modified)
└── package.json (Modified)

→ a1b2c3d 提交可能是原因
  类型错误: src/api/endpoint.ts:42
```

## 子代理协作

满足以下条件时，用 Task tool 启动 ci-cd-fixer：

- 修正 → 重新运行 → 失败的循环发生 **2 次以上**
- 或错误跨多个文件的复杂情况

**启动模式:**

```
Task tool:
  subagent_type="ci-cd-fixer"
  prompt="请诊断并修正 CI 失败。错误日志: {error_log}"
```

ci-cd-fixer 以安全第一运行（默认 dry-run 模式）。
详情请参考 `agents/ci-cd-fixer.md`。

---

## VibeCoder 专用

```markdown
🔧 CI 坏了时的说法

1. **"CI 掉了"、"变红了"**
   - 自动测试失败的状态

2. **"为什么会失败？"**
   - 希望调查原因

3. **"修好它"**
   - 尝试自动修正

💡 重要: "糊弄"测试的修正是禁止的
   - ❌ 删除测试、跳过测试
   - ⭕ 正确修正代码

觉得"测试可能有问题"时，
先确认再决定如何处理
```
