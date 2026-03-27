---
name: ui-skills-summary
description: "UI Skills 约束集摘要（实现质量优先）"
---

# UI Skills Summary

防止 UI 实现中容易出问题的约束集。

## Stack
- MUST: Tailwind CSS 使用默认值（仅在现有自定义或明确要求时例外）
- MUST: 如果需要 JavaScript 动画则使用 `motion/react`
- SHOULD: Tailwind 入场/轻微动画使用 `tw-animate-css`
- MUST: class 控制使用 `cn`（`clsx` + `tailwind-merge`）

## Components
- MUST: 键盘/焦点行为使用可访问的原语
- MUST: 优先使用现有原语
- NEVER: 不在同一操作面混用原语
- SHOULD: 如有兼容则优先 Base UI
- MUST: 仅图标按钮添加 `aria-label`
- NEVER: 不手动实现键盘/焦点行为（除非明确要求）

## Interaction
- MUST: 破坏性操作使用 AlertDialog
- SHOULD: 加载使用结构化骨架
- NEVER: 不使用 `h-screen` 而用 `h-dvh`
- MUST: fixed 元素考虑 `safe-area-inset`
- MUST: 错误显示在操作位置附近
- NEVER: 不阻止 input/textarea 的粘贴

## Animation
- NEVER: 除非明确要求否则不添加动画
- MUST: 仅动画 `transform` / `opacity`
- NEVER: 不动画 `width/height/top/left/margin/padding`
- SHOULD: `background/color` 动画仅用于小型局部 UI
- SHOULD: 入场使用 `ease-out`
- NEVER: 反馈不超过 200ms
- MUST: 循环在离屏时停止
- SHOULD: 尊重 `prefers-reduced-motion`
- NEVER: 除非明确要求否则禁止自定义 easing
- SHOULD: 大图片/全屏避免动画

## Typography
- MUST: 标题使用 `text-balance`
- MUST: 正文使用 `text-pretty`
- MUST: 数字使用 `tabular-nums`
- SHOULD: 紧凑 UI 使用 `truncate` or `line-clamp`
- NEVER: 不随意更改 `tracking-*`

## Layout
- MUST: 使用固定 `z-index` 规模（避免任意 `z-*`）
- SHOULD: 正方形使用 `size-*`

## Performance
- NEVER: 不动画大 `blur()` / `backdrop-filter`
- NEVER: 不常时添加 `will-change`
- NEVER: 不用 `useEffect` 处理可以在 render 中写的逻辑

## Design
- NEVER: 除非明确要求否则禁止渐变
- NEVER: 禁止紫色/多色渐变
- NEVER: 主要线索不使用 glow
- SHOULD: 阴影使用 Tailwind 默认规模
- MUST: 空状态提供「下一步」1 个
- SHOULD: 强调色控制在 1 个
- SHOULD: 优先使用现有主题/token 而非新颜色

## Sources
- https://www.ui-skills.com/
- https://agent-skills.xyz/skills/baptistearno-typebot-io-ui-skills
