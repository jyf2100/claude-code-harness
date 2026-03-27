---
name: core-diff-aware-editing
description: "以最小差异编辑文件，将对现有代码的影响降到最低。"
allowed-tools: ["Read", "Edit"]
---

# Diff-Aware Editing

文件编辑时以最小差异进行变更的技能。
防止破坏现有代码，实现易于审查的变更。

---

## 基本原则

### 1. Read Before Edit

**必须先读取目标文件再编辑**

```
❌ 错误示例：用 Write 工具整体覆盖文件
✅ 正确示例：Read → 确认内容 → 用 Edit 只修改必要部分
```

### 2. 优先最小差异

变更控制在最小必要范围：

- 保持现有缩进・格式
- 保留现有注释
- 配合已有风格

### 3. 按有意义单位变更

```typescript
// ❌ 错误示例：混入无关变更
// 添加函数 + 格式变更 + import 整理

// ✅ 正确示例：集中在一个变更
// 只添加函数
```

---

## Edit 工具用法

### 模式 1：简单替换

```
old_string: "const value = 1"
new_string: "const value = 2"
```

### 模式 2：添加代码块

```
old_string: "// TODO: implement feature"
new_string: "// Feature implemented
const feature = () => {
  // implementation
}"
```

### 模式 3：修改函数

```
old_string: "function getData() {
  return []
}"
new_string: "function getData() {
  const data = fetchData()
  return data
}"
```

---

## 应避免的模式

### 1. 整体重写文件

```
❌ 用 Write 工具重写整个 100 行文件
✅ 用 Edit 工具只修改需要变更的 5 行
```

### 2. 混入格式变更

```
❌ 添加功能的同时改变缩进
✅ 只添加功能。格式变更放在其他提交
```

### 3. 添加不必要的空行・注释

```
❌ 强加自己的风格
✅ 遵循现有风格
```

---

## 编辑前检查清单

1. [ ] 已用 Read 确认目标文件
2. [ ] 已确定需要变更的位置
3. [ ] 已把握现有风格（缩进、命名约定）
4. [ ] 已确认变更在 paths.allowed_modify 范围内
5. [ ] 已能想象变更后的行为

---

## 编辑后确认

```bash
# 确认差异
git diff

# 确认变更行数（是否过大）
git diff --stat

# 是否有语法错误
npm run build 2>&1 | head -20
# 或者
npx tsc --noEmit
```

---

## 编辑多个文件

编辑多个文件时：

1. **依赖关系顺序**：类型定义 → 实现 → 测试
2. **确保一致性**：相关变更同时进行
3. **中间状态也能运行**：每次编辑后保持构建通过

---

## 出错时的应对

编辑发生错误时：

1. **再次确认原代码**：用 Read 确认当前状态
2. **确认 old_string 匹配**：空白・换行要精确
3. **尝试分割**：大变更拆分成小块
