---
name: core-read-repo-context
description: "读取并理解仓库的上下文（README、Plans.md、现有代码）。会话开始时、新任务开始前、或需要理解项目结构时使用。"
allowed-tools: ["Read", "Grep", "Glob"]
---

# Read Repository Context

把握仓库结构和上下文的技能。
在开始作业前或实现新功能前使用。

---

## 输入

- **必需**：访问仓库的根目录
- **可选**：指定特定文件或目录的焦点

---

## 输出

包含仓库理解的结构化上下文信息

---

## 执行步骤

### Step 1：把握基本结构

```bash
# 目录结构
ls -la
find . -maxdepth 2 -type d | head -20

# 确认主要文件
cat README.md 2>/dev/null | head -50
cat package.json 2>/dev/null | head -20
```

### Step 2：确认工作流文件

```bash
# Plans.md 的状态
cat Plans.md 2>/dev/null || echo "Plans.md not found"

# AGENTS.md 的角色分工
cat AGENTS.md 2>/dev/null | head -100 || echo "AGENTS.md not found"

# CLAUDE.md 的设置
cat CLAUDE.md 2>/dev/null | head -50 || echo "CLAUDE.md not found"
```

### Step 3：特定技术栈

```bash
# 前端
[ -f package.json ] && cat package.json | grep -E '"(react|vue|angular|next|nuxt)"'

# 后端
[ -f requirements.txt ] && head -10 requirements.txt
[ -f Gemfile ] && head -10 Gemfile
[ -f go.mod ] && head -10 go.mod

# 配置文件
[ -f tsconfig.json ] && echo "TypeScript project"
[ -f .eslintrc* ] && echo "ESLint configured"
[ -f tailwind.config.* ] && echo "Tailwind CSS"
```

### Step 4：确认 Git 状态

```bash
git status -sb
git log --oneline -5
git branch -a | head -10
```

---

## 输出格式

```markdown
## 📁 仓库上下文

### 基本信息
- **项目名**：{{name}}
- **技术栈**：{{framework}} + {{language}}
- **当前分支**：{{branch}}

### 工作流状态
- **Plans.md**：{{存在/不存在，任务数}}
- **AGENTS.md**：{{存在/不存在}}
- **CLAUDE.md**：{{存在/不存在}}

### 最近更改
{{最近 3 条提交}}

### 重要文件
{{应认识的主要文件列表}}
```

---

## 使用时机

1. **会话开始时**：把握当前状态
2. **实现新功能前**：确认与现有代码的整合性
3. **调查错误时**：特定相关文件
4. **审查时**：理解更改的影响范围

---

## 注意事项

- **大型仓库**：文件数多时聚焦重要部分
- **机密信息**：不读取 .env 或 secrets/ 的内容
- **利用缓存**：同一会话内最小化重新读取
