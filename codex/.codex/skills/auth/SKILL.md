---
name: auth
description: "实现认证和支付功能。支持 Clerk、Supabase Auth、Stripe。Use when user mentions login, authentication, payments, subscriptions, or Stripe. Do NOT load for: general UI work, database design, or non-auth features."
description-en: "Implements authentication and payment features using Clerk, Supabase Auth, or Stripe. Use when user mentions login, authentication, payments, subscriptions, or Stripe. Do NOT load for: general UI work, database design, or non-auth features."
description-ja: "認証と決済機能を実装。Clerk、Supabase Auth、Stripeに対応。Use when user mentions login, authentication, payments, subscriptions, or Stripe. Do NOT load for: general UI work, database design, or non-auth features."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
user-invocable: false
---

# Auth Skills

负责实现认证和支付功能的技能群。

## 功能详情

| 功能 | 详情 |
|------|------|
| **认证功能** | See [references/authentication.md](${CLAUDE_SKILL_DIR}/references/authentication.md) |
| **支付功能** | See [references/payments.md](${CLAUDE_SKILL_DIR}/references/payments.md) |

## 执行步骤

1. **质量判定关卡**（Step 0）
2. 分类用户请求（认证或支付）
3. 从上述"功能详情"读取适当的参考文件
4. 按照其内容实现

### Step 0: 质量判定关卡（安全检查清单）

认证和支付功能始终存在较高的安全风险，因此开始工作前必须显示以下内容：

```markdown
🔐 安全检查清单

此工作在安全上很重要。请确认以下内容：

### 认证相关
- [ ] 密码已哈希化（bcrypt/argon2）
- [ ] 会话管理是否安全（HTTPOnly Cookie）
- [ ] 是否实现了 CSRF 防护
- [ ] 速率限制（暴力破解防护）

### 支付相关
- [ ] 不在服务器保存敏感信息（卡号等）
- [ ] 正确使用 Stripe/支付提供商的 SDK
- [ ] Webhook 签名验证
- [ ] 防止金额篡改（在服务器端确定金额）

### 共同
- [ ] 错误消息是否过于详细（防止信息泄露）
- [ ] 是否在日志中输出了敏感信息
```

### 安全重要度显示

```markdown
⚠️ 注意级别: 🔴 高

此功能存在以下风险：
- 认证信息泄露
- 未授权访问
- 支付操作异常

建议由专家进行审查。
```

### VibeCoder 专用

```markdown
🔐 安全地创建登录和支付功能

1. **密码需要"哈希化"**
   - 以无法还原原始密码的形式保存
   - 即使数据泄露也安全

2. **不在服务器保存卡信息**
   - 交给 Stripe 等专业服务
   - 绝不保存在自己的服务器上

3. **错误消息要模糊**
   - 不是"密码错误"而是"认证失败"
   - 不给恶意者提示
```
