---
name: deploy
description: "部署到 Vercel/Netlify。前往生产环境的单程票已备好。Use when user mentions deployment, Vercel, Netlify, analytics, or health checks. Do NOT load for: implementation work, local development, reviews, or setup."
description-en: "Deploy to Vercel/Netlify. One-way ticket to production arranged. Use when user mentions deployment, Vercel, Netlify, analytics, or health checks. Do NOT load for: implementation work, local development, reviews, or setup."
description-ja: "部署到 Vercel/Netlify。前往生产环境的单程票已备好。触发短语: 部署、Vercel、Netlify、分析统计、健康检查。不用于: 实现工作、本地开发、审查、设置。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
disable-model-invocation: true
argument-hint: "[vercel|netlify|health]"
context: fork
---

# Deploy Skills

负责部署和监控设置的技能组。

## 功能详情

| 功能 | 详情 |
|------|------|
| **部署设置** | See [references/deployment-setup.md](${CLAUDE_SKILL_DIR}/references/deployment-setup.md) |
| **分析统计** | See [references/analytics.md](${CLAUDE_SKILL_DIR}/references/analytics.md) |
| **环境诊断** | See [references/health-checking.md](${CLAUDE_SKILL_DIR}/references/health-checking.md) |

## 执行步骤

1. 分类用户的请求
2. 从上述"功能详情"中读取相应的参考文件
3. 按照其内容进行设置
