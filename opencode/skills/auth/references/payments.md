---
name: payments
description: "支付功能实现（Stripe）。想要添加订阅或一次性支付时使用。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
---

# Payments Skill

使用 Stripe 实现支付功能的技能。

---

## 触发短语

- "想添加支付"
- "引入 Stripe"
- "实现订阅"
- "添加一次性支付"

---

## 功能

- 订阅（月付/年付）
- 一次性支付
- Webhook（支付完成通知）
- 客户门户（计划变更、取消）

---

## 执行流程

1. 确认项目配置
2. 选择订阅或一次性支付
3. 安装 Stripe SDK
4. 创建支付页面
5. 设置 Webhook 端点
6. 指导环境变量设置
