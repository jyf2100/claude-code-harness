# Video Analyzer - 代码库分析引擎

自动分析项目，提取视频生成所需信息。

---

## 概述

在 `/generate-video` 的 Step 1 中执行的分析引擎。
解析代码库和项目资产，判定最佳视频构成。

## 分析项目

### 1. 框架检测

| 检测对象 | 判定方法 |
|---------|---------|
| Next.js | 存在 `next.config.*` |
| React | `package.json` 的 dependencies |
| Vue | `vue.config.*` 或 `nuxt.config.*` |
| Svelte | `svelte.config.*` |
| Express/Fastify | `package.json` 的 dependencies |

**执行命令**:
```bash
# 从 package.json 提取依赖关系
cat package.json | jq '.dependencies, .devDependencies'

# 确认配置文件存在
ls -la *.config.* 2>/dev/null
```

### 2. 主要功能检测

| 功能 | 检测模式 |
|------|-------------|
| 认证 | `auth/`, `login/`, `@clerk`, `@auth0`, `supabase` |
| 支付 | `payment/`, `billing/`, `stripe`, `@stripe` |
| 仪表盘 | `dashboard/`, `admin/`, `analytics` |
| API | `api/`, `routes/`, `trpc`, `graphql` |
| 数据库 | `prisma/`, `drizzle/`, `@supabase` |

**执行命令**:
```bash
# 从目录结构推测功能
find src app -type d -name "auth" -o -name "login" -o -name "dashboard" 2>/dev/null

# 从包推测功能
grep -E "clerk|stripe|supabase|prisma" package.json
```

### 3. UI 组件检测

| 项目 | 检测方法 |
|------|---------|
| 页面数 | `app/**/page.tsx` 或 `pages/**/*.tsx` 的计数 |
| 组件数 | `components/**/*.tsx` 的计数 |
| UI 库 | `shadcn`, `radix`, `chakra`, `mui` 的检测 |

**执行命令**:
```bash
# 页面数计数
find . -name "page.tsx" -o -name "page.jsx" 2>/dev/null | wc -l

# 组件数计数
find . -path "*/components/*" -name "*.tsx" 2>/dev/null | wc -l
```

### 4. 项目资产解析

| 资产 | 用途 |
|------|------|
| `package.json` | 项目名称、description |
| `README.md` | 项目概要、标语 |
| `Plans.md` | 已完成任务（用于发布说明） |
| `CHANGELOG.md` | 变更点（用于发布说明） |
| `.claude/memory/decisions.md` | 技术决策（用于架构讲解） |

**执行命令**:
```bash
# 提取项目信息
cat package.json | jq '{name, description, version}'

# 提取 README 的第一段
head -20 README.md
```

---

## 视频类型自动判定

### 判定逻辑

```
从分析结果判定视频类型:
    │
    ├─ CHANGELOG 最近更新（7 天内）
    │   └─ → 发布说明视频
    │
    ├─ 大规模结构变更（新增目录等）
    │   └─ → 架构讲解
    │
    ├─ UI 变更多（组件添加/变更）
    │   └─ → 产品演示
    │
    └─ 符合多个条件
        └─ → 复合视频（向用户确认）
```

### 判定标准

| 类型 | 条件 |
|--------|------|
| **发布说明** | `git log --since="7 days ago"` 中有 tag/release |
| **架构** | 新的 `src/*/` 目录、大规模重构 |
| **产品演示** | UI 组件的添加/变更 |
| **默认** | 产品演示（最通用） |

---

## 输出格式

分析结果以以下格式输出:

```yaml
project:
  name: "MyAwesomeApp"
  description: "让任务管理变得简单"
  version: "1.2.0"

framework:
  primary: "Next.js"
  ui_library: "shadcn/ui"

features:
  - name: "认证"
    type: "auth"
    path: "src/app/(auth)/"
    provider: "Clerk"
  - name: "仪表盘"
    type: "dashboard"
    path: "src/app/dashboard/"
  - name: "API"
    type: "api"
    path: "src/app/api/"

stats:
  pages: 12
  components: 45
  api_routes: 8

recent_changes:
  changelog_updated: true
  last_release: "2026-01-20"
  major_changes:
    - "添加认证流程"
    - "改进仪表盘"

recommended_video_type: "release-notes"
confidence: 0.85
```

---

## 执行示例

```
📊 正在分析项目...

✅ 分析完成

| 项目 | 结果 |
|------|------|
| 项目名称 | MyAwesomeApp |
| 框架 | Next.js 14 |
| UI 库 | shadcn/ui |
| 页面数 | 12 |
| 组件数 | 45 |

🔍 检测到的功能:
- 认证（Clerk）
- 仪表盘
- API（8 个端点）

📋 最近变更:
- v1.2.0 发布（3 天前）
- 添加认证流程
- 改进仪表盘

🎬 推荐视频类型: 发布说明视频
   原因: 有最近发布，且添加了主要功能
```

---

## Notes

- 分析是非破坏性的（不修改文件）
- 大型项目也能在数秒内完成
- 无法检测的功能可在 planner.md 中手动添加
