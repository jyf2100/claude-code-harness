---
name: crud
description: "快速自动生成 CRUD。样板代码交给 AI。Use when user mentions CRUD, entity generation, or wants to create API endpoints. Do NOT load for: UI component creation, form design, database schema discussions."
description-en: "Auto-generate CRUD quickly. Boilerplate left to AI. Use when user mentions CRUD, entity generation, or wants to create API endpoints. Do NOT load for: UI component creation, form design, database schema discussions."
description-ja: "CRUDをサクッと自動生成。ボイラープレートはAIにお任せ。Use when user mentions CRUD, entity generation, or wants to create API endpoints. Do NOT load for: UI component creation, form design, database schema discussions."
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
argument-hint: "<entity-name>"
user-invocable: false
---

# CRUD Skill

为指定实体（表）自动生成**生产级** CRUD 功能。

## Quick Reference

- "**Create CRUD for task management**" → `/crud tasks`
- "**Want search and pagination too**" → 全部包含
- "**Include permissions (who can view/edit)**" → 一起设置授权/规则

## 交付物

- CRUD + 验证 + 授权 + 测试，**完整的生产安全套件**
- 最小化差异以匹配现有数据库/代码

**功能**:
- 验证（Zod）自动添加
- 认证/授权（行级安全）自动配置
- 关系（一对多、多对多）支持
- 分页、搜索、过滤
- 自动生成测试用例

---

## 自动调用技能

**此技能必须使用 Skill tool 显式调用以下技能**:

| Skill | Purpose | When to Call |
|-------|---------|--------------|
| `impl` | 实现（父技能） | CRUD 功能实现 |
| `verify` | 验证（父技能） | 实现后验证 |

---

## 执行流程

详细步骤在以下阶段中描述。

### Phase 1: 实体分析

1. 从 $ARGUMENTS 解析实体名
2. 检测现有 schema（Prisma、Drizzle、原生 SQL）
3. 推断字段类型和关系

### Phase 2: CRUD 生成

1. 如需要生成 model/schema
2. 创建 API 端点（REST 或 tRPC）
3. 添加验证 schema（Zod）
4. 配置授权规则

### Phase 3: 测试生成

1. 为每个端点创建单元测试
2. 添加集成测试
3. 生成测试夹具

### Phase 4: 验证

1. 运行类型检查
2. 运行测试
3. 验证构建

---

## 支持的框架

| Framework | Detection | Generated Files |
|-----------|-----------|-----------------|
| **Next.js + Prisma** | `prisma/schema.prisma` | API 路由、Prisma 客户端 |
| **Next.js + Drizzle** | `drizzle.config.ts` | API 路由、Drizzle 查询 |
| **Express** | `express` in package.json | 控制器、路由 |
| **Hono** | `hono` in package.json | 路由处理器 |

---

## 输出结构

```
src/
├── lib/
│   └── validations/
│       └── {entity}.ts        # Zod schemas
├── app/api/{entity}/
│   ├── route.ts              # GET (list), POST (create)
│   └── [id]/
│       └── route.ts          # GET, PUT, DELETE
└── tests/
    └── {entity}.test.ts      # Test cases
```

---

## Related Skills

- `impl` - 功能实现
- `verify` - 构建验证
- `auth` - 认证/授权
