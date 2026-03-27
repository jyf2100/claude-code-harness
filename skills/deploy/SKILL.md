---
name: deploy
description: "部署到 Vercel/Netlify。前往生产环境的单程票。Use when user mentions deployment, Vercel, Netlify, analytics, or health checks. Do NOT load for: implementation work, local development, reviews, or setup."
description-en: "Deploy to Vercel/Netlify. One-way ticket to production arranged. Use when user mentions deployment, Vercel, Netlify, analytics, or health checks. Do NOT load for: implementation work, local development, reviews, or setup."
description-zh: "部署到 Vercel/Netlify。前往生产环境的单程票。触发短语：部署、Vercel、Netlify、分析、健康检查。不用于：实现工作、本地开发、审查、设置。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
disable-model-invocation: true
argument-hint: "[vercel|netlify|health]"
context: fork
---

# Deploy 技能

负责部署和监控设置的技能群。

## 功能详情

| 功能 | 详情 |
|------|------|
| **部署设置** | 见 [references/deployment-setup.md](${CLAUDE_SKILL_DIR}/references/deployment-setup.md) |
| **分析** | 见 [references/analytics.md](${CLAUDE_SKILL_DIR}/references/analytics.md) |
| **环境诊断** | 见 [references/health-checking.md](${CLAUDE_SKILL_DIR}/references/health-checking.md) |

## 执行步骤

1. 分类用户请求
2. 从上述"功能详情"读取适当的参考文件
3. 按其内容设置
