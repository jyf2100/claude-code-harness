---
name: harness-setup
description: "Harness v3 统一设置技能。负责项目初始化、工具配置、2 代理配置、内存设置、公开 skill mirror 同步。触发短语：设置、初始化、新项目、CI 设置、codex CLI 设置、harness-mem、代理设置、symlink、mirror、harness-setup。不用于：实现、代码审查、发布或计划。"
description-en: "Unified setup skill for Harness v3. Project init, tool setup, 2-agent config, memory setup, and public skill mirror sync. Use when user mentions: setup, initialization, new project, CI setup, codex CLI setup, harness-mem, agent setup, symlinks, mirrors, harness-setup. Do NOT load for: implementation, code review, release, or planning."
description-zh: "Harness v3 统一设置技能。负责项目初始化、工具配置、2 代理配置、内存设置、公开 skill mirror 同步。触发短语：设置、初始化、新项目、CI 设置、codex CLI 设置、harness-mem、代理设置、symlink、mirror、harness-setup。不用于：实现、代码审查、发布或计划。"
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash"]
argument-hint: "[init|ci|codex|harness-mem|mirrors|agents|localize]"
---

# Harness Setup (v3)

Harness v3 的统一设置技能。
整合了以下旧技能：

- `setup` — 统一设置中心
- `harness-init` — 项目初始化
- `harness-update` — Harness 更新
- `maintenance` — 文件整理、清理

## 快速参考

| 子命令 | 操作 |
|-------|------|
| `harness-setup init` | 新项目初始化（CLAUDE.md + Plans.md + hooks）|
| `harness-setup ci` | CI/CD 流水线设置 |
| `harness-setup codex` | Codex CLI 安装和设置 |
| `harness-setup harness-mem` | harness-mem 集成、内存设置 |
| `harness-setup mirrors` | skills-v3/ → 公开 mirror bundle 更新 |
| `harness-setup agents` | agents-v3/ 代理设置 |
| `harness-setup localize` | CLAUDE.md 规则本地化 |

## 子命令详情

### init — 项目初始化

向新项目引入 Harness v3。

**生成的文件**:
```
project/
├── CLAUDE.md            # 项目配置
├── Plans.md             # 任务管理（空模板）
├── .claude/
│   ├── settings.json    # Claude Code 设置
│   └── hooks.json       # 钩子设置（v3 shim）
└── hooks/
    ├── pre-tool.sh      # 薄 shim（→ core/src/index.ts）
    └── post-tool.sh     # 薄 shim（→ core/src/index.ts）
```

**流程**:
1. 检测项目类型（Node.js/Python/Go/Rust/其他）
2. 生成最小化的 CLAUDE.md
3. 生成 Plans.md 模板
4. 放置 hooks.json

### ci — CI/CD 设置

设置 GitHub Actions 工作流。

```yaml
# .github/workflows/ci.yml 生成示例
name: CI
on:
  push:
    branches: [main]
  pull_request:
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci && npm test
```

### codex — Codex CLI 设置

```bash
# 确认安装
which codex || npm install -g @openai/codex

# 确认 timeout 命令（macOS）
TIMEOUT=$(command -v timeout || command -v gtimeout || echo "")
# macOS 时: brew install coreutils
```

**使用模式**:
```bash
${TIMEOUT:+$TIMEOUT 120} codex exec "$(cat /tmp/prompt.md)" 2>/dev/null
```

### harness-mem — 内存设置

设置 Unified Harness Memory。

```bash
# 创建内存目录
mkdir -p .claude/agent-memory/claude-code-harness-worker
mkdir -p .claude/agent-memory/claude-code-harness-reviewer

# 放置 MEMORY.md 模板
cat > .claude/agent-memory/claude-code-harness-worker/MEMORY.md << 'EOF'
# Worker Agent Memory

## Project Context
[项目概要]

## Patterns
[学习模式]
EOF
```

### mirrors — 公开 skill bundle 同步

Windows 的 `core.symlinks=false` 会让仓库符号链接变成普通文件，可能导致 `harness-*` skill 不出现在命令列表中。公开 bundle 作为实目录 mirror 同步。

```bash
./scripts/sync-v3-skill-mirrors.sh
./scripts/sync-v3-skill-mirrors.sh --check
```

更新目标：

- `skills/`
- `codex/.codex/skills/`
- `opencode/skills/`

### agents — 代理设置

设置 agents-v3/ 的 3 代理配置。

```
agents-v3/
├── worker.md      # 实现负责人（task-worker + codex-implementer + error-recovery）
├── reviewer.md    # 审查负责人（code-reviewer + plan-critic）
└── scaffolder.md  # 脚手架负责人（project-analyzer + scaffolder）
```

### localize — 规则本地化

将 `.claude/rules/` 的规则适配到当前项目。

```bash
# 确认规则列表
ls .claude/rules/

# 添加项目固有规则
cat >> .claude/rules/project-rules.md << 'EOF'
# Project-Specific Rules
[项目固有规则]
EOF
```

## Plugin 安装 (v2.1.71+ Marketplace)

v2.1.71 中 Marketplace 稳定性大幅改善。

### 推荐安装方式

```bash
# @ref 形式固定版本（推荐）
claude plugin install owner/repo@v3.5.0

# 最新版
claude plugin install owner/repo
```

推荐 `owner/repo@vX.X.X` 格式。`@ref` 解析器修复后，标签、分支、提交哈希都能准确解析。

### 更新

```bash
claude plugin update owner/repo
```

v2.1.71 修复了更新时的合并冲突，可稳定更新。

### 其他改进

- MCP 服务器去重: 自动防止同一 MCP 服务器重复注册
- `/plugin uninstall` 使用 `settings.local.json`: 准确反映到用户本地设置

## Maintenance — 文件整理

定期维护任务：

| 任务 | 命令 |
|-----|------|
| 删除旧日志 | `find .claude/logs -mtime +30 -delete` |
| 压缩 Plans.md | 将完成任务移动到归档部分 |
| 删除旧跟踪 | `tail -1000 .claude/state/agent-trace.jsonl > /tmp/trace && mv /tmp/trace .claude/state/agent-trace.jsonl` |

## 相关技能

- `harness-plan` — 设置后创建项目计划
- `harness-work` — 设置后执行任务
- `harness-review` — 审查设置配置
