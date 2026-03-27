---
name: ci-fix-failing-tests
description: "修复 CI 中失败测试的指南。当 CI 失败原因已确定后，尝试自动修复时使用。"
allowed-tools: ["Read", "Edit", "Bash"]
---

# CI Fix Failing Tests

修复 CI 中失败测试的技能。
进行测试代码修改或主体代码修改。

---

## 输入

- **失败测试信息**: 测试名、错误消息
- **测试文件**: 失败测试的源代码
- **被测代码**: 测试目标的实现

---

## 输出

- **修复后的代码**: 测试或实现的修复
- **测试通过的确认**

---

## 执行步骤

### Step 1: 确定失败测试

```bash
# 本地运行测试
npm test 2>&1 | tail -50

# 特定文件的测试
npm test -- {{test-file}}
```

### Step 2: 分类错误类型

#### 类型 A: 断言失败

```
Expected: "expected value"
Received: "actual value"
```

→ 实现与期望不符，或测试的期望值错误

#### 类型 B: 超时

```
Timeout - Async callback was not invoked within the 5000ms timeout
```

→ 异步处理未完成或耗时过长

#### 类型 C: 类型错误

```
TypeError: Cannot read properties of undefined
```

→ null/undefined 访问或初始化问题

#### 类型 D: Mock 相关

```
expected mockFn to have been called
```

→ Mock 设置不足或未调用

### Step 3: 决定修复策略

```markdown
## 修复方针判断

1. **测试正确的情况** → 修复实现
2. **实现正确的情况** → 修复测试
3. **两者都需要修复**   → 优先修复实现

判断标准:
- 按照规格・需求判断哪边正确
- 最近有什么变更
- 对其他测试的影响
```

### Step 4: 实现修复

#### 断言失败的修复

```typescript
// 测试的期望值错误时
it('calculates correctly', () => {
  // 修复前
  expect(calculate(2, 3)).toBe(5)
  // 修复后（规格是乘法时）
  expect(calculate(2, 3)).toBe(6)
})

// 实现错误时
// → 修改实现文件
```

#### 超时的修复

```typescript
// 延长超时
it('fetches data', async () => {
  // ...
}, 10000)  // 延长到10秒

// 或正确使用 async/await
it('fetches data', async () => {
  await waitFor(() => {
    expect(screen.getByText('Data')).toBeInTheDocument()
  })
})
```

#### Mock 相关的修复

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

### Step 5: 修复后确认

```bash
# 重新运行失败测试
npm test -- {{test-file}}

# 运行所有测试（确认回归）
npm test
```

---

## 修复模式集

### 快照更新

```bash
# 更新快照
npm test -- -u

# 仅特定测试
npm test -- {{test-file}} -u
```

### 异步测试的修复

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
// 根据实现变更更新 Mock
const mockData = {
  id: 1,
  name: 'Test',
  createdAt: new Date().toISOString()  // 新字段
}
```

---

## 修复后的检查清单

- [ ] 失败的测试通过了
- [ ] 其他测试没有损坏
- [ ] 与实现的意图一致
- [ ] 没有过度宽松的测试

---

## 完成报告格式

```markdown
## ✅ 测试修复完成

### 修复内容

| 测试 | 问题 | 修复 |
|-----|------|------|
| `{{测试名}}` | {{问题}} | {{修复内容}} |

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
- **skip 是临时措施**: 禁止永久 skip
- **确定根本原因**: 避免表面修复
