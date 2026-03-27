---
name: gogcli-ops
description: "用 gogcli 操作 Google Workspace（Drive/Sheets/Docs/Slides）。用户通过 gogcli 请求查看、搜索、导出、读取、更新 Google 文件时使用。Trigger when a user asks to check, list, search, export, read, or update Google files via gogcli; when a Google URL/ID needs parsing; when auth/account selection or safe read-only workflows are needed; or when troubleshooting gogcli access/errors. Do NOT load for: general file operations, non-Google cloud storage, or standard shell commands."
description-en: "Use gogcli for Google Workspace CLI operations (Drive/Sheets/Docs/Slides). Trigger when a user asks to check, list, search, export, read, or update Google files via gogcli; when a Google URL/ID needs parsing; when auth/account selection or safe read-only workflows are needed; or when troubleshooting gogcli access/errors. Do NOT load for: general file operations, non-Google cloud storage, or standard shell commands."
description-zh: "用 gogcli 操作 Google Workspace（Drive/Sheets/Docs/Slides）。用户通过 gogcli 请求查看、搜索、导出、读取、更新 Google 文件时使用。触发短语：查看 Google 文件、搜索、导出、读取、更新。不用于：通用文件操作、非 Google 云存储、标准 shell 命令。"
allowed-tools: ["Read", "Bash", "Grep", "Glob"]
---

# Gogcli Ops

## 概述
标准化 gogcli 使用：验证认证、从 URL 解析 ID、默认只读检查、然后运行所需的最小命令。

## 快速开始
- 确认 gogcli 可用: `gog --version`
- 如有多个账户，列出并明确选择一个: `gog auth list`
- 用 `python3 scripts/gog_parse_url.py "<url-or-id>"` 将 URL 解析为 ID
- 首先运行只读元数据命令（Drive/Sheets/Docs/Slides）

## 工作流决策树
1. 通过 `scripts/gog_parse_url.py` 识别目标类型: `sheet | doc | slide | file | folder | id | unknown`
2. 选择最小的只读命令确认访问:
   - Sheets: `gog sheets metadata <spreadsheetId>`
   - Docs: `gog docs info <docId>`
   - Slides: `gog slides info <presentationId>`
   - Drive 文件/文件夹: `gog drive get <fileId>` 或 `gog drive permissions <fileId>`
3. 仅在用户明确确认后进行写操作（update/append/move/share/delete）

## 核心任务

### 认证和账户选择
- 显示存储的账户: `gog auth list`
- 显示认证配置: `gog auth status`
- 添加/授权账户: `gog auth add <email>`
- 存在多个账户时始终使用 `--account <email>`

### 从 URL 解析 ID
- 解析 URL 或 ID:
  - `python3 scripts/gog_parse_url.py "<url-or-id>"`
- 如果输出类型是 `unknown`，请求直接 ID 或其他 URL

### Drive（文件/文件夹）
- 列出根目录或文件夹: `gog drive ls`
- 按查询搜索: `gog drive search "<query>"`
- 获取元数据: `gog drive get <fileId>`
- 下载/导出: `gog drive download <fileId>`
- 权限检查: `gog drive permissions <fileId>`

### Sheets
- 元数据: `gog sheets metadata <spreadsheetId>`
- 读取值: `gog sheets get <spreadsheetId> <range>`
- 导出: `gog sheets export <spreadsheetId>`
- 写操作（update/append/clear/format）: 需要明确确认和精确范围

### Docs
- 元数据: `gog docs info <docId>`
- 读取文本: `gog docs cat <docId>`
- 导出: `gog docs export <docId>`

### Slides
- 元数据: `gog slides info <presentationId>`
- 导出: `gog slides export <presentationId>`

### 输出模式
- 使用 `--plain` 获得稳定的 TSV 输出
- 使用 `--json` 当调用者需要结构化输出
- 在非交互流程中使用 `--no-input` 避免挂起

## 错误处理
- 403/404: 验证账户（`gog auth list`）、检查权限（`gog drive permissions <fileId>`）、确认 ID
- 如果访问失败，请求用户将文件分享给所选账户或提供正确的账户

## 资源
- 紧凑命令列表见 `${CLAUDE_SKILL_DIR}/references/gogcli-cheatsheet.md`
- 运行命令前使用 `scripts/gog_parse_url.py` 将 URL 规范化为 ID
