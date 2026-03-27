---
name: merge-plans
description: "进行 Plans.md 合并更新的技能（保留用户任务）。需要整合多个 Plans.md 时使用。"
allowed-tools: ["Read", "Write", "Edit"]
---

# Merge Plans Skill

更新现有 Plans.md 时，在保留用户任务数据的同时应用模板结构的技能。

---

## 目的

- 保留用户的任务（🔴🟡🟢📦 部分）
- 更新模板的结构和标记定义
- 更新最后更新信息

---

## Plans.md 的结构

```markdown
# Plans.md - 任务管理

> **项目**：{{PROJECT_NAME}}
> **最后更新**：{{DATE}}
> **更新者**：Claude Code

---

## 🔴 进行中的任务        ← 用户数据（保留）

## 🟡 未开始的任务        ← 用户数据（保留）

## 🟢 已完成任务          ← 用户数据（保留）

## 📦 归档                ← 用户数据（保留）

## 标记图例               ← 从模板更新

## 最后更新信息           ← 更新日期
```

---

## 合并算法

### Step 1：分割部分

```
将现有 Plans.md 分割为以下部分：

1. 头部（# Plans.md ... ---）
2. 🔴 进行中的任务（到下一个部分）
3. 🟡 未开始的任务（到下一个部分）
4. 🟢 已完成任务（到下一个部分）
5. 📦 归档（到下一个部分）
6. 标记图例（到下一个部分）
7. 最后更新信息（到文件末尾）
```

### Step 2：提取任务部分

```bash
extract_section() {
  local file="$1"
  local start_marker="$2"
  local end_markers="$3"  # 管道分隔的结束标记

  awk -v start="$start_marker" -v ends="$end_markers" '
    BEGIN { in_section = 0; split(ends, end_arr, "|") }
    $0 ~ start { in_section = 1; next }
    in_section {
      for (i in end_arr) {
        if ($0 ~ end_arr[i]) { in_section = 0; exit }
      }
      if (in_section) print
    }
  ' "$file"
}

# 提取各部分
TASKS_WIP=$(extract_section "$PLANS_FILE" "## 🔴" "## 🟡|## 🟢|## 📦|## 标记|---")
TASKS_TODO=$(extract_section "$PLANS_FILE" "## 🟡" "## 🔴|## 🟢|## 📦|## 标记|---")
TASKS_DONE=$(extract_section "$PLANS_FILE" "## 🟢" "## 🔴|## 🟡|## 📦|## 标记|---")
TASKS_ARCHIVE=$(extract_section "$PLANS_FILE" "## 📦" "## 🔴|## 🟡|## 🟢|## 标记|---")
```

### Step 3：验证任务

```bash
# 确认非空
count_tasks() {
  echo "$1" | grep -c "^\s*- \[" || echo "0"
}

WIP_COUNT=$(count_tasks "$TASKS_WIP")
TODO_COUNT=$(count_tasks "$TASKS_TODO")
DONE_COUNT=$(count_tasks "$TASKS_DONE")
ARCHIVE_COUNT=$(count_tasks "$TASKS_ARCHIVE")

echo "保留的任务："
echo "  进行中：$WIP_COUNT"
echo "  未开始：$TODO_COUNT"
echo "  已完成：$DONE_COUNT"
echo "  归档：$ARCHIVE_COUNT"
```

### Step 4：生成新的 Plans.md

```markdown
# Plans.md - 任务管理

> **项目**：{{PROJECT_NAME}}
> **最后更新**：{{DATE}}
> **更新者**：Claude Code

---

## 🔴 进行中的任务

<!-- cc:WIP 的任务记载在此 -->

{{TASKS_WIP}}

---

## 🟡 未开始的任务

<!-- cc:TODO, pm:依頼中（兼容：cursor:依頼中）的任务记载在此 -->

{{TASKS_TODO}}

---

## 🟢 已完成任务

<!-- cc:完了, pm:確認済（兼容：cursor:確認済）的任务记载在此 -->

{{TASKS_DONE}}

---

## 📦 归档

<!-- 旧的已完成任务移到这里 -->

{{TASKS_ARCHIVE}}

---

## 标记图例

| 标记 | 含义 |
|---------|------|
| `pm:依頼中` | PM 请求的任务（兼容：cursor:依頼中） |
| `cc:TODO` | Claude Code 未开始 |
| `cc:WIP` | Claude Code 工作中 |
| `cc:完了` | Claude Code 完成（待确认） |
| `pm:確認済` | PM 确认完成（兼容：cursor:確認済） |
| `cursor:依頼中` | （兼容）与 pm:依頼中 同义 |
| `cursor:確認済` | （兼容）与 pm:確認済 同义 |
| `blocked` | 阻塞中（附注理由） |

---

## 最后更新信息

- **更新时间**：{{DATE}}
- **最后会话负责人**：Claude Code
- **分支**：main
- **更新类型**：插件更新
```

---

## 空部分的处理

任务为空时，插入默认文本：

```markdown
## 🔴 进行中的任务

<!-- cc:WIP 的任务记载在此 -->

（当前无）
```

---

## 错误处理

### Plans.md 无法解析时

```bash
if ! validate_plans_structure "$PLANS_FILE"; then
  echo "⚠️ 无法解析 Plans.md 的结构"
  echo "保留备份，使用新模板"

  # 备份
  cp "$PLANS_FILE" "${PLANS_FILE}.bak.$(date +%Y%m%d%H%M%S)"

  # 使用模板
  use_template_instead=true
fi
```

### 缺少必需部分时

用模板默认值补充缺失的部分。

---

## 输出

| 项目 | 说明 |
|------|------|
| `merge_successful` | 合并成功标志 |
| `tasks_wip_count` | 进行中任务数 |
| `tasks_todo_count` | 未开始任务数 |
| `tasks_done_count` | 已完成任务数 |
| `tasks_archive_count` | 归档任务数 |
| `backup_created` | 是否创建备份 |

---

## 使用示例

```bash
# 调用技能
merge_plans \
  --existing "./Plans.md" \
  --template "$PLUGIN_PATH/templates/Plans.md.template" \
  --output "./Plans.md" \
  --project-name "my-project" \
  --date "$(date +%Y-%m-%d)"
```

---

## 相关技能

- `update-2agent-files` - 更新整个流程
- `generate-workflow-files` - 新建生成
