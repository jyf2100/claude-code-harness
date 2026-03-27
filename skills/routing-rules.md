# Skill Routing Rules (Reference)

技能间路由规则的参考文档。

> **SSOT 位置**：各技能的 `description` 字段是路由的 SSOT。
> 此文件是提供详细说明和示例的参考，实际路由依赖于各技能的 description。
>
> **重要**：各技能的 description 和正文中的「Do NOT Load For」表格必须完全一致。

## Codex 相关路由

### harness-review（包含 Codex 审查功能）

**目的**：用 Codex CLI (`codex exec`) 提供第二意见审查（v3 中从 `codex-review` 集成）

**触发关键词**（引自 description）：
- "review", "code review", "plan review"
- "scope analysis", "security", "performance"
- "quality checks", "PRs", "diffs"
- "/harness-review"

**排除关键词**（引自 description）：
- "implementation", "new features", "bug fixes"
- "setup", "release"

### harness-work --codex（包含 Codex 实现功能）

**目的**：将 Codex 用作实现引擎（v3 中集成）

**触发关键词**：
- "implement", "execute", "/work"
- "breezing", "team run"
- "--codex", "--parallel"

**排除关键词**（引自 description）：
- "planning", "code review", "release"
- "setup", "initialization"

**对应**：用 `/harness-work --codex` 执行

## 路由判定流程（参考）

> 此部分是 Claude Code 内部运行的说明，不是额外的关键词定义。
> 实际路由仅通过各技能 description 中记载的关键词判定。

```
用户输入
    │
    ├── 匹配 description 的触发关键词 → 加载相应技能
    ├── 匹配 description 的排除关键词 → 排除相应技能
    └── 都不是 → 常规技能匹配
```

## 优先级规则（参考）

关键词匹配多个技能时的优先级：

1. **排除最优先**：匹配排除关键词的技能绝对不加载
2. **具体关键词优先**：完全匹配 > 部分匹配

> **注**：「上下文判定」会产生歧义，因此不使用。由 description 的关键词确定性判定。

## 更新规则

1. **description = SSOT**：各技能的 `description` 字段是路由的正式定义
2. **与正文一致**：各技能的「Do NOT Load For」表格必须与 description 完全一致
3. **此文件的角色**：详细说明和判定流程的参考（不是 SSOT）
4. **维护完整列表**：不使用通用表述（"~概览"），而是列举具体关键词
