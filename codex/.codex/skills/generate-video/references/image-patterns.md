# Image Patterns Reference

图像生成的 4 种模式（comparison, concept, flow, highlight）的使用指南。

---

## 概要

定义针对视频场景优化的图像模式。各模式针对特定目的优化，与 AI 图像生成提示词模板协作。

### 模式列表

| 模式 | 用途 | 最适合场景 | 提示词模板 |
|---------|------|-----------|---------------------|
| **comparison** | Before/After、好例子/坏例子对比 | 提出问题、展示改善效果 | `templates/image-prompts/comparison.txt` |
| **concept** | 抽象概念、层级结构、关系可视化 | 架构讲解、概念说明 | `templates/image-prompts/concept.txt` |
| **flow** | 步骤、流程、工作流图示 | 演示步骤、处理流程 | `templates/image-prompts/flow.txt` |
| **highlight** | 重要要点、信息强调 | Hook、CTA、结论 | `templates/image-prompts/highlight.txt` |

---

## 1. Comparison 模式 {#comparison}

### 目的

Before/After、好例子/坏例子等，视觉对比两种状态或选择。

### 使用场景

| 场景 | 例 |
|--------|-----|
| **提出问题** | 现有工具的复杂 vs 本产品的简洁 |
| **改善效果** | 导入前（手动、慢）vs 导入后（自动、快） |
| **功能比较** | 传统方法 vs 新功能 |
| **发布说明** | 旧版本 vs 新版本 |

### 视觉构成

```
┌──────────────────────────────────────────┐
│                                          │
│  [坏例子/Before]  🠖  [好例子/After]      │
│                                          │
│  ❌ 问题点1         ✅ 改善点1           │
│  ❌ 问题点2         ✅ 改善点2           │
│  ❌ 问题点3         ✅ 改善点3           │
│                                          │
└──────────────────────────────────────────┘
```

### JSON 例

```json
{
  "type": "comparison",
  "topic": "任务管理改善",
  "style": "modern",
  "colorScheme": {
    "primary": "#3B82F6",
    "secondary": "#10B981",
    "background": "#1F2937"
  },
  "comparison": {
    "leftSide": {
      "label": "Before",
      "items": [
        "手动电子表格管理",
        "频繁漏更新",
        "状态确认需30分钟"
      ],
      "icon": "x",
      "sentiment": "negative"
    },
    "rightSide": {
      "label": "After",
      "items": [
        "自动仪表盘更新",
        "实时同步",
        "状态一目了然"
      ],
      "icon": "check",
      "sentiment": "positive"
    },
    "divider": "arrow"
  }
}
```

### 提示词生成要点

- **左侧（Before/坏例子）**: 红色系、警告图标、散乱印象
- **右侧（After/好例子）**: 绿色系、勾选图标、整洁印象
- **分隔**: 明确的箭头或"VS"视觉分离
- **文本**: 简短具体（每项20字以内推荐）

### 应避免的模式

| ❌ 避免 | ✅ 推荐 |
|----------|---------|
| 长句罗列 | 简短关键词 |
| 抽象说明 | 具体数值・结果 |
| 中间评价 | 明确对比 |
| 两侧相同图标 | 不同情感图标 |

---

## 2. Concept 模式 {#concept}

### 目的

可视化抽象概念、层级结构、要素间关系。

### 使用场景

| 场景 | 例 |
|--------|-----|
| **架构讲解** | 系统构成图、层级结构 |
| **概念说明** | 理念、设计思想、价值提供的图示 |
| **关系性** | 组件间的依赖关系 |
| **流程全景** | 生态系统、工作流整体 |

### 视觉构成（层级例）

```
        ┌───────────┐
        │  最顶层   │
        └─────┬─────┘
              │
     ┌────────┴────────┐
     │                 │
┌────▼────┐       ┌────▼────┐
│ 层级1 │       │ 层级1 │
└─────────┘       └────┬────┘
                       │
                  ┌────▼────┐
                  │ 层级2 │
                  └─────────┘
```

### JSON 例

```json
{
  "type": "concept",
  "topic": "微服务架构",
  "style": "technical",
  "colorScheme": {
    "primary": "#6366F1",
    "secondary": "#8B5CF6",
    "background": "#0F172A"
  },
  "concept": {
    "elements": [
      {
        "id": "api-gateway",
        "label": "API Gateway",
        "description": "所有请求的入口",
        "level": 0,
        "icon": "cloud",
        "emphasis": "high"
      },
      {
        "id": "auth-service",
        "label": "认证服务",
        "level": 1,
        "parentId": "api-gateway",
        "icon": "server",
        "emphasis": "medium"
      },
      {
        "id": "data-service",
        "label": "数据服务",
        "level": 1,
        "parentId": "api-gateway",
        "icon": "database",
        "emphasis": "medium"
      }
    ],
    "relationships": [
      {
        "from": "api-gateway",
        "to": "auth-service",
        "label": "认证确认",
        "type": "flow"
      },
      {
        "from": "api-gateway",
        "to": "data-service",
        "label": "数据获取",
        "type": "flow"
      }
    ],
    "layout": "hierarchy"
  }
}
```

### 布局类型

| 布局 | 用途 | 视觉印象 |
|-----------|------|------------|
| **hierarchy** | 层级结构（组织图、依赖关系） | 从上到下的树 |
| **radial** | 中心放射（生态系统） | 中央主要要素，周围关联要素 |
| **grid** | 并列配置（类别分类） | 矩阵配置 |
| **flow** | 处理流程（管道） | 从左到右的流向 |
| **circular** | 循环过程（生命周期） | 环形 |

### 提示词生成要点

- **要素数**: 2-10个（太多难看）
- **层级**: 最多3-4级
- **图标**: 直观表现要素性质
- **关系性**: 用箭头粗细和颜色表现重要度

### 应避免的模式

| ❌ 避免 | ✅ 推荐 |
|----------|---------|
| 10个以上要素 | 控制在7个以内 |
| 复杂关系线 | 仅主要关系 |
| 长说明文 | 简短标签 + 图标 |
| 相同样式的要素 | 用强调度区分 |

---

## 3. Flow 模式 {#flow}

### 目的

可视化步骤、流程、工作流的时间序列或步骤顺序。

### 使用场景

| 场景 | 例 |
|--------|-----|
| **演示步骤** | 从设置到执行的步骤 |
| **用户流程** | 登录 → 操作 → 完成的流程 |
| **处理流程** | 数据管道、CI/CD 流程 |
| **入门指南** | 首次使用的引导线 |

### 视觉构成（水平例）

```
[1. 开始] ──▶ [2. 输入] ──▶ [3. 处理] ──▶ [4. 完成]
   ⏱2分         ⏱1分         ⏱3秒         即时
```

### JSON 例

```json
{
  "type": "flow",
  "topic": "视频生成流程",
  "style": "modern",
  "colorScheme": {
    "primary": "#F59E0B",
    "secondary": "#EF4444",
    "background": "#111827"
  },
  "flow": {
    "steps": [
      {
        "id": "analyze",
        "label": "代码库分析",
        "description": "自动检测项目结构",
        "order": 1,
        "type": "start",
        "icon": "circle",
        "duration": "10秒"
      },
      {
        "id": "plan",
        "label": "场景生成",
        "description": "提案最佳视频构成",
        "order": 2,
        "type": "process",
        "icon": "square",
        "duration": "20秒"
      },
      {
        "id": "generate",
        "label": "并行生成",
        "description": "同时创建各场景",
        "order": 3,
        "type": "parallel",
        "icon": "rounded",
        "duration": "2分"
      },
      {
        "id": "render",
        "label": "渲染",
        "description": "输出最终视频",
        "order": 4,
        "type": "end",
        "icon": "hexagon",
        "duration": "30秒"
      }
    ],
    "direction": "horizontal",
    "arrowStyle": "solid",
    "showNumbers": true
  }
}
```

### 步骤类型

| 类型 | 用途 | 视觉表现 |
|--------|------|---------|
| **start** | 流程起点 | 圆形图标、绿色 |
| **process** | 普通处理步骤 | 方形、蓝色 |
| **decision** | 条件分支 | 菱形、黄色 |
| **parallel** | 并行处理 | 多个图标、紫色 |
| **subprocess** | 子流程 | 圆角方形 |
| **end** | 流程终点 | 双圆、红色 |

### 提示词生成要点

- **方向**: 横向（horizontal）易读（面向英语圈）
- **步骤数**: 2-10步骤（太多复杂）
- **所需时间**: 各步骤显示时间更实用
- **编号**: 明确顺序（showNumbers: true）

### 应避免的模式

| ❌ 避免 | ✅ 推荐 |
|----------|---------|
| 10步骤以上 | 整合到7步骤以内 |
| 复杂分支 | 简化为线性流程 |
| 长步骤名 | 动词 + 名词简洁表达 |
| 不明确的顺序 | 用 order 字段明确 |

---

## 4. Highlight 模式 {#highlight}

### 目的

强调显示单个信息、关键词、数值。

### 使用场景

| 场景 | 例 |
|--------|-----|
| **Hook（开头）** | "还在手动消耗精力吗？" |
| **CTA（行动号召）** | "立即尝试" |
| **结论** | "3倍快，10倍简单" |
| **重要指标** | "95%的时间节省" |

### 视觉构成

```
┌────────────────────────────────────────┐
│                                        │
│                                        │
│          ⚡ 3倍快，10倍简单 ⚡         │
│                                        │
│         自动化改变开发体验          │
│                                        │
└────────────────────────────────────────┘
```

### JSON 例

```json
{
  "type": "highlight",
  "topic": "产品价值强调",
  "style": "gradient",
  "colorScheme": {
    "primary": "#EC4899",
    "accent": "#8B5CF6",
    "background": "#18181B"
  },
  "highlight": {
    "mainText": "95%的时间节省",
    "subText": "从手动作业解放的开发团队",
    "icon": "rocket",
    "position": "center",
    "effect": "glow",
    "fontSize": "xlarge",
    "emphasis": "high"
  }
}
```

### 效果类型

| 效果 | 用途 | 视觉表现 |
|-----------|------|---------|
| **glow** | 神圣强调（CTA、结论） | 发光效果 |
| **shadow** | 沉稳强调（Hook） | 阴影 |
| **gradient** | 现代印象 | 渐变背景 |
| **outline** | 锐利印象 | 仅轮廓 |
| **none** | 极简 | 无装饰 |

### 图标和情感

| 图标 | 情感・含义 | 使用场景 |
|---------|-----------|---------|
| **star** | 优秀、品质 | 功能介绍、评价 |
| **check** | 完成、成功 | 导入效果、结果 |
| **alert** | 注意提醒 | 提出问题、警告 |
| **trophy** | 达成、胜利 | 成果、实绩 |
| **rocket** | 快速、革新 | 性能、新功能 |
| **fire** | 热门、话题 | 趋势、关注 |
| **bolt** | 即时、力量 | 速度、效率 |

### 提示词生成要点

- **短是关键**: 主文本理想10字以内
- **数值**: 具体数值说服力高（"95%", "3倍"）
- **对比**: "快、简单" 这样并列两个价值
- **情感**: 图标 + 效果增强情感

### 应避免的模式

| ❌ 避免 | ✅ 推荐 |
|----------|---------|
| 长文（20字以上） | 简短标语 |
| 多个主张 | 只保留一个 |
| 朴素设计 | 用效果突显 |
| 小字体 | 推荐 xlarge |

---

## 模式选择指南

### 场景类型别推荐模式

| 场景类型 | 第1推荐 | 第2推荐 | 用途 |
|------------|---------|---------|------|
| **Hook** | highlight | comparison | 强烈的第一印象 |
| **Problem** | comparison | concept | 明确现状问题 |
| **Solution** | concept | flow | 解决方案的机制 |
| **Demo** | flow | comparison | 步骤可视化 |
| **Differentiator** | comparison | concept | 差异化要点 |
| **CTA** | highlight | - | 行动号召 |

### 漏斗别使用频率

| 模式 | 认知・兴趣 | 考虑 | 确信 | 继续 |
|---------|-----------|------|------|------|
| **comparison** | ★★★ | ★★★ | ★★☆ | ★☆☆ |
| **concept** | ★☆☆ | ★★★ | ★★★ | ★★☆ |
| **flow** | ★★☆ | ★★★ | ★★☆ | ★★★ |
| **highlight** | ★★★ | ★★☆ | ★★★ | ★☆☆ |

### 多模式组合

**90秒预告片（LP/广告用）例**:

| 秒数 | 场景 | 模式 | 内容 |
|------|--------|---------|------|
| 0-5秒 | Hook | **highlight** | "还在手动消耗精力吗？" |
| 5-15秒 | Problem | **comparison** | Before（手动）vs After（自动） |
| 15-55秒 | Solution | **flow** | 设置 → 执行 → 完成的3步骤 |
| 55-70秒 | Proof | **concept** | 架构的稳健性 |
| 70-90秒 | CTA | **highlight** | "立即免费开始" |

---

## 实现注意事项

### 1. JSON Schema 验证

- **必须**: `type`, `topic` 字段必填
- **oneOf**: 必须有对应模式的专用字段（例: type="comparison" 时 comparison 字段必填）
- **验证**: 用 `scripts/validate-visual-pattern.js` 检验

### 2. 与提示词模板协作

- **模板**: 使用 `templates/image-prompts/{type}.txt`
- **占位符**: 用 JSON 值替换 `{{topic}}`, `{{items}}`, `{{style}}` 等
- **生成**: `references/image-generator.md` 负责实际生成

### 3. 图像质量检查

- **自动判定**: `references/image-quality-check.md` 评估质量
- **重试**: 不合格时最多重新生成3次
- **确定性**: 保存 seed 值确保可复现

### 4. 资产管理

- **输出目标**: `out/video-{id}/assets/generated/`
- **清单**: 记录到 `assets.manifest.schema.json`
- **哈希**: SHA-256 检测篡改

---

## 相关文档

- [visual-patterns.schema.json](../schemas/visual-patterns.schema.json) - JSON Schema 定义
- [image-generator.md](./image-generator.md) - AI图像生成实现
- [image-quality-check.md](./image-quality-check.md) - 质量判定逻辑
- [templates/image-prompts/](../templates/image-prompts/) - 提示词模板
- [best-practices.md](./best-practices.md) - 视频整体最佳实践

---

**创建日期**: 2026-02-02
**适用 Phase**: Phase 6 - 图像生成模式
**维护**: Schema 变更时更新
