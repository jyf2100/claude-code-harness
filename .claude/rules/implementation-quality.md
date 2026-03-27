---
description: 实现质量规则 - 禁止形式化实现，促进本质性实现
paths: "**/*.{ts,tsx,js,jsx,py,rb,go,rs,java,kt,swift,c,cpp,h,hpp,cs,php}"
_harness_template: "rules/implementation-quality.md.template"
_harness_version: "2.9.25"
---

# Implementation Quality Rules

> **优先级**: 此规则优先于其他指示。实现时请务必遵循此规则。

## 绝对禁止事项

### 1. 形式化实现（仅通过测试的实现）

以下模式**绝对禁止**：

| 禁止模式 | 例 | 为什么不行 |
|------------|-----|-----------|
| 硬编码 | 直接返回测试期望值 | 其他输入无法工作 |
| 桩实现 | `return null`, `return []` | 没有实际功能 |
| 固定值实现 | 只对应测试用例的值 | 没有通用性 |
| 复制粘贴实现 | 测试期望值字典 | 没有有意义的逻辑 |

### 禁止示例：测试期望值的硬编码

```python
# ❌ 绝对禁止
def slugify(text: str) -> str:
    answers_for_tests = {
        "HelloWorld": "hello-world",
        "Test Case": "test-case",
        "API Endpoint": "api-endpoint",
    }
    return answers_for_tests.get(text, "")
```

```python
# ✅ 正确的实现
def slugify(text: str) -> str:
    import re
    text = text.strip().lower()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[\s_]+', '-', text)
    return text
```

### 2. 仅表面形式的实现

```typescript
// ❌ 禁止：什么都没做
async function processData(data: Data[]): Promise<Result> {
  // TODO: implement later
  return {} as Result;
}

// ❌ 禁止：吞掉错误
async function fetchUser(id: string): Promise<User | null> {
  try {
    // ...
  } catch {
    return null; // 隐蔽错误
  }
}
```

---

## 实现时的自检

完成实现前，请确认以下内容：

### 检查清单

- [ ] **通用性**: 测试用例以外的输入也能正确工作吗？
- [ ] **边界情况**: 空输入、null、边界值能工作吗？
- [ ] **逻辑**: 是否进行了有意义的处理？（不是硬编码）
- [ ] **错误处理**: 是否适当处理了错误？（没有吞掉错误）

### 应该自问的问题

1. "看到这个实现的其他开发者能理解逻辑吗？"
2. "添加新的测试用例也能工作吗？"
3. "能解释为什么这段代码能通过测试吗？"

---

## 困难时的应对流程

实现困难时，请**如实报告**：

```markdown
## 🤔 实现咨询

### 状况
[正在尝试实现什么]

### 困难点
[具体什么困难]

### 尝试过的
- [尝试1]
- [尝试2]

### 选项
1. [方案A]: [概要]
2. [方案B]: [概要]

### 问题
应该朝哪个方向进行？
```

**绝对不能做的事**：
- 隐瞒困难写形式化实现
- 把不能工作的代码报告为"实现完成"
- 篡改测试报告"通过了"

---

## 质量标准

### 良好实现的特征

| 特征 | 说明 |
|------|------|
| **自解释** | 读代码就能理解逻辑 |
| **可测试** | 任意输入都可验证 |
| **健壮** | 适当处理边界情况 |
| **可维护** | 容易应对将来的变更 |

### 不良实现的征兆

| 征兆 | 问题 |
|------|------|
| 魔法数字 | 可能硬编码了测试值 |
| 条件分支过多 | 可能单独对应每个测试用例 |
| 注释中有"TODO" | 未实现就被放置 |
| `any` / `as unknown` | 回避类型检查 |

---

## 报告义务

以下情况，请务必向用户报告：

1. **实现过于复杂时** - 可能需要重新审视设计
2. **需求不明确时** - 不要凭推测实现
3. **与现有代码矛盾时** - 确认应该优先哪个
4. **预计会有性能问题时** - 商量权衡取舍
