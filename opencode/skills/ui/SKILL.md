---
name: ui
description: "生成 UI 组件和反馈表单。Use when user mentions components, UI, hero sections, forms, feedback, or contact requests. Do NOT load for: authentication features, backend implementation, database operations, or business logic."
description-en: "Generates UI components and feedback forms. Use when user mentions components, UI, hero sections, forms, feedback, or contact requests. Do NOT load for: authentication features, backend implementation, database operations, or business logic."
description-ja: "生成 UI 组件和反馈表单。Use when user mentions components, UI, hero sections, forms, feedback, or contact requests. Do NOT load for: authentication features, backend implementation, database operations, or business logic."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
user-invocable: false
---

# UI Skills

负责生成 UI 组件和表单的技能群。

## 约束的优先级和适用条件

1. 基本上优先应用 `${CLAUDE_SKILL_DIR}/references/ui-skills.md` 的约束。
2. `${CLAUDE_SKILL_DIR}/references/frontend-design.md` 仅在**明确**要求「尖锐/独特/表现强烈/品牌强化」等时应用。
3. UI Skills 的 MUST/NEVER 原则上保持。但**仅在用户明确要求时**允许以下例外：
   - 渐变、发光、强装饰
   - 动画（添加/扩展）
   - 自定义 easing

## 功能详情

| 功能 | 详情 |
|------|------|
| **约束集** | See [references/ui-skills.md](${CLAUDE_SKILL_DIR}/references/ui-skills.md) / [references/frontend-design.md](${CLAUDE_SKILL_DIR}/references/frontend-design.md) |
| **组件生成** | See [references/component-generation.md](${CLAUDE_SKILL_DIR}/references/component-generation.md) |
| **反馈表单** | See [references/feedback-forms.md](${CLAUDE_SKILL_DIR}/references/feedback-forms.md) |

## 执行步骤

1. **应用约束集**（按优先级）
2. **质量判定门**（Step 0）
3. 分类用户请求
4. 从上述「功能详情」读取适当的参考文件
5. 按其内容生成

### Step 0: 质量判定门（a11y 检查清单）

生成 UI 组件时，确保可访问性：

```markdown
♿ 可访问性检查清单

生成的 UI 推荐满足以下条件：

### 必需项
- [ ] 图片设置 alt 属性
- [ ] 表单元素关联 label
- [ ] 可键盘操作（Tab 移动焦点）
- [ ] 焦点状态视觉可见

### 推荐项
- [ ] 不仅依赖颜色传递信息
- [ ] 对比度 4.5:1 以上（文本）
- [ ] 适当使用 aria-label / aria-describedby
- [ ] 标题结构（h1 → h2 → h3）逻辑合理

### 交互元素
- [ ] 按钮有适当标签（不是「详情」而是「查看产品详情」）
- [ ] 模态/对话框的焦点陷阱
- [ ] 错误消息能被屏幕阅读器读取
```

### VibeCoder 向导

```markdown
♿ 让任何人都能使用的设计

1. **图片添加说明**
   - 不是「商品图片」而是「红色运动鞋，正面」

2. **可点击的地方也支持键盘操作**
   - Tab 键移动，Enter 键确认

3. **不只靠颜色判断**
   - 红=错误 不够，还要加图标+文本
```
