---
name: core-diff-aware-editing
description: "用最小差异编辑文件，将对现有代码的影响降到最低。"
allowed-tools: ["Read", "Edit"]
---

# Diff-Aware Editing

文件编辑时用最小差异进行更改的技能。
防止破坏现有代码，实现易于审查的更改。

---

## 基本原则

### 1. Read Before Edit

**必须先读取目标文件再编辑**

```
❌ 错误示例：用 Write 工具覆盖整个文件
✅ 正确示例：Read → 确认内容 → 用 Edit 只更改必要部分
```

### 2. 优先最小差异

更改控制在必要的最小限度：

- 保持现有的缩进和格式
- 保留现有的注释
- 配合使用的样式

### 3. 以有意义的单位更改

```typescript
// ❌ 错误示例：混合无关的更改
// 函数添加 + 格式更改 + import 整理

// ✅ 正确示例：集中在一个更改
// 只添加函数
```

---

## Edit 工具的使用方法

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

### 模式 3：修正函数

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

### 1. 重写整个文件

```
❌ 用 Write 工具重写 100 行的整个文件
✅ 用 Edit 工具只修正需要更改的 5 行
```

### 2. 混入格式更改

```
❌ 添加功能的同时更改缩进
✅ 只添加功能。格式在另一个提交中处理
```

### 3. 添加不必要的空行和注释

```
❌ 强加自己的样式
✅ 遵循现有样式
```

---

## 编辑前检查清单

1. [ ] 用 Read 确认了目标文件
2. [ ] 确定了需要更改的位置
3. [ ] 把握了现有样式（缩进、命名规范）
4. [ ] 确认更改是否包含在 paths.allowed_modify 中
5. [ ] 能想象更改后的行为

---

## 编辑后的确认

```bash
# 确认差异
git diff

# 确认更改行数（是否过大）
git diff --stat

# 是否有语法错误
npm run build 2>&1 | head -20
# 或者
npx tsc --noEmit
```

---

## 编辑多个文件

编辑多个文件时：

1. **依赖关系的顺序**：类型定义 → 实现 → 测试
2. **确保一致性**：相关更改同时进行
3. **中间状态也能运行**：每次编辑后保持构建通过的状态

---

## 错误时的应对

编辑发生错误时：

1. **再次确认原代码**：用 Read 确认当前状态
2. **确认 old_string 匹配**：准确匹配空白和换行
3. **尝试分割**：将大更改分成小块
