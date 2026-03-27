---
name: notebookLM
description: "生成 NotebookLM 用 YAML 和幻灯片。文档工匠大显身手。Use when user mentions NotebookLM, YAML, slides, or presentations. Do NOT load for: implementation work, code fixes, reviews, or deployments."
description-en: "Generate NotebookLM YAML and slides. Document craftsman shows skill. Use when user mentions NotebookLM, YAML, slides, or presentations. Do NOT load for: implementation work, code fixes, reviews, or deployments."
description-ja: "NotebookLM用YAMLやスライドを生成。ドキュメント職人の腕の見せ所。Use when user mentions NotebookLM, YAML, slides, or presentations. Do NOT load for: implementation work, code fixes, reviews, or deployments."
allowed-tools: ["Read", "Write", "Edit"]
argument-hint: "[yaml|slides]"
---

# NotebookLM Skill

负责文档生成的技能群。

## 功能详情

| 功能 | 详情 |
|------|------|
| **NotebookLM YAML** | See [references/notebooklm-yaml.md](${CLAUDE_SKILL_DIR}/references/notebooklm-yaml.md) |
| **幻灯片 YAML** | See [references/notebooklm-slides.md](${CLAUDE_SKILL_DIR}/references/notebooklm-slides.md) |

## 执行步骤

1. 分类用户请求
2. 从上述「功能详情」读取适当的参考文件
3. 按其内容生成

---

## 🔧 PDF 页面范围读取（Claude Code 2.1.49+）

高效处理大型 PDF 的功能。

### 指定页面范围读取

```javascript
// 指定页面范围读取
Read({ file_path: "docs/spec.pdf", pages: "1-10" })

// 只确认目录
Read({ file_path: "docs/manual.pdf", pages: "1-3" })

// 只读特定章节
Read({ file_path: "docs/api-reference.pdf", pages: "25-45" })
```

### 按用途的推荐方法

| 情况 | 推荐读取方法 | 理由 |
|--------|----------------|------|
| **100 页以上的 PDF** | 目录(1-3) → 仅相关章节 | 最小化 token 消费 |
| **规格书审查** | 按章节指定范围 | 只精读必要部分 |
| **API 文档** | 从端点列表(目录)开始 | 先把握整体结构再深入 |
| **学术论文** | 摘要 + 结论 → 正文 | 先把握要点 |
| **技术手册** | 目录 + 故障排除章节 | 优先实用部分 |

### NotebookLM YAML 生成时的应用示例

```markdown
从大型 PDF（300 页技术规格书）生成 YAML 时：

1. **读取目录**（1-5 页）
   Read({ file_path: "spec.pdf", pages: "1-5" })
   → 把握章节结构

2. **读取各章节开头**（各章节前 2 页）
   Read({ file_path: "spec.pdf", pages: "10-11" })  // 第 1 章
   Read({ file_path: "spec.pdf", pages: "45-46" })  // 第 2 章
   → 把握各章节概要

3. **精读重要章节**
   Read({ file_path: "spec.pdf", pages: "78-95" })  // API 参考
   → 抽取详细内容

这样无需读取全部 300 页即可高效生成 YAML。
```

### 最佳实践

| 原则 | 说明 |
|------|------|
| **渐进式加载** | 按目录 → 概要 → 详情顺序读取 |
| **仅相关页面** | 只指定任务所需的页面 |
| **节约 token** | 全页读取是最后手段 |
| **优先理解结构** | 先用目录把握整体再深入 |

### 与传统方法的比较

| 方法 | Token 消费 | 处理时间 | 精度 |
|------|------------|---------|------|
| **全页读取**（300 页） | ~150,000 | 长 | 高 |
| **页面范围指定**（需要的 30 页） | ~15,000 | 短 | 高 |

→ **可节省 90% token 和缩短处理时间**
