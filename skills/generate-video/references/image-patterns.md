# Image Patterns Reference

图片生成的4种模式（comparison, concept, flow, highlight）的使用指南。

---

## 概要

定义针对视频场景优化的图片模式。每种模式都针对特定目的进行了优化，并与 AI 图片生成提示词模板联动。

### 模式列表

| 模式 | 用途 | 最佳场景 | 提示词模板 |
|-----|------|---------|----------|
| **comparison** | Before/After、好例子/坏例子的对比 | 问题提出、改善效果展示 | `templates/image-prompts/comparison.txt` |
| **concept** | 抽象概念、层次结构、关系的可视化 | 架构解说、概念说明 | `templates/image-prompts/concept.txt` |
| **flow** | 步骤、流程、工作流的图示 | 演示步骤、处理流程 | `templates/image-prompts/flow.txt` |
| **highlight** | 重要要点、信息的强调 | Hook、CTA、结论 | `templates/image-prompts/highlight.txt` |

---

## 1. Comparison 模式 {#comparison}

### 目的

Before/After、好例子/坏例子等，在视觉上对比两种状态或选择。

### 使用场景

| 场景 | 示例 |
|-----|------|
| **问题提出** | 现有工具的复杂性 vs 本产品的简洁性 |
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

### JSON 示例

```json
{
  "type": "comparison",
  "topic": "任务管理的改善",
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
        "手动管理电子表格",
        "更新遗漏频繁发生",
        "状态把握需要30分钟"
      ],
      "icon": "x",
      "sentiment": "negative"
    },
    "rightSide": {
      "label": "After",
      "items": [
        "自动更新仪表盘",
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

- **左侧（Before/坏例子）**: 红色系、警告图标、杂乱印象
- **右侧（After/好例子）**: 绿色系、勾选图标、整洁印象
- **分隔符**: 明确的箭头或 "VS" 进行视觉分离
- **文本**: 短小具体（每个项目推荐20字符以内）

### 应避免的模式

| ❌ 避免 | ✅ 推荐 |
|--------|--------|
| 长文罗列 | 短关键词 |
| 抽象说明 | 具体数值・结果 |
| 中间评价 | 明确对比 |
| 两侧相同图标 | 不同情感的图标 |

---

## 2. Concept 模式 {#concept}

### 目的

将抽象概念、层次结构、要素间的关系可视化展示。

### 使用场景

| 场景 | 示例 |
|-----|------|
| **架构解说** | 系统构成图、层次结构 |
| **概念说明** | 理念、设计思想、价值提供的图示 |
| **关系性** | 组件间的依赖关系 |
| **流程全貌** | 生态系统、工作流整体 |

### 视觉构成（层次示例）

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

### JSON 示例

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

| 布局 | 用途 | 视觉意象 |
|-----|------|---------|
| **hierarchy** | 层次结构（组织图、依赖关系） | 从上到下的树形 |
| **radial** | 从中心放射（生态系统） | 中央主要元素，周围关联元素 |
| **grid** | 并列配置（分类） | 矩阵配置 |
| **flow** | 处理流程（管道） | 从左到右的流向 |
| **circular** | 循环流程（生命周期） | 环状 |

### 提示词生成要点

- **元素数量**: 2-10个（太多会难以看清）
- **层次**: 最多3-4级
- **图标**: 直观表达元素的性质
- **关系**: 用箭头的粗细和颜色表达重要性

### 应避免的模式

| ❌ 避免 | ✅ 推荐 |
|--------|--------|
| 10个以上元素 | 控制在7个以内 |
| 复杂的关系线 | 仅显示主要关系 |
| 长说明文字 | 短标签 + 图标 |
| 相同外观元素 | 通过强调度区分 |

---

## 3. Flow 模式 {#flow}

### 目的

将步骤、流程、工作流按时间顺序或步骤顺序可视化。

### 使用场景

| 场景 | 示例 |
|-----|------|
| **演示步骤** | 从设置到执行的步骤 |
| **用户流程** | 登录 → 操作 → 完成的流程 |
| **处理流程** | 数据管道、CI/CD 流程 |
| **入门引导** | 首次使用的流程 |

### 视觉构成（水平示例）

```
[1. 开始] ──▶ [2. 输入] ──▶ [3. 处理] ──▶ [4. 完成]
   ⏱2分         ⏱1分         ⏱3秒         即时
```

### JSON 示例

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
        "description": "提出最佳视频构成",
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

| 类型 | 用途 | 视觉表达 |
|-----|------|---------|
| **start** | 流程开始点 | 圆形图标、绿色 |
| **process** | 普通处理步骤 | 方形、蓝色 |
| **decision** | 条件分支 | 菱形、黄色 |
| **parallel** | 并行处理 | 多个图标、紫色 |
| **subprocess** | 子流程 | 圆角方形 |
| **end** | 流程结束点 | 双圆、红色 |

### 提示词生成要点

- **方向**: 横向（horizontal）更易读（适合英语地区）
- **步骤数**: 2-10步（太多会复杂）
- **所需时间**: 在各步骤显示时间更实用
- **编号**: 明确顺序（showNumbers: true）

### 应避免的模式

| ❌ 避免 | ✅ 推荐 |
|--------|--------|
| 10步以上 | 合并为7步以内 |
| 复杂分支 | 简化为线性流程 |
| 长步骤名 | 用动词 + 名词简洁表达 |
| 顺序不明确 | 用 order 字段明确指定 |

---

## 4. Highlight 模式 {#highlight}

### 目的

强调显示单一信息、关键词、数值。

### 使用场景

| 场景 | 示例 |
|-----|------|
| **Hook（开头）** | "还在手动消耗吗？" |
| **CTA（行动号召）** | "立即试用" |
| **结论** | "快3倍，简单10倍" |
| **重要指标** | "节省95%时间" |

### 视觉构成

```
┌────────────────────────────────────────┐
│                                        │
│                                        │
│          ⚡ 快3倍，简单10倍 ⚡          │
│                                        │
│         自动化带来的开发体验变革         │
│                                        │
└────────────────────────────────────────┘
```

### JSON 示例

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
    "mainText": "节省95%时间",
    "subText": "从手动工作中解放的开发团队",
    "icon": "rocket",
    "position": "center",
    "effect": "glow",
    "fontSize": "xlarge",
    "emphasis": "high"
  }
}
```

### 效果类型

| 效果 | 用途 | 视觉表达 |
|-----|------|---------|
| **glow** | 神圣强调（CTA、结论） | 发光效果 |
| **shadow** | 沉稳强调（Hook） | 投影 |
| **gradient** | 现代印象 | 渐变背景 |
| **outline** | 锐利印象 | 仅轮廓 |
| **none** | 极简 | 无装饰 |

### 图标与情感

| 图标 | 情感・含义 | 使用场景 |
|-----|----------|---------|
| **star** | 优秀、品质 | 功能介绍、评价 |
| **check** | 完成、成功 | 导入效果、结果 |
| **alert** | 提醒注意 | 问题提出、警告 |
| **trophy** | 成就、胜利 | 成果、实绩 |
| **rocket** | 快速、革新 | 性能、新功能 |
| **fire** | 人气、热门 | 趋势、关注 |
| **bolt** | 即时、力量 | 速度、效率 |

### 提示词生成要点

- **短是关键**: 主文本理想情况下10字符以内
- **数值**: 具体数值更有说服力（"95%", "3倍"）
- **对比**: 如"快、简单"并列两个价值
- **情感**: 用图标 + 效果增强情感

### 应避免的模式

| ❌ 避免 | ✅ 推荐 |
|--------|--------|
| 长文（20字符以上） | 短标语 |
| 多个主张 | 只聚焦一个 |
| 平淡设计 | 用效果使其突出 |
| 小字体 | 推荐 xlarge |

---

## 模式选择指南

### 场景类型别推荐模式

| 场景类型 | 第1推荐 | 第2推荐 | 用途 |
|---------|---------|---------|------|
| **Hook** | highlight | comparison | 强烈的第一印象 |
| **Problem** | comparison | concept | 明确当前问题 |
| **Solution** | concept | flow | 解决方案的机制 |
| **Demo** | flow | comparison | 步骤可视化 |
| **Differentiator** | comparison | concept | 差异化要点 |
| **CTA** | highlight | - | 行动号召 |

### 漏斗别使用频率

| 模式 | 认知・兴趣 | 考虑 | 确信 | 继续 |
|-----|----------|------|------|------|
| **comparison** | ★★★ | ★★★ | ★★☆ | ★☆☆ |
| **concept** | ★☆☆ | ★★★ | ★★★ | ★★☆ |
| **flow** | ★★☆ | ★★★ | ★★☆ | ★★★ |
| **highlight** | ★★★ | ★★☆ | ★★★ | ★☆☆ |

### 多模式组合

**90秒 teaser（LP/广告用）示例**:

| 秒数 | 场景 | 模式 | 内容 |
|-----|------|------|------|
| 0-5秒 | Hook | **highlight** | "还在手动消耗吗？" |
| 5-15秒 | Problem | **comparison** | Before（手动）vs After（自动） |
| 15-55秒 | Solution | **flow** | 设置 → 执行 → 完成的3步 |
| 55-70秒 | Proof | **concept** | 架构的健壮性 |
| 70-90秒 | CTA | **highlight** | "立即免费开始" |

---

## 实现时注意事项

### 1. JSON Schema 验证

- **必需**: `type`, `topic` 字段是必需的
- **oneOf**: 必须有对应模式的专用字段（例: type="comparison" 时必须有 comparison 字段）
- **验证**: 使用 `scripts/validate-visual-pattern.js` 验证

### 2. 与提示词模板的联动

- **模板**: 使用 `templates/image-prompts/{type}.txt`
- **占位符**: 用 JSON 值替换 `{{topic}}`, `{{items}}`, `{{style}}` 等
- **生成**: `references/image-generator.md` 负责实际生成

### 3. 图片质量检查

- **自动判定**: `references/image-quality-check.md` 进行质量评估
- **重试**: 不合格时最多重新生成3次
- **确定性**: 保存 seed 值确保可重现

### 4. 素材管理

- **输出位置**: `out/video-{id}/assets/generated/`
- **清单**: 记录到 `assets.manifest.schema.json`
- **哈希**: SHA-256 检测篡改

---

## 相关文档

- [visual-patterns.schema.json](../schemas/visual-patterns.schema.json) - JSON Schema 定义
- [image-generator.md](./image-generator.md) - AI 图片生成实现
- [image-quality-check.md](./image-quality-check.md) - 质量判定逻辑
- [templates/image-prompts/](../templates/image-prompts/) - 提示词模板
- [best-practices.md](./best-practices.md) - 视频整体最佳实践

---

**创建日期**: 2026-02-02
**适用 Phase**: Phase 6 - 图片生成模式
**维护**: Schema 变更时更新
