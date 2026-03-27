# Video Planner - 场景规划器

从分析结果自动提出场景构成，与用户确认·调整。

---

## 概述

在 `/generate-video` 的 Step 2 中执行的场景规划器。
接收 analyzer.md 的输出，提出最佳场景构成。

> **重要**: 场景构成必须遵循 [best-practices.md](best-practices.md) 的按漏斗指南

## 输入

来自 analyzer.md 的分析结果:
- 项目信息（名称、description）
- 检测到的功能列表
- 推荐视频类型
- 最近变更

---

## 按漏斗模板选择

### Step 0: 确认目的（必须）

确认视频目的，选择适当的模板。

| 目的（漏斗） | 视频类型 | 时长参考 | 构成核心 |
|------------------|------------|----------|----------|
| 认知~兴趣 | LP/广告预告 | 30-90秒 | 痛点→结果→CTA |
| 兴趣→考虑 | Intro 演示 | 2-3分 | 1 个用例完整展示 |
| 考虑→确信 | 演示/发布说明 | 2-5分 | 先消除反对意见 |
| 确信→决策 | 演示视频 | 5-30分 | 实际运营+证据 |
| 持续·活用 | 引导入门 | 30秒-数分 | 到达 Aha 体验的最短路径 |

### 90 秒预告模板

**用途**: LP/广告、认知~兴趣漏斗

```
0:00-0:05 (150f)  → HookScene: 痛点 or 期望结果
0:05-0:15 (300f)  → ProblemPromise: 目标用户和承诺
0:15-0:55 (1200f) → WorkflowDemo: 象征性工作流
0:55-1:10 (450f)  → Differentiator: 差异化依据
1:10-1:30 (600f)  → CTA: 下一步行动
```

### 3 分钟 Intro 演示模板

**用途**: 考虑用、兴趣→考虑漏斗

```
0:00-0:10 (300f)  → Hook: 结论+痛点
0:10-0:30 (600f)  → UseCase: 用例声明
0:30-2:20 (3300f) → Demo: 实际画面完整展示
2:20-2:50 (900f)  → Objection: 消除一个常见顾虑
2:50-3:00 (300f)  → CTA: 行动号召
```

### 20 分钟演示视频模板

**用途**: 决策用、确信→决策漏斗

```
0:00-1:00   → Intro: 对象和课题
1:00-8:00   → BasicFlow: 基本流程
8:00-12:00  → Objections: 反对意见前 2 名
12:00-15:00 → Security: 管理/安全
15:00-20:00 → CaseStudy+CTA: 成功案例+CTA
```

## 场景模板

### 通用场景

| 场景 | 推荐时间 | 内容 | 必须 |
|--------|----------|------|------|
| **介绍** | 3-5秒 | Logo + 标语 + 淡入 | ✅ |
| **CTA** | 3-5秒 | URL + 联系方式 + 淡出 | ✅ |

### 产品演示用场景

| 场景 | 推荐时间 | 内容 |
|--------|----------|------|
| **功能介绍** | 5-10秒 | 功能名 + 1 行说明 |
| **UI 演示** | 10-30秒 | Playwright 截图 |
| **亮点** | 5-10秒 | 强调主要特征 |

### 架构讲解用场景

| 场景 | 推荐时间 | 内容 |
|--------|----------|------|
| **概览图** | 5-10秒 | 整体构成的 Mermaid 图 |
| **详细解说** | 10-20秒 | 放大各组件 |
| **数据流** | 10-15秒 | 时序图动画 |

### 发布说明用场景

| 场景 | 推荐时间 | 内容 |
|--------|----------|------|
| **版本显示** | 3-5秒 | vX.Y.Z + 发布日期 |
| **变更列表** | 5-15秒 | Added/Changed/Fixed 动画 |
| **Before/After** | 10-20秒 | UI 变更的并排比较 |
| **新功能演示** | 10-30秒 | 新增功能的 UI 演示 |

---

## 场景生成逻辑

### Step 1: 按视频类型选择模板

```
根据推荐视频类型选择基础模板:
    │
    ├─ LP/广告预告（30-90秒）
    │   └─ Hook → ProblemPromise → WorkflowDemo → Differentiator → CTA
    │
    ├─ Intro 演示（2-3分）
    │   └─ Hook → UseCase 声明 → 实际画面 Demo → Objection → CTA
    │
    ├─ 发布说明（1-3分）
    │   └─ Hook → 版本 → Before/After → 新功能 Demo → CTA
    │
    ├─ 架构讲解（5-30分）
    │   └─ Intro → 概览图 → 详细解说×N → 数据流 → 管理/安全 → CTA
    │
    └─ 引导入门（30秒-数分）
        └─ Welcome → 快速胜利 → 下一步
```

**重要原则**:
- 开头不要长时间显示 Logo 和公司介绍（防止流失）
- CTA 不仅放在最后，中间也要放置
- 不是功能罗列而是"痛点→解决"的故事

### Step 2: 从检测功能生成场景

```python
# 伪代码
for feature in detected_features:
    if feature.type == "auth":
        add_scene("认证流程演示", duration=15, source="playwright")
    elif feature.type == "dashboard":
        add_scene("仪表盘介绍", duration=20, source="playwright")
    elif feature.type == "api":
        add_scene("API 概览", duration=10, source="mermaid")
```

### Step 3: 优化时间分配

| 视频长度 | 推荐用途 | 场景数参考 |
|--------|----------|-------------|
| 15秒 | 社交媒体广告 | 3-4 |
| 30秒 | 短视频 | 5-6 |
| 60秒 | 标准演示 | 8-10 |
| 2-3分 | 详细讲解 | 15-20 |

---

## 用户确认流程

### 提案显示

```markdown
🎬 场景规划

**视频类型**: 产品演示
**总时长**: 45秒

| # | 场景 | 时间 | 内容 | 来源 |
|---|--------|------|------|--------|
| 1 | 介绍 | 5秒 | MyApp - 让任务管理变得简单 | 模板 |
| 2 | 认证流程 | 15秒 | 登录界面演示 | Playwright |
| 3 | 仪表盘 | 20秒 | 主要功能介绍 | Playwright |
| 4 | CTA | 5秒 | myapp.com | 模板 |

这个构成可以吗？
1. OK，开始生成
2. 想要编辑
3. 取消
```

### AskUserQuestion 实现

```
AskUserQuestion:
  question: "用这个场景配置生成视频吗？"
  header: "场景确认"
  options:
    - label: "OK，开始生成"
      description: "用这个场景构成生成视频"
    - label: "想要编辑"
      description: "添加/删除/更改场景"
    - label: "取消"
      description: "中止视频生成"
```

### 编辑模式

用户选择"想要编辑"时:

```markdown
📝 场景编辑

可用以下命令编辑：

- **添加**: "添加功能 X 的演示"
- **删除**: "删除场景 2"
- **更改**: "将介绍缩短到 3 秒"
- **替换**: "交换场景 2 和 3"
- **完成**: "就这样"

要编辑什么？
```

---

## 输出格式

planner.md 的输出（generator.md 的输入）:

```yaml
video:
  type: "product-demo"
  total_duration: 45
  resolution: "1080p"
  fps: 30

scenes:
  - id: 1
    name: "intro"
    duration: 5
    template: "intro"
    content:
      title: "MyApp"
      tagline: "让任务管理变得简单"
      logo: "public/logo.svg"

  - id: 2
    name: "auth-demo"
    duration: 15
    template: "ui-demo"
    source: "playwright"
    content:
      url: "http://localhost:3000/login"
      actions:
        - click: "[data-testid=email-input]"
        - type: "user@example.com"
        - click: "[data-testid=login-button]"

  - id: 3
    name: "dashboard"
    duration: 20
    template: "ui-demo"
    source: "playwright"
    content:
      url: "http://localhost:3000/dashboard"
      actions:
        - wait: 1000
        - scroll: "down"

  - id: 4
    name: "cta"
    duration: 5
    template: "cta"
    content:
      url: "https://myapp.com"
      text: "立即试用"
```

---

## Notes

- 场景数过多时自动从提案中排除优先级低的项目
- 用户也可以手动添加场景
- Playwright 来源的场景需要应用已启动
