---
name: harness-release
description: "Harness v3 统一发布技能。自动化 CHANGELOG、版本升级、标签、GitHub Release。触发短语：发布、版本升级、创建标签、publish、/harness-release。不用于：实现、代码审查、计划或设置。"
description-en: "Unified release skill for Harness v3. CHANGELOG, version bump, tag, GitHub Release automation. Use when user mentions: release, version bump, create tag, publish, /harness-release. Do NOT load for: implementation, code review, planning, or setup."
description-zh: "Harness v3 统一发布技能。自动化 CHANGELOG、版本升级、标签、GitHub Release。触发短语：发布、版本升级、创建标签、publish、/harness-release。不用于：实现、代码审查、计划或设置。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
argument-hint: "[patch|minor|major|--dry-run|--announce]"
context: fork
---

# Harness Release (v3)

Harness v3 的统一发布技能。
整合了以下旧技能：

- `release-har` — 通用发布自动化
- `x-release-harness` — Harness 专用发布自动化
- `handoff` — 向 PM 交接、完成报告

## 快速参考

```bash
/release          # 交互式（确认版本类型）
/release patch    # 补丁版本升级（bug 修复）
/release minor    # 次版本升级（新功能）
/release major    # 主版本升级（破坏性变更）
/release --dry-run  # 仅预览（不执行）
/release --announce # 同时执行 Slack 等通知
```

## Release-only 策略

- 普通 PR: 不触碰 `VERSION` / `.claude-plugin/plugin.json` / versioned `CHANGELOG.md` 条目
- 普通 PR 的变更历史: 追加到 `CHANGELOG.md` 的 `[Unreleased]`
- 只在 `/release` 执行时统一更新 version bump、versioned CHANGELOG entry、tag / GitHub Release

## 分支策略

- **单独开发**: 允许直接 push 到 main（CI 作为质量门禁）
- **协同开发**: 必须通过 PR 合并
- 始终禁止 force push（`--force` / `--force-with-lease`）

## 执行流程

### Pre-flight 检查（必须）

```bash
# 1. 确认 gh 命令
command -v gh &>/dev/null || echo "⚠️ 无 gh: 跳过 GitHub Release"

# 2. 确认未提交变更
git diff --quiet && git diff --cached --quiet || {
  echo "⚠️ 有未提交变更。请先提交。"
  exit 1
}

# 3. 确认 CI 状态
gh run list --branch main --limit 3 --json status,conclusion
```

### Step 1: 获取当前版本

```bash
CURRENT=$(cat VERSION 2>/dev/null || jq -r '.version' package.json 2>/dev/null)
```

### Step 2: 计算新版本

遵循语义版本控制（SemVer）：
- `patch`: x.y.Z → x.y.(Z+1)（bug 修复）
- `minor`: x.Y.z → x.(Y+1).0（新功能、向后兼容）
- `major`: X.y.z → (X+1).0.0（破坏性变更）

### Step 3: 更新 CHANGELOG

release entry 是将普通 PR 积累的 `[Unreleased]` 变更整理为 versioned section。

**详细 Before/After 格式**（中文）描述。
各功能以编号分段，用具体例子说明"以前"和"现在"。

```markdown
## [X.Y.Z] - YYYY-MM-DD

### 主题: [用一句话概括变更]

**[用户价值的 1~2 句话]**

---

#### 1. [功能名]

**以前**: [具体描述旧行为。让用户感觉"确实是这样"的问题描述]

**现在**: [具体描述新行为。解决了什么]

```
[实际输出示例或命令示例]
```

#### 2. [下一个功能名]

**以前**: ...

**现在**: ...
```

**写作规则**:

| 规则 | 说明 |
|-----|------|
| 语言 | **中文** |
| 各功能独立分段 | 用 `#### N. 功能名` 编号 |
| "以前"是问题描述 | 具体描述用户体验到的不便 |
| "现在"展示解决方案 | 有什么变化 + 具体例子（代码/输出） |
| 必须包含具体例子 | 命令示例、输出示例、Plans.md 片段等 |
| 技术细节最小化 | 文件名和步骤编号只作为"现在"的补充 |
| 可以长一些 | 各功能 3~10 行。可读性最优先 |

### Step 4: 更新版本文件

```bash
echo "$NEW_VERSION" > VERSION
# 如果有 package.json
jq --arg v "$NEW_VERSION" '.version = $v' package.json > tmp && mv tmp package.json
# 如果有 .claude-plugin/plugin.json
jq --arg v "$NEW_VERSION" '.version = $v' .claude-plugin/plugin.json > tmp && mv tmp .claude-plugin/plugin.json
```

### Step 5: 提交 & 打标签

```bash
git add CHANGELOG.md VERSION package.json .claude-plugin/plugin.json
git commit -m "chore: release v$NEW_VERSION"
git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION"
git push origin main --tags
```

### Step 6: 创建 GitHub Release

```bash
gh release create "v$NEW_VERSION" \
  --title "v$NEW_VERSION - $(head -n 2 CHANGELOG.md | tail -n 1)" \
  --notes "$(cat <<'EOF'
## What's Changed

**[变更概要]**

### Before / After

| Before | After |
|--------|-------|
| 旧状态 | 新状态 |

---

Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

## GitHub Release Notes 格式

必需元素：
- `## What's Changed` 部分
- **粗体**单行摘要
- Before / After 表格
- `Generated with [Claude Code](...)` 页脚
- 语言：**英语**（禁止中文）

## PM 交接

发布后向 PM 的完成报告：

```markdown
## 发布完成报告

**版本**: v{{NEW_VERSION}}
**发布日期**: {{DATE}}

### 执行内容
{{CHANGELOG 内容}}

### GitHub Release
{{URL}}

### 下一步操作
- PM 确认发布说明
- 部署到生产环境（如适用）
```

## 相关技能

- `review` — 发布前执行代码审查
- `execute` — 发布后实现下一个任务
- `plan` — 创建下一版本计划
