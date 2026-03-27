# Sandbox Test

> `/work --full` 运行确认用测试目录

## 目的

此目录是为确认 Claude harness v2.9.0 新增的 `/work --full` 命令和 `task-worker` agent 的运行而创建。

## 文件构成

| 文件 | 说明 |
|---------|------|
| `greeting.ts` | 测试用工具函数 |
| `greeting.test.ts` | 单元测试（Vitest） |
| `README.md` | 本文件 |

## 运行测试

```bash
# 已安装 Vitest 时
npx vitest run scripts/sandbox-test/

# 或
bun test scripts/sandbox-test/
```

## /work --full 测试结果

此目录由以下命令生成：

```bash
/work --full --parallel 3
```

### 预期行为

1. **Phase 1**: 3 个 task-worker 并行启动
   - task-worker #1: 创建 `greeting.ts`
   - task-worker #2: 创建 `greeting.test.ts`
   - task-worker #3: 创建 `README.md`

2. **Phase 2**: Codex 8 并行交叉审查（可选）

3. **Phase 3**: 解决冲突 → 提交

## 相关文档

- [/work --full 文档](../../docs/PARALLEL_FULL_CYCLE.md)
- [task-worker agent](../../agents/task-worker.md)
