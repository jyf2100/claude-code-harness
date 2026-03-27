---
name: ci
description: "CI变红了就叫我。管道消防队，出动。Use when user mentions CI failures, build errors, test failures, or pipeline issues. Do NOT load for: local builds, standard implementation work, reviews, or setup."
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

- "CI挂了" "GitHub Actions失败"
- "构建错误" "测试不通过"
- "修复管道"

---

## 功能详情

| 功能 | 详情 | 触发器 |
|------|------|----------|
| **失败分析** | See [references/analyzing-failures.md](${CLAUDE_SKILL_DIR}/references/analyzing-failures.md) | "看日志" "调查原因" |
| **测试修复** | See [references/fixing-tests.md](${CLAUDE_SKILL_DIR}/references/fixing-tests.md) | "修测试" "给出修复方案" |

---

## 执行步骤

1. **测试 vs 实现判定**（Step 0）
2. 分类用户意图（分析 or 修复）
3. 判定复杂度（见下文）
4. 从上述"功能详情"读取适当的参考文件，或启动 ci-cd-fixer 子代理
5. 确认结果，必要时重新运行

### Step 0: 测试 vs 实现判定（质量判定门禁）

CI 失败时，首先进行原因分离:

```
CI 失败报告
    ↓
┌─────────────────────────────────────────┐
│           测试 vs 实现判定             │
├─────────────────────────────────────────┤
│  分析错误原因:                    │
│  ├── 实现有误 → 修正实现          │
│  ├── 测试过时 → 向用户确认      │
│  └── 环境问题 → 修正环境                │
└─────────────────────────────────────────┘
```

#### 禁止事项（篡改防止）

```markdown
⚠️ CI 失败时的禁止事项

以下"解决方案"是禁止的：

| 禁止 | 例 | 正确应对 |
|------|-----|-----------|
| 测试 skip 化 | `it.skip(...)` | 修正实现 |
| 删除断言 | 删除 `expect()` | 确认期望值 |
| CI 检查绕过 | `continue-on-error` | 修复根本原因 |
| lint 规则放宽 | `eslint-disable` | 修正代码 |
```

#### 判断流程

```markdown
🔴 CI 失败

**需要判断**:

1. **实现有误** → 修正实现 ✅
2. **测试期望值过时** → 请求用户确认
3. **环境问题** → 修正环境配置

⚠️ 测试篡改（skip 化、删除断言）是禁止的

属于哪种情况？
```

#### 需要批准的情况

测试/配置的更改不可避免时:

```markdown
## 🚨 测试/配置更改批准请求

### 理由
[为什么需要此更改]

### 更改内容
[差异]

### 代替方案探讨
- [ ] 已确认无法通过修正实现来解决

等待用户明确批准
```

### Git log 扩展标志的使用（CC 2.1.49+）

CI 失败时使用结构化日志定位原因提交。

#### 定位原因提交

```bash
# 结构化格式分析提交
git log --format="%h|%s|%an|%ad" --date=short -10

# 拓扑顺序时序分析
git log --topo-order --oneline -20

# 变更文件与原因的关联
git log --raw --oneline -5
```

#### 主要使用场景

| 用途 | 标志 | 效果 |
|------|--------|------|
| **定位失败原因** | `--format="%h\|%s"` | 提交列表结构化 |
| **时序追踪** | `--topo-order` | 考虑合并顺序的追踪 |
| **把握变更影响** | `--raw` | 文件变更详细显示 |
| **合并排除分析** | `--cherry-pick --no-merges` | 仅提取实际提交 |

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

## 子代理联动

满足以下条件时，使用 Task tool 启动 ci-cd-fixer:

- 修复 → 重新运行 → 失败的循环发生 **2次以上**
- 或错误跨越多个文件的复杂情况

**启动模式:**

```
Task tool:
  subagent_type="ci-cd-fixer"
  prompt="诊断并修复 CI 失败。错误日志: {error_log}"
```

ci-cd-fixer 以安全优先运行（默认 dry-run 模式）。
详情参见 `agents/ci-cd-fixer.md`。

---

## VibeCoder 专用

```markdown
🔧 CI 坏了时的说法

1. **"CI 挂了" "变红了"**
   - 自动测试失败的状态

2. **"为什么失败？"**
   - 希望调查原因

3. **"修一下"**
   - 尝试自动修复

💡 重要: "糊弄"测试的修复是禁止的
   - ❌ 删除测试、跳过测试
   - ⭕ 正确修复代码

如果觉得"测试好像错了"，
先确认后再决定如何处理
```
