---
name: ci-fix-failing-tests
description: "修正 CI 中失败测试的指南。在确定 CI 失败原因后，尝试自动修正时使用。"
allowed-tools: ["Read", "Edit", "Bash"]
---

# CI Fix Failing Tests

修正 CI 中失败测试的技能。
修正测试代码或主体代码。

---

## 输入

- **失败测试信息**: 测试名、错误消息
- **测试文件**: 失败测试的源代码
- **被测代码**: 测试目标的实现

---

## 输出

- **修正后的代码**: 测试或实现的修正
- **确认测试通过**

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

→ 实现与预期不同，或测试期望值错误

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

#### 类型 D: 模拟相关

```
expected mockFn to have been called
```

→ 模拟设置不足或未调用

### Step 3: 决定修正策略

```markdown
## 修正方针判断

1. **测试正确时** → 修正实现
2. **实现正确时** → 修正测试
3. **都需要修正**   → 优先实现

判断基准:
- 对照规格/需求哪边正确
- 最近有什么变更
- 对其他测试的影响
```

### Step 4: 实现修正

#### 修正断言失败

```typescript
// 测试期望值错误时
it('calculates correctly', () => {
  // 修正前
  expect(calculate(2, 3)).toBe(5)
  // 修正后（规格是乘法时）
  expect(calculate(2, 3)).toBe(6)
})

// 实现错误时
// → 修正实现文件
```

#### 修正超时

```typescript
// 延长超时
it('fetches data', async () => {
  // ...
}, 10000)  // 延长到 10 秒

// 或正确使用 async/await
it('fetches data', async () => {
  await waitFor(() => {
    expect(screen.getByText('Data')).toBeInTheDocument()
  })
})
```

#### 修正模拟相关

```typescript
// 添加模拟设置
vi.mock('../api', () => ({
  fetchData: vi.fn().mockResolvedValue({ data: 'mock' })
}))

// beforeEach 中重置
beforeEach(() => {
  vi.clearAllMocks()
})
```

### Step 5: 修正后确认

```bash
# 重新运行失败测试
npm test -- {{test-file}}

# 运行所有测试（回归确认）
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

### 修正异步测试

```typescript
// 使用 findBy（自动等待）
const element = await screen.findByText('Text')

// 使用 waitFor
await waitFor(() => {
  expect(mockFn).toHaveBeenCalled()
})
```

### 更新模拟数据

```typescript
// 根据实现变更更新模拟
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
- [ ] 没有变得过于宽松的测试

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

"提交" 或 "重新运行 CI"
```

---

## 注意事项

- **不要删除测试**: 删除是最后手段
- **skip 是临时的**: 禁止永久 skip
- **定位根本原因**: 避免表面修正
