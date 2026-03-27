---
name: agent-browser
description: "像手脚一样操控浏览器。页面导航、表单输入、截图，样样精通。Use when users ask to navigate websites, fill forms, take screenshots, extract web data, test web apps, or automate browser workflows. Trigger phrases include 'go to [url]', 'click on', 'fill out the form', 'take a screenshot', 'scrape', 'automate', 'test the website', 'log into', or any browser interaction request. Do NOT load for: sharing URLs, embedding links, screenshot image files."
description-en: "Control browser like hands and feet. Navigate, fill forms, screenshot, bring it on. Use when users ask to navigate websites, fill forms, take screenshots, extract web data, test web apps, or automate browser workflows. Trigger phrases include 'go to [url]', 'click on', 'fill out the form', 'take a screenshot', 'scrape', 'automate', 'test the website', 'log into', or any browser interaction request. Do NOT load for: sharing URLs, embedding links, screenshot image files."
description-ja: "ブラウザを手足のように操る。ページ遷移、フォーム入力、スクショ、なんでもこい。Use when users ask to navigate websites, fill forms, take screenshots, extract web data, test web apps, or automate browser workflows. Trigger phrases include 'go to [url]', 'click on', 'fill out the form', 'take a screenshot', 'scrape', 'automate', 'test the website', 'log into', or any browser interaction request. Do NOT load for: sharing URLs, embedding links, screenshot image files."
allowed-tools: ["Bash", "Read"]
user-invocable: false
context: fork
argument-hint: "[url] [--headless]"
---

# Agent Browser Skill

浏览器自动化技能。使用 agent-browser CLI 执行 UI 调试、验证和自动操作。

---

## 触发短语

此技能在以下短语时自动启动：

- "打开页面"、"确认 URL"
- "点击"、"输入"、"表单"
- "截取屏幕截图"
- "确认 UI"、"测试画面"
- "open this page", "click on", "fill the form", "screenshot"

---

## 功能详情

| 功能 | 详情 |
|------|------|
| **浏览器自动化** | See [references/browser-automation.md](${CLAUDE_SKILL_DIR}/references/browser-automation.md) |
| **AI 快照工作流** | See [references/ai-snapshot-workflow.md](${CLAUDE_SKILL_DIR}/references/ai-snapshot-workflow.md) |

## 执行步骤

### Step 0: 确认 agent-browser

```bash
# 确认安装
which agent-browser

# 未安装时
npm install -g agent-browser
agent-browser install
```

### Step 1: 分类用户请求

| 请求类型 | 对应操作 |
|----------------|---------------|
| 打开 URL | `agent-browser open <url>` |
| 点击元素 | 快照 → `agent-browser click @ref` |
| 表单输入 | 快照 → `agent-browser fill @ref "text"` |
| 确认状态 | `agent-browser snapshot -i -c` |
| 屏幕截图 | `agent-browser screenshot <path>` |
| 调试 | `agent-browser --headed open <url>` |

### Step 2: AI 快照工作流（推荐）

大多数操作中，首先**获取快照**，然后通过元素引用进行操作：

```bash
# 1. 打开页面
agent-browser open https://example.com

# 2. 获取快照（面向 AI，仅交互元素）
agent-browser snapshot -i -c

# 输出示例:
# - link "Home" [ref=e1]
# - button "Login" [ref=e2]
# - input "Email" [ref=e3]
# - input "Password" [ref=e4]
# - button "Submit" [ref=e5]

# 3. 通过元素引用操作
agent-browser click @e2           # 点击 Login 按钮
agent-browser fill @e3 "user@example.com"
agent-browser fill @e4 "password123"
agent-browser click @e5           # Submit
```

### Step 3: 确认结果

```bash
# 通过快照确认当前状态
agent-browser snapshot -i -c

# 或确认 URL
agent-browser get url

# 获取屏幕截图
agent-browser screenshot result.png
```

---

## 快速参考

### 基本操作

| 命令 | 说明 |
|---------|------|
| `open <url>` | 打开 URL |
| `snapshot -i -c` | 面向 AI 的快照 |
| `click @e1` | 点击元素 |
| `fill @e1 "text"` | 输入表单 |
| `type @e1 "text"` | 输入文本 |
| `press Enter` | 按键 |
| `screenshot [path]` | 屏幕截图 |
| `close` | 关闭浏览器 |

### 导航

| 命令 | 说明 |
|---------|------|
| `back` | 后退 |
| `forward` | 前进 |
| `reload` | 刷新 |

### 获取信息

| 命令 | 说明 |
|---------|------|
| `get text @e1` | 获取文本 |
| `get html @e1` | 获取 HTML |
| `get url` | 当前 URL |
| `get title` | 页面标题 |

### 等待

| 命令 | 说明 |
|---------|------|
| `wait @e1` | 等待元素 |
| `wait 1000` | 等待 1 秒 |

### 调试

| 命令 | 说明 |
|---------|------|
| `--headed` | 显示浏览器 |
| `console` | 控制台日志 |
| `errors` | 页面错误 |
| `highlight @e1` | 高亮元素 |

---

## 会话管理

并行管理多个标签页/会话：

```bash
# 指定会话
agent-browser --session admin open https://admin.example.com
agent-browser --session user open https://example.com

# 会话列表
agent-browser session list

# 在特定会话中操作
agent-browser --session admin snapshot -i -c
```

---

## 与 MCP 浏览器工具的使用区分

| 工具 | 推荐度 | 用途 |
|--------|--------|------|
| **agent-browser** | ★★★ | 首选。面向 AI 的快照功能强大 |
| chrome-devtools MCP | ★★☆ | Chrome 已打开时 |
| playwright MCP | ★★☆ | 复杂的 E2E 测试 |

**原则**: 首先尝试 agent-browser，仅在不顺利时使用 MCP 工具。

---

## 注意事项

- agent-browser 默认为无头模式
- `--headed` 选项可显示浏览器
- 会话在显式 `close` 之前保持
- 需要认证的站点请使用会话
