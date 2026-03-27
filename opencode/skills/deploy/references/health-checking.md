---
name: health-check
description: "环境诊断（依赖/设置/可用功能确认）。想要确认环境是否正确设置时使用。"
allowed-tools: ["Read", "Bash"]
---

# Health Check Skill

在使用插件前，诊断环境是否正确设置的技能。

---

## 触发短语

- "检查这个环境能否运行"
- "缺少什么？"
- "诊断环境"
- "告诉我有哪些可用功能"

---

## 检查项目

### 必需工具
- Git
- Node.js / npm（如适用）
- GitHub CLI（可选）

### 配置文件
- `claude-code-harness.config.json` 的存在和有效性
- `.claude/settings.json` 的存在

### 工作流文件
- `Plans.md` 的存在
- `AGENTS.md` 的存在
- `CLAUDE.md` 的存在

---

## 输出格式

```
## 环境诊断报告

### 必需工具
✅ git (2.40.0)
✅ node (v20.10.0)
⚠️ gh (未安装 - CI 自动修正需要)

### 配置文件
✅ claude-code-harness.config.json
✅ .claude/settings.json

### 可用功能
✅ /work, /plan-with-agent, /sync-status
⚠️ CI自动修正 (需要 gh)
```
