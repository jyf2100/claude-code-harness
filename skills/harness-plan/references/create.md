# create 子命令 — 计划创建流程

通过调研想法和需求，生成可执行的 Plans.md。

## Step 0：确认会话上下文

可从之前的会话提取需求时进行确认：

> 请选择计划的创建方式：
> 1. 从之前的会话 — 基于头脑风暴内容创建计划
> 2. 从零开始 — 从调研开始

选择「从之前的会话」时：提取需求/想法/决策事项并向用户确认。
确认后，跳到 Step 3（技术调查）。

## Step 1：询问要做什么

无用户输入时提问：

> 要做什么？
>
> 例：预约管理系统 / 博客网站 / 任务管理应用 / API 服务器
>
> 粗略的想法也可以！

## Step 2：提高清晰度（最多 3 问）

> 请再告诉我一些：
>
> 1. 谁会使用？（只有自己？团队？公开？）
> 2. 有想参考的服务吗？
> 3. 做到什么程度？（MVP？完整功能？）

## Step 3：技术调查（WebSearch）

不问用户，由 Claude Code 调查并提议。

```
WebSearch:
- "{{项目类型}} tech stack 2025"
- "{{类似服务}} architecture"
```

## Step 4：提取功能列表

从需求中提取具体功能列表。

例：预约管理系统的情况
- 用户注册/登录
- 预约日历显示
- 预约的创建/编辑/取消
- 管理员仪表盘
- 邮件通知
- 支付功能

## Step 5：创建优先级矩阵（2 轴评价）

各功能按 **Impact（影响度）× Risk（风险/不确定性）** 的 2 轴评价：

- **Impact**：用户价值 × 目标用户数（高/低）
- **Risk**：技术未知 × 外部依赖（高/低）

| Impact＼Risk | 低风险 | 高风险 |
|-------------|--------|--------|
| **高 Impact** | ★ **Required** — 最优先（确定有价值） | ▲ **Required + [needs-spike]** — 需要早期验证 |
| **低 Impact** | ○ **Recommended** — 有余力时处理 | ✕ **Optional** — 暂缓或缩小范围 |

### `[needs-spike]` 标记

高 Impact × 高 Risk 的任务自动添加 `[needs-spike]` 标记。
带 `[needs-spike]` 的任务会**自动生成 spike（技术验证）任务**并先行：

```markdown
| N.X-spike | [spike] {{任务名}} 的技术验证 | 创建验证结果报告 | - | cc:TODO |
| N.X       | {{任务名}} [needs-spike] | {{DoD}} | N.X-spike | cc:TODO |
```

spike 任务的完成条件是「留下验证结果报告（可行/不可行/需要设计变更）」。

## Step 5.5：TDD 跳过判断（默认启用）

TDD 默认启用。仅以下任务添加 `[skip:tdd]` 标记跳过：

| 跳过条件 | 理由 |
|---------|------|
| 仅文档/注释 | 不影响执行代码 |
| 仅配置文件（JSON, YAML, .env） | 没有测试对象的逻辑 |
| 1 行以下的简单修正（typo） | 测试成本超过效果 |
| 仅样式/格式更改 | 不影响行为 |
| 仅依赖更新 | 无实现逻辑更改 |
| README/CHANGELOG 更新 | 仅文档 |
| 重构（无行为更改） | 已被现有测试覆盖 |

不符合以上条件的任务自动应用 TDD（推荐测试先行）。

## Step 5.7：Plans.md v3 格式规格

Plans.md v3 包含以下格式扩展：

### Phase 头部的 Purpose 行（可选）

各 Phase 的头部可写 1 行 Purpose（目的）。无输入时省略：

```markdown
### Phase N.X: [阶段名] [Px]

Purpose: [用 1 行描述此阶段要解决的问题]
```

- **默认**：不请求输入（空白时省略）
- **记载时的效果**：在 breezing Phase 0 的范围确认中显示
- **生成规则**：仅当用户明确表述阶段目的时自动记载

### Artifact 表示（Status 列）

任务完成时在 Status 中附加 commit hash：

```markdown
| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 1.1  | ... | ... | - | cc:完了 [a1b2c3d] |
| 1.2  | ... | ... | 1.1 | cc:TODO |
```

- **格式**：`cc:完了 [7字符hash]`
- **附加时机**：`harness-work` Solo Step 7 自动附加
- **向后兼容**：无 hash 的 `cc:完了` 继续有效

### 影响文件列表

与 v3 格式相关的文件：

| 文件 | 影响 |
|------|------|
| `skills/harness-plan/references/create.md` | Step 6 模板添加 Purpose 行 |
| `skills/harness-plan/references/sync.md` | 差异检测识别 `cc:完了 [hash]` 格式 |
| `skills/harness-work/SKILL.md` | Solo Step 7 附加 hash，失败时重新工单化 |
| `skills/harness-sync/SKILL.md` | --snapshot 保存快照 |
| `skills/breezing/SKILL.md` | Progress Feed 显示进度 |

## Step 6：生成 Plans.md

自动生成质量标记 + DoD + Depends 并生成 Plans.md。

### 质量标记附加逻辑
```
分析任务内容
    ↓
├── "auth" "login" "API" → [feature:security]
├── "component" "UI" "screen" → [feature:a11y]
├── "fix" "bug" → [bugfix:reproduce-first]
├── "docs" "comment" "README" "CHANGELOG" → [skip:tdd]
├── "config" "json" "yaml" "env" → [skip:tdd]
├── "style" "format" "lint" → [skip:tdd]
├── "refactor" (无行为更改) → [skip:tdd]
├── "payment" "billing" → [feature:security]
└── 其他 → 无标记（TDD 默认启用）
```

### DoD 自动推断逻辑

基于任务「内容」的关键词推断 DoD 并自动填充：

| 任务内容关键词 | DoD 推断 |
|--------------|---------|
| "创建" "新增" "添加" | 文件存在且具有预期结构 |
| "测试" "test" | 测试通过（`npm test` / `pytest` 等） |
| "修复" "fix" "bug" | 问题不再重现 |
| "UI" "画面" "组件" | 显示确认（截图或浏览器） |
| "API" "端点" | 用 curl/httpie 确认响应 |
| "设置" "config" | 设置值生效 |
| "文档" "docs" | 文件存在，无断链 |
| "迁移" "DB" | 迁移可执行 |
| "重构" | 现有测试全部通过 + lint 错误 0 |

推断结果仅为默认值。用户指定具体验收条件时优先用户条件。

### Depends 自动推断逻辑

按以下规则推断阶段内任务间的依赖关系：

1. **DB/模式相关任务** → 被其他实现任务依赖（先行任务）
2. **UI 任务** → 依赖 API/逻辑 任务（后行任务）
3. **测试/验证任务** → 依赖实现任务（最后）
4. **设置/环境任务** → 被其他任务依赖（先行任务）
5. **无明显依赖的任务** → `-`（可并行执行）

推断不确定时设为 `-`，向用户确认。

**生成模板**：

```markdown
# [项目名] Plans.md

创建日期：YYYY-MM-DD

---

## Phase 1: [阶段名]

Purpose: [阶段目的（可省略）]

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 1.1  | [任务说明] [feature:security] | [可验证的完成条件] | - | cc:TODO |
| 1.2  | [任务说明] | [可验证的完成条件] | 1.1 | cc:TODO |
```

**Purpose 行**：
- 仅当用户表述阶段目的时自动记载
- 无输入时省略整个 Purpose 行（不留空行）
- 用 1 行完结（禁止多行）

**DoD（Definition of Done）写法**：
- 用可验证的 1 行写（例：「测试通过」「迁移可执行」「lint 错误 0」）
- 禁止「感觉不错」「正常运行」等。要用 Yes/No 可判定的形式

**Depends 写法**：
- 无依赖：`-`
- 单一依赖：任务编号（例：`1.1`）
- 多重依赖：逗号分隔（例：`1.1, 1.2`）
- 阶段依赖：阶段编号（例：`Phase 1`）

## Step 7：引导下一步行动

> Plans.md 完成！
>
> 下一步：
> - 用 `harness-work` 开始实现
> - 或者说「从 Phase 1 开始」
> - 添加功能用 `harness-plan add [功能名]`
> - 推迟功能用 `harness-plan update [任务] blocked`

## CI 模式（--ci）

无调研。直接利用现有 Plans.md 仅进行任务分解。

1. 读取 Plans.md
2. 按优先级列出 cc:TODO 任务
3. 对可并行的任务标记 `[P]`
4. 提议下一个执行任务
