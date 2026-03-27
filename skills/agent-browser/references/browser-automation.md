# Browser Automation with agent-browser

使用 agent-browser CLI 进行浏览器自动化的详细指南。

---

## 安装

```bash
# 全局安装
npm install -g agent-browser

# 下载 Chromium
agent-browser install

# Linux 时，还需要系统依赖
agent-browser install --with-deps
```

---

## 基本操作

### 打开页面

```bash
# 基本
agent-browser open https://example.com

# 显示浏览器打开（调试用）
agent-browser open https://example.com --headed

# 带自定义头
agent-browser open https://api.example.com --headers '{"Authorization": "Bearer token"}'
```

### 点击

```bash
# 用元素引用点击（推荐）
agent-browser click @e1

# 用 CSS 选择器点击
agent-browser click "button.submit"

# 双击
agent-browser dblclick @e1
```

### 输入

```bash
# 清空并输入表单
agent-browser fill @e1 "hello@example.com"

# 追加输入（不清空）
agent-browser type @e1 "追加文本"

# 按键
agent-browser press Enter
agent-browser press Tab
agent-browser press "Control+a"
```

### 表单操作

```bash
# 复选框
agent-browser check @e1
agent-browser uncheck @e1

# 下拉框
agent-browser select @e1 "option-value"

# 文件上传
agent-browser upload @e1 /path/to/file.pdf
```

### 滚动

```bash
# 指定方向
agent-browser scroll down
agent-browser scroll up 500

# 滚动到元素可见
agent-browser scrollintoview @e1
```

---

## 获取信息

```bash
# 获取文本
agent-browser get text @e1

# 获取 HTML
agent-browser get html @e1

# 获取属性
agent-browser get attr href @e1

# 获取值（input）
agent-browser get value @e1

# 当前 URL
agent-browser get url

# 页面标题
agent-browser get title

# 元素数量
agent-browser get count "li.item"

# 元素位置和大小
agent-browser get box @e1
```

---

## 状态检查

```bash
# 是否可见
agent-browser is visible @e1

# 是否可用（是否 disabled）
agent-browser is enabled @e1

# 是否选中
agent-browser is checked @e1
```

---

## 等待

```bash
# 等待元素出现
agent-browser wait @e1
agent-browser wait "button.loaded"

# 按时间等待（毫秒）
agent-browser wait 2000
```

---

## 截图

```bash
# 基本
agent-browser screenshot

# 指定文件名
agent-browser screenshot output.png

# 全页面
agent-browser screenshot --full page.png

# 保存为 PDF
agent-browser pdf document.pdf
```

---

## JavaScript 执行

```bash
# 执行脚本
agent-browser eval "document.title"
agent-browser eval "localStorage.getItem('token')"
agent-browser eval "window.scrollTo(0, document.body.scrollHeight)"
```

---

## 网络操作

```bash
# 模拟请求
agent-browser network route "*/api/users" --body '{"users": []}'

# 阻止请求
agent-browser network route "*/analytics/*" --abort

# 解除路由
agent-browser network unroute "*/api/users"

# 请求历史
agent-browser network requests
agent-browser network requests --filter "api"
agent-browser network requests --clear
```

---

## Cookie/Storage

```bash
# 获取 Cookie
agent-browser cookies get

# 设置 Cookie
agent-browser cookies set '{"name": "session", "value": "abc123", "domain": "example.com"}'

# 清除 Cookie
agent-browser cookies clear

# LocalStorage
agent-browser storage local get "key"
agent-browser storage local set "key" "value"
agent-browser storage local clear

# SessionStorage
agent-browser storage session get "key"
```

---

## 标签页管理

```bash
# 打开新标签页
agent-browser tab new

# 标签页列表
agent-browser tab list

# 切换标签页
agent-browser tab 2

# 关闭标签页
agent-browser tab close
```

---

## 浏览器设置

```bash
# 视口大小
agent-browser set viewport 1920 1080

# 设备模拟
agent-browser set device "iPhone 12"

# 地理位置
agent-browser set geo 35.6762 139.6503

# 离线模式
agent-browser set offline on
agent-browser set offline off

# 暗黑模式
agent-browser set media dark
agent-browser set media light

# 认证信息
agent-browser set credentials admin password123
```

---

## 调试

```bash
# 显示控制台日志
agent-browser console
agent-browser console --clear

# 显示页面错误
agent-browser errors
agent-browser errors --clear

# 高亮元素
agent-browser highlight @e1

# 追踪记录
agent-browser trace start
# ... 操作 ...
agent-browser trace stop trace.zip
```

---

## Find 命令（高级元素搜索）

```bash
# 按角色搜索并点击
agent-browser find role button click --name "Submit"

# 按文本搜索
agent-browser find text "Click here" click

# 按标签搜索
agent-browser find label "Email" fill "test@example.com"

# 按占位符搜索
agent-browser find placeholder "Enter your name" fill "John"

# 按 test ID 搜索
agent-browser find testid "submit-btn" click

# 第一个/最后一个/第 n 个
agent-browser find first "button" click
agent-browser find last "input" fill "text"
agent-browser find nth 2 "li" click
```

---

## 鼠标操作（低级）

```bash
# 鼠标移动
agent-browser mouse move 100 200

# 鼠标按钮
agent-browser mouse down
agent-browser mouse up
agent-browser mouse down right

# 滚轮
agent-browser mouse wheel 100
agent-browser mouse wheel 100 50  # dy, dx
```

---

## 拖拽

```bash
# 元素间拖拽
agent-browser drag @e1 @e2

# 坐标指定
agent-browser drag @e1 "500,300"
```

---

## 会话管理

```bash
# 命名会话
agent-browser --session myapp open https://example.com

# 会话列表
agent-browser session list

# 当前会话名
agent-browser session

# 也可用环境变量指定
AGENT_BROWSER_SESSION=myapp agent-browser snapshot
```

---

## JSON 输出

```bash
# JSON 格式输出
agent-browser snapshot --json
agent-browser get text @e1 --json
agent-browser network requests --json
```

---

## 自定义浏览器

```bash
# 自定义可执行文件
agent-browser --executable-path /path/to/chrome open https://example.com

# 也可用环境变量指定
AGENT_BROWSER_EXECUTABLE_PATH=/path/to/chrome agent-browser open https://example.com
```
