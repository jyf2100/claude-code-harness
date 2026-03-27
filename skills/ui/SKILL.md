---
name: ui
description: "生成 UI 组件和反馈表单。触发短语：组件、UI、hero 区域、表单、反馈、联系请求。不用于：认证功能、后端实现、数据库操作或业务逻辑。"
description-en: "Generates UI components and feedback forms. Use when user mentions components, UI, hero sections, forms, feedback, or contact requests. Do NOT load for: authentication features, backend implementation, database operations, or business logic."
description-zh: "生成 UI 组件和反馈表单。触发短语：组件、UI、hero 区域、表单、反馈、联系请求。不用于：认证功能、后端实现、数据库操作或业务逻辑。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
user-invocable: false
---

# UI 技能

负责 UI 组件和表单生成的技能群。

## 约束的优先顺序和适用条件

1. 基本上最优先应用 `${CLAUDE_SKILL_DIR}/references/ui-skills.md` 的约束。
2. `${CLAUDE_SKILL_DIR}/references/frontend-design.md` 只在**显式**指定"尖锐/独特/表现强烈/品牌强化"等时应用。
3. UI Skills 的 MUST/NEVER 原则上维持。但**仅在用户显式要求时**允许以下例外：
   - 渐变、发光、强装饰
   - 动画（追加/扩展）
   - 自定义 easing

## 功能详情

| 功能 | 详情 |
|-----|------|
| **约束集** | 见 [references/ui-skills.md](${CLAUDE_SKILL_DIR}/references/ui-skills.md) / [references/frontend-design.md](${CLAUDE_SKILL_DIR}/references/frontend-design.md) |
| **组件生成** | 见 [references/component-generation.md](${CLAUDE_SKILL_DIR}/references/component-generation.md) |
| **反馈表单** | 见 [references/feedback-forms.md](${CLAUDE_SKILL_DIR}/references/feedback-forms.md) |

## 执行步骤

1. **应用约束集**（按优先顺序）
2. **质量判定门禁**（Step 0）
3. 分类用户请求
4. 从上述"功能详情"读取适当的参考文件
5. 按其内容生成

### Step 0: 质量判定门禁（a11y 检查清单）

生成 UI 组件时，确保无障碍访问：

```markdown
♿ 无障碍检查清单

生成的 UI 建议满足以下要求：

### 必须项
- [ ] 为图片设置 alt 属性
- [ ] 为表单元素关联 label
- [ ] 可用键盘操作（Tab 键移动焦点）
- [ ] 焦点状态视觉可见

### 推荐项
- [ ] 不只依赖颜色传递信息
- [ ] 对比度 4.5:1 以上（文本）
- [ ] 恰当使用 aria-label / aria-describedby
- [ ] 标题结构（h1 → h2 → h3）逻辑清晰

### 交互元素
- [ ] 按钮有恰当标签（不是"详情"而是"查看产品详情"）
- [ ] 模态/对话框的焦点陷阱
- [ ] 错误消息可被屏幕阅读器读取
```

### 面向 VibeCoder

```markdown
♿ 让任何人都能使用的设计

1. **为图片添加说明**
   - 不是"商品图片"而是"红色运动鞋，正面"

2. **可点击的地方也要能用键盘操作**
   - Tab 键移动，Enter 键确定

3. **不只靠颜色判断**
   - 不只是红色=错误，还要有图标+文字
```
