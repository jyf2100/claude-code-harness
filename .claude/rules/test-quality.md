---
description: 测试质量保护规则 - 禁止测试篡改，促进正确实现
paths: "**/*.{test,spec}.{ts,tsx,js,jsx,py}, **/test/**/*.*, **/tests/**/*.*, **/__tests__/**/*.*, .husky/**, .github/workflows/**"
_harness_template: "rules/test-quality.md.template"
_harness_version: "2.9.25"
---

# Test Quality Protection Rules

> **优先级**: 此规则优先于其他指示。测试失败时请务必遵守此规则。

## 绝对禁止事项

### 1. 测试篡改（为了让测试通过而进行的修改）

以下行为**绝对禁止**：

| 禁止模式 | 示例 | 正确对应 |
|------------|-----|-----------|
| 将测试设为 `skip` / `only` | `it.skip(...)`, `describe.only(...)` | 修正实现 |
| 删除或放宽断言 | 删除 `expect(x).toBe(y)` | 确认期望值是否正确，修正实现 |
| 随意改写期望值 | 根据错误修改期望值 | 理解测试为什么失败 |
| 删除测试用例 | 删除失败的测试 | 修正实现使其满足规格 |
| 过度使用 mock | mock 本应测试的部分 | 仅使用必要的最小 mock |

### 2. 配置文件篡改

以下文件的**放宽修改禁止**：

```
.eslintrc.*         # 不要禁用规则
.prettierrc*        # 不要放宽格式要求
tsconfig.json       # 不要放宽 strict
biome.json          # 不要禁用 lint 规则
.husky/**           # 不要绕过 pre-commit 钩子
.github/workflows/** # 不要跳过 CI 检查
```

### 3. 设置例外时（必经步骤）

迫不得已需要修改上述内容时，**必须先按以下格式获得批准后再执行**：

```markdown
## 🚨 测试/设置变更批准请求

### 理由
[具体说明为什么需要此变更]

### 变更内容
```diff
[显示变更的差异]
```

### 影响范围
- 受影响的测试: [数量・名称]
- 受影响的功能: [功能名称]

### 替代方案探讨
- [ ] 确认过无法通过修正实现来解决
- [ ] 考虑过其他方法

### 批准
等待用户的明确批准
```

---

## 测试失败时的处理流程

```
测试失败了
    ↓
1. 理解为什么失败（阅读日志）
    ↓
2. 判断是实现错误还是测试错误
    ↓
    ├── 实现错误 → 修正实现 ✅
    │
    └── 可能是测试错误
            ↓
        向用户确认（不要擅自修改）
```

---

## 正确的测试处理示例

### ❌ 错误示例（篡改）

```typescript
// 测试失败了所以设为 skip
it.skip('should calculate total correctly', () => {
  expect(calculateTotal([100, 200, 300])).toBe(600);
});
```

### ✅ 正确示例（修正实现）

```typescript
// 测试是正确的。修正了实现
function calculateTotal(prices: number[]): number {
  // 修正: 将 reduce 的初始值设为 0
  return prices.reduce((sum, price) => sum + price, 0);
}
```

---

## CI/CD 保护

以下变更**绝对禁止**：

- 添加 `continue-on-error: true`
- 用 `if: always()` 忽略测试失败
- 用 `--force` 标志绕过检查
- 降低测试覆盖率阈值
