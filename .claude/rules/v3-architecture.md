# v3 架构详细

## 目录结构

```
claude-code-harness/
├── core/           # TypeScript 核心引擎
│   ├── src/
│   │   ├── index.ts          # stdin → route → stdout 管道
│   │   ├── types.ts          # 类型定义（HookInput, HookResult 等）
│   │   └── guardrails/       # 护栏引擎
│   │       ├── rules.ts      # 声明式规则表 (R01-R09)
│   │       ├── pre-tool.ts   # PreToolUse 钩子
│   │       ├── post-tool.ts  # PostToolUse 钩子
│   │       ├── permission.ts # PermissionRequest 钩子
│   │       └── tampering.ts  # 篡改检测
│   ├── package.json          # standalone TypeScript package
│   └── tsconfig.json         # strict, NodeNext ESM
├── skills-v3/      # 5动词技能
│   ├── plan/       # planning + plans-management + sync-status 集成
│   ├── execute/    # work + breezing + codex 集成
│   ├── review/     # harness-review + codex-review 集成
│   ├── release/    # release-har + handoff 集成
│   ├── setup/      # harness-init + harness-mem 集成
│   └── extensions/ # 扩展包（symlink → skills/）
├── agents-v3/      # 3代理（11→3 集成）
│   ├── worker.md        # 实现担当
│   ├── reviewer.md      # 审查担当（Read-only）
│   ├── scaffolder.md    # 脚手架・状态更新担当
│   └── team-composition.md  # 团队构成指南
├── skills/         # 旧技能（向后兼容保留）
├── hooks/          # 薄层封装（→ core/src/index.ts 委托）
└── .claude/
    └── agent-memory/
        ├── claude-code-harness-worker/
        ├── claude-code-harness-reviewer/
        └── claude-code-harness-scaffolder/
```

## 5动词技能映射

| v3 技能 | 集成来源（旧技能） |
|----------|----------------|
| `plan` | planning, plans-management, sync-status |
| `execute` | work, impl, breezing, parallel-workflows, ci |
| `review` | harness-review, codex-review, verify, troubleshoot |
| `release` | release-har, x-release-harness, handoff |
| `setup` | setup, harness-init, harness-update, maintenance |

## 3代理映射
| v3 代理 | 集成来源（旧代理） |
|--------------|------------------|
| `worker` | task-worker, codex-implementer, error-recovery |
| `reviewer` | code-reviewer, plan-critic, plan-analyst |
| `scaffolder` | project-analyzer, project-scaffolder, project-state-updater |

## TypeScript 配置
- `exactOptionalPropertyTypes: true` — optional 字段使用条件赋值
- `noUncheckedIndexedAccess: true` — 数组访问需要 undefined 检查
- `NodeNext` 模块解析 — ESM
- `better-sqlite3` 是 `optionalDependencies`（Node 24 compat）

## Symlink 构成（v3）
`codex/.codex/skills/` 和 `opencode/skills/` 的5动词技能是 `skills-v3/` 的 symlink:

```bash
codex/.codex/skills/plan -> ../../../../skills-v3/plan
opencode/skills/execute   -> ../../../skills-v3/execute
# ...等等
```

`check-consistency.sh` 验证 symlink 的健全性。
