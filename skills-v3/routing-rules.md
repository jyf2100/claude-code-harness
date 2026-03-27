# Skill Routing Rules — v3 (Reference)

Harness v3 的5动词技能间路由规则参考。

> **SSOT 位置**: 各技能的 `description` 字段是路由的 SSOT。
> 本文件是提供详细说明和示例的参考文档，实际路由依赖于各技能的 description。

## 5动词技能路由表

| 技能 | 触发关键词 | 排除 |
|--------|-----------------|------|
| `harness-plan` | 创建计划、添加任务、Plans.md更新、标记完成、进度确认、harness-plan、harness-sync | implementation, code review, release |
| `harness-work` | implement, execute, harness-work, 全部做完、breezing、团队执行、--codex, --parallel | planning, code review, release, setup |
| `harness-review` | review, 代码审查、计划审查、范围确认、安全检查、质量检查、PR 审查、harness-review | implementation, 新功能、错误修复、setup, release |
| `harness-release` | release, 版本升级、创建标签、publish、/harness-release | implementation, code review, planning, setup |
| `harness-setup` | setup, 初始化、新项目、CI 设置、Codex CLI 设置、harness-mem、代理设置、symlink、/harness-setup | implementation, code review, release, planning |

## 详细路由

### harness-plan 技能

**触发条件**（匹配任一）:
- "创建计划" / "create a plan"
- "添加任务" / "add a task"
- "更新 Plans.md"
- "标记完成" / "mark complete" / "mark as done"
- "今在哪里" / "where am I" / "check progress"
- "进度确认"
- "harness-plan" / "harness-sync"
- "sync status" / "sync Plans.md"

**排除条件**（匹配任一则排除）:
- "实现" / "implement"
- "代码审查"
- "发布"

### harness-work 技能

**触发条件**（匹配任一）:
- "实现" / "implement"
- "执行" / "execute"
- "harness-work"
- "全部做完" / "do everything"
- "只做这个" / "just this"
- "breezing" / "团队执行"
- "--codex" / "--parallel"
- "构建" / "build"

**排除条件**（匹配任一则排除）:
- "计划" / "plan"（无实现）
- "审查"（无实现）
- "发布"
- "设置"

### harness-review 技能

**触发条件**（匹配任一）:
- "审查" / "review"
- "代码审查" / "code review"
- "计划审查" / "plan review"
- "范围确认"
- "安全检查"
- "质量检查"
- "PR 审查"
- "harness-review"
- "看 diff" / "确认变更"

**排除条件**（匹配任一则排除）:
- "实现"（实现请求）
- "添加新功能"
- "修复错误"
- "设置"
- "发布"

### harness-release 技能

**触发条件**（匹配任一）:
- "发布" / "release"
- "版本升级" / "version bump"
- "创建标签" / "create tag"
- "公开" / "publish"
- "更新 CHANGELOG"
- "harness-release"

**排除条件**（匹配任一则排除）:
- "实现"
- "代码审查"
- "计划"
- "设置"

### harness-setup 技能

**触发条件**（匹配任一）:
- "设置" / "setup"
- "初始化" / "initialization" / "init"
- "新项目" / "new project"
- "CI 设置"
- "Codex CLI 设置"
- "harness-mem"
- "代理设置"
- "symlink 更新"
- "harness-setup"

**排除条件**（匹配任一则排除）:
- "实现"
- "代码审查"
- "发布"
- "创建计划"

## 优先级规则

1. **排除最优先**: 匹配排除关键词的技能绝对不加载
2. **具体关键词优先**: 完全匹配 > 部分匹配
3. **模糊情况**: `plan` > `execute` > `review` 顺序优先（选择更保守的）

## 扩展包（extensions/）

核心技能以外的功能存放在 `skills-v3/extensions/`:

| 技能 | 用途 |
|--------|------|
| `auth` | 认证・支付功能（Clerk, Stripe） |
| `crud` | CRUD 自动生成 |
| `ui` | UI组件生成 |
| `agent-browser` | 浏览器自动化 |
| `gogcli-ops` | Google Workspace 操作 |
| `codex-review` | Codex 第二意见 |
| `notebookLM` | NotebookLM 连携 |
| `generate-slide` | 幻灯片生成 |
| `deploy` | 部署自动化 |
| `memory` | SSOT・内存管理 |
| `cc-cursor-cc` | Cursor ↔ Claude Code 连携 |

## 更新规则

1. **description = SSOT**: 各技能的 `description` 字段是路由的正式定义
2. **本文件的职责**: 详细说明和判定流程的参考文档（非 SSOT）
3. **维护完整列表**: 不使用泛化表达，列举具体关键词
