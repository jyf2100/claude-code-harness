---
name: auth
description: "认证和支付功能实现。支持 Clerk、Supabase Auth、Stripe。Use when user mentions login, authentication, payments, subscriptions, or Stripe. Do NOT load for: general UI work, database design, or non-auth features."
description-en: "Implements authentication and payment features using Clerk, Supabase Auth, or Stripe. Use when user mentions login, authentication, payments, subscriptions, or Stripe. Do NOT load for: general UI work, database design, or non-auth features."
description-zh: "认证和支付功能实现。支持 Clerk、Supabase Auth、Stripe。触发短语：登录、认证、支付、订阅、Stripe。不用于：通用 UI 工作、数据库设计、非认证功能。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
user-invocable: false
---

# Auth 技能

负责认证和支付功能实现的技能群。

## 功能详情

| 功能 | 详情 |
|------|------|
| **认证功能** | 见 [references/authentication.md](${CLAUDE_SKILL_DIR}/references/authentication.md) |
| **支付功能** | 见 [references/payments.md](${CLAUDE_SKILL_DIR}/references/payments.md) |

## 执行步骤

1. **质量判定门禁**（Step 0）
2. 分类用户请求（认证 or 支付）
3. 从上述"功能详情"读取适当的参考文件
4. 按其内容实现

### Step 0: 质量判定门禁（安全检查清单）

认证和支付功能始终有高安全风险，因此在开始工作前必须显示以下内容：

```markdown
🔐 安全检查清单

此工作在安全上很重要。请确认以下内容：

### 认证相关
- [ ] 密码已哈希化（bcrypt/argon2）
- [ ] 会话管理是否安全（HTTPOnly Cookie）
- [ ] CSRF 防护是否已实现
- [ ] 速率限制（暴力破解防护）

### 支付相关
- [ ] 敏感信息（卡号等）不保存到服务器
- [ ] 正确使用 Stripe/支付提供商的 SDK
- [ ] Webhook 签名验证
- [ ] 金额篡改防护（服务器端确定金额）

### 通用
- [ ] 错误消息不过于详细（防止信息泄露）
- [ ] 日志中不输出敏感信息
```

### 安全重要度显示

```markdown
⚠️ 注意级别: 🔴 高

此功能存在以下风险：
- 认证信息泄露
- 未授权访问
- 支付非法操作

建议由专家进行审查。
```

### 面向 VibeCoder

```markdown
🔐 安全地创建登录和支付功能

1. **密码要"哈希化"**
   - 以无法恢复原始密码的形式保存
   - 即使数据泄露也安全

2. **卡信息不保存到服务器**
   - 交给 Stripe 等专业服务
   - 自己的服务器完全不保存

3. **错误消息要模糊**
   - 不是"密码错误"而是"认证失败"
   - 不给恶意者提示
```
