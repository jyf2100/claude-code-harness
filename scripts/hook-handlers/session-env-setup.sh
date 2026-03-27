#!/bin/bash
# session-env-setup.sh
# SessionStart 钩子处理器: 利用 CLAUDE_ENV_FILE 设置 harness 环境变量
#
# 会话开始时将以下环境变量写入 CLAUDE_ENV_FILE:
#   HARNESS_VERSION          - harness 版本 (从 VERSION 文件获取)
#   HARNESS_EFFORT_DEFAULT   - 默认 effort 级别 (medium)
#   HARNESS_AGENT_TYPE       - agent 类型 (BREEZING_ROLE 或 "solo")
#   HARNESS_BREEZING_SESSION_ID - Breezing 会话 ID (如果存在)
#   HARNESS_IS_REMOTE           - 云会话检测 (从 CLAUDE_CODE_REMOTE 获取)
#
# Usage: bash session-env-setup.sh
# Hook event: SessionStart

set -euo pipefail

# === 配置 ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# 如果 CLAUDE_ENV_FILE 未设置则不做任何操作
if [ -z "${CLAUDE_ENV_FILE:-}" ]; then
  exit 0
fi

# 从 VERSION 文件获取版本
HARNESS_VERSION="unknown"
if [ -f "${PLUGIN_ROOT}/VERSION" ]; then
  HARNESS_VERSION="$(cat "${PLUGIN_ROOT}/VERSION" | tr -d '[:space:]')"
fi

# 确定 agent 类型
HARNESS_AGENT_TYPE="${BREEZING_ROLE:-solo}"

# Breezing 会话 ID (如果存在)
HARNESS_BREEZING_SESSION_ID="${BREEZING_SESSION_ID:-}"

# 云会话检测
HARNESS_IS_REMOTE="${CLAUDE_CODE_REMOTE:-false}"

# 写入 CLAUDE_ENV_FILE (覆盖现有 harness 变量)
{
  echo "HARNESS_VERSION=${HARNESS_VERSION}"
  echo "HARNESS_EFFORT_DEFAULT=medium"
  echo "HARNESS_AGENT_TYPE=${HARNESS_AGENT_TYPE}"
  echo "HARNESS_IS_REMOTE=${HARNESS_IS_REMOTE}"
  if [ -n "${HARNESS_BREEZING_SESSION_ID}" ]; then
    echo "HARNESS_BREEZING_SESSION_ID=${HARNESS_BREEZING_SESSION_ID}"
  fi
} >> "${CLAUDE_ENV_FILE}"

exit 0
