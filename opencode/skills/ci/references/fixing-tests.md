---
name: ci-fix-failing-tests
description: "修复 CI 中失败测试的指南。在 CI 失败原因确定后，尝试自动修复时使用。"
allowed-tools: ["Read", "Edit", "Bash"]
---

# CI Fix Failing Tests

修复 CI 中失败测试的技能。
进行测试代码修正，或本体代码修正。

---

## 输入

- **失败测试信息**: 测试名、错误消息
- **测试文件**: 失败测试的源码
- **被测代码**: 测试目标的实现

---

## 输出

- **修正后的代码**: 测试或实现的修正
- **测试通过的确认**

---

## 执行步骤

### Step 1: 失败测试的识别

```bash
# 本地运行测试
npm test 2>&1 | tail -50

# 特定文件的测试
npm test -- {{test-file}}
```

### Step 2: 错误类型分类

#### 类型 A: 断言失败

```
Expected: "expected value"
Received: "actual value"
```

→ 实现与预期不同，或测试的期望值有误

#### 类型 B: 超时

```
Timeout - Async callback was not invoked within the 5000ms timeout
```

→ 异步处理未完成，或耗时过长

#### 类型 C: 类型错误

```
TypeError: Cannot read properties of undefined
```

→ null/undefined 访问，或初始化问题

#### 类型 D: Mock 相关

```
expected mockFn to have been called
```

→ Mock 设置不足，或未进行调用

### Step 3: 修正策略决定

```markdown
## 修正方针判断

1. **测试正确的情况** → 修正实现
2. **实现正确的情况** → 修正测试
3. **两者都需要修正** → 优先实现

判断基准:
- 对照规格/需求，哪一方是正确的
- 最近做了什么更改
- 对其他测试的影响
```

### Step 4: 修正实现

#### 断言失败的修正

```typescript
// 测试期望值有误的情况
it('calculates correctly', () => {
  // 修正前
  expect(calculate(2, 3)).toBe(5)
  // 修正后（规格是乘法的情况）
  expect(calculate(2, 3)).toBe(6)
})

// 实现有误的情况
// → 修正实现文件
```

#### 超时的修正

```typescript
// 延长超时时间
it('fetches data', async () => {
  // ...
}, 10000)  // 延长至 10 秒

// 或正确使用 async/await
it('fetches data', async () => {
  await waitFor(() => {
    expect(screen.getByText('Data')).toBeInTheDocument()
  })
})
```

#### Mock 相关的修正

```typescript
// 添加 Mock 设置
vi.mock('../api', () => ({
  fetchData: vi.fn().mockResolvedValue({ data: 'mock' })
}))

// 在 beforeEach 中重置
beforeEach(() => {
  vi.clearAllMocks()
})
```

### Step 5: 修正后确认

```bash
# 重新运行失败测试
npm test -- {{test-file}}

# 运行全部测试（回归确认）
npm test
```

---

## 修正模式集

### 快照更新

```bash
# 更新快照
npm test -- -u

# 仅特定测试
npm test -- {{test-file}} -u
```

### 异步测试的修正

```typescript
// 使用 findBy（自动等待）
const element = await screen.findByText('Text')

// 使用 waitFor
await waitFor(() => {
  expect(mockFn).toHaveBeenCalled()
})
```

### Mock 数据的更新

```typescript
// 根据实现的更改更新 Mock
const mockData = {
  id: 1,
  name: 'Test',
  createdAt: new Date().toISOString()  // 新字段
}
```

---

## 修正后检查清单

- [ ] 失败的测试通过
- [ ] 其他测试未被破坏
- [ ] 与实现意图一致
- [ ] 未变成过于宽松的测试

---

## 完成报告格式

```markdown
## ✅ 测试修正完成

### 修正内容

| 测试 | 问题 | 修正 |
|-------|------|------|
| `{{测试名}}` | {{问题}} | {{修正内容}} |

### 确认结果

```
Tests: {{passed}} passed, {{total}} total
```

### 下一步操作

「提交」或「重新运行 CI」
```

---

## 注意事项

- **不要删除测试**: 删除是最后手段
- **skip 仅作临时使用**: 禁止永久性 skip
- **确定根本原因**: 避免表面修正
