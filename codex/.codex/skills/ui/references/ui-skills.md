---
name: ui-skills-summary
description: "UI Skills 约束集摘要（实现质量优先）"
---

# UI Skills Summary

防止 UI 实现中容易出问题的地方的约束集。

## Stack
- MUST：Tailwind CSS 使用默认值（仅在已有自定义或明确要求时例外）
- MUST：需要 JavaScript 动画时使用 `motion/react`
- SHOULD：Tailwind 入场/轻微动画用 `tw-animate-css`
- MUST：class 控制用 `cn`（`clsx` + `tailwind-merge`）

## Components
- MUST：键盘/焦点行为使用可访问的原语
- MUST：优先使用现有原语
- NEVER：不在同一操作面混用原语
- SHOULD：有兼容性时优先 Base UI
- MUST：仅图标按钮要有 `aria-label`
- NEVER：不手动实现键盘/焦点行为（除非明确要求）

## Interaction
- MUST：破坏性操作用 AlertDialog
- SHOULD：加载状态用结构性骨架
- NEVER：不用 `h-screen`，用 `h-dvh`
- MUST：fixed 元素考虑 `safe-area-inset`
- MUST：错误在操作位置附近显示
- NEVER：不阻止 input/textarea 的粘贴

## Animation
- NEVER：除非明确要求否则不添加动画
- MUST：只动画 `transform` / `opacity`
- NEVER：不动画 `width/height/top/left/margin/padding`
- SHOULD：`background/color` 动画仅用于小的局部 UI
- SHOULD：入场用 `ease-out`
- NEVER：反馈不超过 200ms
- MUST：循环在屏幕外停止
- SHOULD：尊重 `prefers-reduced-motion`
- NEVER：除非明确要求禁止自定义 easing
- SHOULD：大图/全屏避免动画

## Typography
- MUST：标题用 `text-balance`
- MUST：正文用 `text-pretty`
- MUST：数字用 `tabular-nums`
- SHOULD：密集 UI 用 `truncate` or `line-clamp`
- NEVER：不随意更改 `tracking-*`

## Layout
- MUST：使用固定 `z-index` 级别（避免任意 `z-*`）
- SHOULD：正方形用 `size-*`

## Performance
- NEVER：不动画大 `blur()` / `backdrop-filter`
- NEVER：不常时附加 `will-change`
- NEVER：能用 render 写的不用 `useEffect`

## Design
- NEVER：除非明确要求禁止渐变
- NEVER：禁止紫色/多彩渐变
- NEVER：不用 glow 作为主要线索
- SHOULD：阴影用 Tailwind 默认级别
- MUST：空状态提示「下一步」的 1 个操作
- SHOULD：强调色控制在 1 个
- SHOULD：优先使用现有主题/令牌而非新颜色

## Sources
- https://www.ui-skills.com/
- https://agent-skills.xyz/skills/baptistearno-typebot-io-ui-skills
