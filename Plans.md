# Claude Code Harness — Plans.md

最终归档: 2026-03-26（Phase 29.0, Phase 25 → `.claude/memory/archive/Plans-2026-03-26-phase29-25-completed.md`）

---

## Phase 31: 日文→中文国际化（i18n-zh）

创建日期: 2026-03-26
目标: 将项目主要文档和代码注释从日文转换为中文，提升中文用户的使用体验

### 背景

- 项目共有 536 个文件包含日文字符
- 主要分布在: skills/ (85), scripts/ (91), opencode/skills/ (82), codex/.codex/skills/ (84)
- 作者 jyf2100 以日文为主要文档语言
- 已有 README_cn.md 作为中文支持，但核心技能和脚本仍为日文

### 优先级矩阵

| 优先级 | Phase | 内容 | 文件数 |
|--------|-------|------|--------|
| **Required** | 31.0 | 核心技能文件国际化 (skills/) | 85 |
| **Required** | 31.1 | 脚本输出消息国际化 (scripts/) | 91 |
| **Recommended** | 31.2 | Agent 定义文件国际化 | 15 |
| **Recommended** | 31.3 | 规则文件国际化 | 9 |
| **Optional** | 31.4 | 模板文件国际化 | 34 |
| **Required** | 31.5 | 整合验证·CHANGELOG | 2 |

---

### Phase 31.0: 核心技能文件国际化 [P0] [P]

| Task | 内容 | Status |
|------|------|--------|
| 31.0.1 | 创建进度跟踪文件 | cc:完了 |
| 31.0.2 | 翻译核心工作流技能 (6 个) | cc:完了 |
| 31.0.3 | 翻译 breezing/ | cc:完了 |
| 31.0.4 | 翻译会话管理技能 (5 个) | cc:完了 |
| 31.0.5 | 翻译内存管理技能 | cc:完了 |
| 31.0.6 | 翻译 UI 相关技能 | cc:完了 |
| 31.0.7 | 翻译其他技能 (14 个) | cc:完了 |

### Phase 31.1: 脚本输出消息国际化 [P0] [P]

| Task | 内容 | Status |
|------|------|--------|
| 31.1.1 | 创建脚本翻译规范文档 | cc:完了 |
| 31.1.2-7 | 翻译各类脚本 (91 个) | cc:TODO |

### Phase 31.2-31.5: Agent/规则/模板/验证

| Task | 内容 | Status |
|------|------|--------|
| 31.2.1-2 | Agent 定义文件翻译 | cc:TODO |
| 31.3.1-2 | 规则文件翻译 | cc:TODO |
| 31.4.1-3 | 模板文件翻译 | cc:TODO |
| 31.5.1-2 | 验证 + CHANGELOG | cc:TODO |

---

## Phase 32: 日文内容清理（i18n-zh 完成后）

创建日期: 2026-03-27
目标: 彻底删除项目中剩余的日文专用文件和字段

### 日文残留清单

| 类别 | 文件/位置 | 数量 | 操作 |
|------|----------|------|------|
| 日文专用文件 | README_ja.md, LICENSE.ja.md | 2 | 删除 |
| description-ja 字段 | skills-v3/, skills/ | 8 | 删除字段 |
| codex skills 日文 | codex/.codex/skills/*/SKILL.md | ~20 | 翻译或同步 |
| TypeScript 注释 | core/src/*.ts | 17 | 翻译 |
| CHANGELOG 历史记录 | CHANGELOG.md | 470处 | 保留（历史记录） |

### Phase 32.0: 删除日文专用文件 [P0]

| Task | 内容 | DoD | Status |
|------|------|-----|--------|
| 32.0.1 | 删除 README_ja.md | 文件已删除 | cc:完了 |
| 32.0.2 | 删除 LICENSE.ja.md | 文件已删除 | cc:完了 |
| 32.0.3 | 更新 CLAUDE.md 中的日文引用 | 无日文文件引用 | cc:完了 |

### Phase 32.1: 删除 description-ja 字段 [P0]

| Task | 内容 | DoD | Status |
|------|------|-----|--------|
| 32.1.1 | 删除 skills-v3/ 中的 description-ja | 7 个文件已清理 | cc:完了 |
| 32.1.2 | 删除 skills/ 中的 description-ja | 1 个文件已清理 | cc:完了 |

### Phase 32.2: 同步/翻译 codex skills [P1]

| Task | 内容 | DoD | Status |
|------|------|-----|--------|
| 32.2.1 | 将 codex/.codex/skills/ 设为符号链接 | 指向主 skills/ | cc:完了 |
| 32.2.2 | 或翻译所有 codex skills 日文 | 无日文残留 | cc:完了 |

### Phase 32.3: 翻译 TypeScript 注释 [P2]

| Task | 内容 | DoD | Status |
|------|------|-----|--------|
| 32.3.1 | 翻译 core/src/guardrails/ 注释 | 无日文注释 | cc:完了 |
| 32.3.2 | 翻译 core/src/ 其他文件注释 | 无日文注释 | cc:完了 |

### Phase 32.4: 验证与清理 [P0]

| Task | 内容 | DoD | Status |
|------|------|-----|--------|
| 32.4.1 | 更新 i18n-zh-progress.json | 状态为"日文清理完成" | cc:完了 |
| 32.4.2 | 全局日文残留扫描 | 0 处日文（除 CHANGELOG） | cc:完了 |
| 32.4.3 | 提交并更新 CHANGELOG | commit 完成 | cc:完了 [7709063] |

---

## Phase 29: CCAGI 来源要素整合（29.1〜29.4 待完成）

### Phase 29.1: Plans.md ⇄ GitHub Issue 桥接（opt-in） [P1]

| Task | 内容 | Status |
|------|------|--------|
| 29.1.1-3 | team mode 规范 + bridge script + docs | cc:TODO |

### Phase 29.2: pre-release verification [P1]

| Task | 内容 | Status |
|------|------|--------|
| 29.2.1-3 | preflight 检查 + script + 引导 | cc:TODO |

### Phase 29.3: brief 和 manifest [P2]

| Task | 内容 | Status |
|------|------|--------|
| 29.3.1-3 | brief 生成 + manifest 生成 + docs | cc:TODO |

### Phase 29.4: 整合验证

| Task | 内容 | Status |
|------|------|--------|
| 29.4.1-2 | 验证 + CHANGELOG | cc:TODO |

---

## Phase 25: 单人模式 PM 框架（待完成: 25.5.3）

### Phase 25.5: 整合验证·发布

| Task | 内容 | Status |
|------|------|--------|
| 25.5.3 | GitHub Release 创建 | cc:TODO |

---

## 已归档 Phase

| Phase | 内容 | 归档日期 |
|-------|------|----------|
| Phase 29.0 | AI 残留审查关卡 | 2026-03-26 |
| Phase 25 (25.5.1-2) | 单人模式 PM 框架 | 2026-03-26 |
| Phase 26〜28 | Masao 理论/CC 更新跟踪 | 2026-03-26 |
| Phase 30 / M-CC79 / Fix | CC/Codex 对应/整合/质量改善 | 2026-03-26 |

详情: `.claude/memory/archive/Plans-*.md`
