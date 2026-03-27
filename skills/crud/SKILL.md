---
name: crud
description: "快速自动生成 CRUD。样板代码交给 AI。Use when user mentions CRUD, entity generation, or wants to create API endpoints. Do NOT load for: UI component creation, form design, database schema discussions."
description-en: "Auto-generate CRUD quickly. Boilerplate left to AI. Use when user mentions CRUD, entity generation, or wants to create API endpoints. Do NOT load for: UI component creation, form design, database schema discussions."
description-zh: "快速自动生成 CRUD。样板代码交给 AI。触发短语：CRUD、实体生成、创建 API 端点。不用于：UI 组件创建、表单设计、数据库模式讨论。"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
argument-hint: "<entity-name>"
user-invocable: false
---

# CRUD 技能

为指定实体（表）自动生成 **生产级** CRUD 功能。

## 快速参考

- "**Create CRUD for task management**" → `/crud tasks`
- "**Want search and pagination too**" → 全部包含
- "**Include permissions (who can view/edit)**" → 一起设置授权/规则

## 交付物

- CRUD + 验证 + 授权 + 测试，**完整的生产安全套件**
- 最小化差异以匹配现有数据库/代码

**功能**：
- 验证（Zod）自动添加
- 认证/授权（行级安全）自动配置
- 关系（一对多、多对多）支持
- 分页、搜索、过滤
- 自动生成测试用例

---

## 自动调用技能

**此技能必须用 Skill tool 显式调用以下技能**：

| 技能 | 用途 | 调用时机 |
|------|------|----------|
| `impl` | 实现（父技能） | CRUD 功能实现 |
| `verify` | 验证（父技能） | 实现后验证 |

---

## 执行流程

详细步骤在以下阶段中描述。

### Phase 1: 实体分析

1. 从 $ARGUMENTS 解析实体名称
2. 检测现有模式（Prisma、Drizzle、原始 SQL）
3. 推断字段类型和关系

### Phase 2: CRUD 生成

1. 如需要生成模型/模式
2. 创建 API 端点（REST 或 tRPC）
3. 添加验证模式（Zod）
4. 配置授权规则

### Phase 3: 测试生成

1. 为每个端点创建单元测试
2. 添加集成测试
3. 生成测试固件

### Phase 4: 验证

1. 运行类型检查
2. 运行测试
3. 验证构建

---

## 支持的框架

| 框架 | 检测方式 | 生成的文件 |
|------|----------|------------|
| **Next.js + Prisma** | `prisma/schema.prisma` | API 路由、Prisma 客户端 |
| **Next.js + Drizzle** | `drizzle.config.ts` | API 路由、Drizzle 查询 |
| **Express** | `package.json` 中的 `express` | 控制器、路由 |
| **Hono** | `package.json` 中的 `hono` | 路由处理器 |

---

## 输出结构

```
src/
├── lib/
│   └── validations/
│       └── {entity}.ts        # Zod 模式
├── app/api/{entity}/
│   ├── route.ts              # GET（列表）、POST（创建）
│   └── [id]/
│       └── route.ts          # GET、PUT、DELETE
└── tests/
    └── {entity}.test.ts      # 测试用例
```

---

## 相关技能

- `impl` - 功能实现
- `verify` - 构建验证
- `auth` - 认证/授权
