# 典型工作流示例

双代理工作流的实际流程。

---

## 示例 1：新功能开发

### Phase 1：PM（Cursor）创建任务

```markdown
# Plans.md

## 🟡 未开始的任务

- [ ] 用户资料编辑功能 `pm:依頼中`
  - 编辑姓名、邮箱、头像图片
  - 带验证
  - 保存更改历史
```

**PM 的发言**：「请 Claude Code 做资料编辑功能」

---

### Phase 2：Claude Code 开始工作

```bash
# 在 Claude Code 中执行
/work
```

**Claude Code 的工作**：
1. 读取 Plans.md
2. 检测 `pm:依頼中` 任务
3. 将标记更新为 `cc:WIP`
4. 开始实现
5. 用 `/harness-review` 进行质量审查
6. 如有问题则修正 → 再审查（循环，最多 3 次）
7. Review OK → Auto-commit

```markdown
# Plans.md（更新后）

## 🔴 进行中的任务

- [ ] 用户资料编辑功能 `cc:WIP`
  - 编辑姓名、邮箱、头像图片
  - 带验证
  - 保存更改历史
  - 相关文件：
    - `src/components/ProfileForm.tsx`
    - `src/lib/api/profile.ts`
```

---

### Phase 3：Claude Code 完成报告（仅 2-Agent）

Review OK 且 Auto-commit 完成后，在 2-Agent 模式下执行 `/handoff-to-cursor` 向 PM 报告。

> **Solo 模式不需要 handoff** — Review OK → Auto-commit 即完成 /work。

```bash
# 在 Claude Code 中执行（仅 2-Agent 模式）
/handoff-to-cursor
```

**生成的报告**：

```markdown
## 📋 完成报告：用户资料编辑功能

### 实现内容
- 创建 ProfileForm 组件
- 资料 API 端点
- 使用 Zod 进行验证
- 添加更改历史表

### 更改文件
- src/components/ProfileForm.tsx (+150 lines)
- src/lib/api/profile.ts (+80 lines)
- src/lib/validations/profile.ts (+25 lines)
- prisma/schema.prisma (+10 lines)

### 审查结果
✅ harness-review APPROVE（无 Critical/High 问题）

### 测试结果
✅ 全部测试通过 (12/12)

### 下一步行动
- [ ] 在 staging 环境确认运行
- [ ] 设计审查
```

---

### Phase 4：PM 确认

```markdown
# Plans.md（PM 更新后）

## 🟢 已完成任务

- [x] 用户资料编辑功能 `pm:確認済` (2024-01-15)
```

---

## 示例 2：错误修复的紧急对应

### PM 的紧急请求

```markdown
## 🟡 未开始的任务

- [ ] 🔥 【紧急】登录错误修复 `pm:依頼中`
  - 症状：特定用户无法登录
  - 错误："Invalid token format"
  - 优先级：最高
```

### Claude Code 的对应

1. 用 `/work` 着手
2. 调查错误日志
3. 确定原因并修正
4. 添加测试
5. 用 `/harness-review` 审查（有问题则修正→再审查）
6. Review OK → Auto-commit
7. 用 `/handoff-to-cursor` 完成报告（仅 2-Agent。Solo 中省略）

---

## 示例 3：CI 失败时的自动修正

### CI 失败

```
GitHub Actions: ❌ Build failed
- TypeScript error in src/utils/date.ts:45
```

### Claude Code 的自动对应

1. 检测错误
2. 修正类型错误
3. 再提交和推送

**失败 3 次时**：

```markdown
## ⚠️ CI 升级报告

尝试了 3 次修正但无法解决。

### 尝试过的修正
1. 添加类型注解 → 失败
2. 更新类型定义文件 → 失败
3. 调整 tsconfig → 失败

### 推测原因
外部库的类型定义可能过时

### 推荐行动
- [ ] 将 @types/xxx 更新到最新版
- [ ] 确认库本身的版本
```

---

## 示例 4：并行任务执行

### 有多个任务时

```markdown
## 🟡 未开始的任务

- [ ] 重构头部组件 `cc:TODO`
- [ ] 重构底部组件 `cc:TODO`
- [ ] 添加测试：工具函数 `cc:TODO`
```

### 执行 /work 时

Claude Code 判断是否可并行执行：
- 独立任务 → 并行执行
- 有依赖关系 → 串行执行

```
🚀 开始并行执行
├─ Agent 1：头部重构
├─ Agent 2：底部重构
└─ Agent 3：添加测试
```
