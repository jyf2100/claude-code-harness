#!/bin/bash
# breezing-signal-injector.sh
# 在 UserPromptSubmit 钩子中从 breezing-signals.jsonl 读取未消费信号，
# 作为 systemMessage 注入。
#
# Usage: 自动调用（UserPromptSubmit hook）
# Input: stdin JSON from Claude Code hooks (UserPromptSubmit)
# Output: JSON with optional systemMessage

set +e  # 不在错误时停止

# === 检测项目根目录 ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
if [ -f "${PARENT_DIR}/path-utils.sh" ]; then
  source "${PARENT_DIR}/path-utils.sh" 2>/dev/null || true
fi
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${PARENT_DIR}/.." && pwd)}"
STATE_DIR="${PROJECT_ROOT}/.claude/state"

# === 检查 breezing 会话是否存在 ===
ACTIVE_FILE="${STATE_DIR}/breezing-active.json"
if [ ! -f "${ACTIVE_FILE}" ]; then
  # breezing 会话外则跳过
  exit 0
fi

# === 检查信号文件是否存在 ===
SIGNALS_FILE="${STATE_DIR}/breezing-signals.jsonl"
if [ ! -f "${SIGNALS_FILE}" ]; then
  exit 0
fi

# === 读取未消费信号 ===
# consumed_at 为 null 或不存在的行被视为未消费
UNCONSUMED_SIGNALS=""
if command -v jq >/dev/null 2>&1; then
  # 使用 jq 提取 consumed_at 为 null 的信号
  UNCONSUMED_SIGNALS="$(grep -v '^$' "${SIGNALS_FILE}" 2>/dev/null | \
    while IFS= read -r line; do
      consumed="$(printf '%s' "${line}" | jq -r '.consumed_at // "null"' 2>/dev/null)"
      if [ "${consumed}" = "null" ]; then
        printf '%s\n' "${line}"
      fi
    done)" || UNCONSUMED_SIGNALS=""
elif command -v python3 >/dev/null 2>&1; then
  UNCONSUMED_SIGNALS="$(python3 -c "
import json, sys
lines = []
try:
    with open('${SIGNALS_FILE}', 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
                if d.get('consumed_at') is None:
                    lines.append(line)
            except:
                pass
print('\n'.join(lines))
" 2>/dev/null)" || UNCONSUMED_SIGNALS=""
fi

if [ -z "${UNCONSUMED_SIGNALS}" ]; then
  # 没有未消费信号
  exit 0
fi

# === 将信号格式化为消息形式 ===
SYSTEM_MESSAGE=""
SIGNAL_COUNT=0

while IFS= read -r signal_line; do
  [ -z "${signal_line}" ] && continue

  SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
  signal_type=""
  signal_ts=""

  if command -v jq >/dev/null 2>&1; then
    signal_type="$(printf '%s' "${signal_line}" | jq -r '.signal // .type // "unknown"' 2>/dev/null)" || signal_type="unknown"
    signal_ts="$(printf '%s' "${signal_line}" | jq -r '.timestamp // ""' 2>/dev/null)" || signal_ts=""
  fi

  case "${signal_type}" in
    ci_failure_detected)
      conclusion=""
      trigger_cmd=""
      if command -v jq >/dev/null 2>&1; then
        conclusion="$(printf '%s' "${signal_line}" | jq -r '.conclusion // "unknown"' 2>/dev/null)"
        trigger_cmd="$(printf '%s' "${signal_line}" | jq -r '.trigger_command // ""' 2>/dev/null)"
      fi
      SYSTEM_MESSAGE="${SYSTEM_MESSAGE}[SIGNAL:ci_failure_detected] CI 失败（${conclusion}）。触发器: ${trigger_cmd}。请考虑使用 ci-cd-fixer 代理自动修复。\n"
      ;;
    retake_requested)
      reason=""
      task_id=""
      if command -v jq >/dev/null 2>&1; then
        reason="$(printf '%s' "${signal_line}" | jq -r '.reason // ""' 2>/dev/null)"
        task_id="$(printf '%s' "${signal_line}" | jq -r '.task_id // ""' 2>/dev/null)"
      fi
      SYSTEM_MESSAGE="${SYSTEM_MESSAGE}[SIGNAL:retake_requested] 任务 #${task_id} 被要求重做。理由: ${reason}\n"
      ;;
    reviewer_approved)
      task_id=""
      if command -v jq >/dev/null 2>&1; then
        task_id="$(printf '%s' "${signal_line}" | jq -r '.task_id // ""' 2>/dev/null)"
      fi
      SYSTEM_MESSAGE="${SYSTEM_MESSAGE}[SIGNAL:reviewer_approved] 任务 #${task_id} 已被审核员批准。\n"
      ;;
    escalation_required)
      reason=""
      task_id=""
      if command -v jq >/dev/null 2>&1; then
        reason="$(printf '%s' "${signal_line}" | jq -r '.reason // ""' 2>/dev/null)"
        task_id="$(printf '%s' "${signal_line}" | jq -r '.task_id // ""' 2>/dev/null)"
      fi
      SYSTEM_MESSAGE="${SYSTEM_MESSAGE}[SIGNAL:escalation_required] 任务 #${task_id} 需要升级处理。理由: ${reason}\n"
      ;;
    *)
      # 未知信号直接通知
      SYSTEM_MESSAGE="${SYSTEM_MESSAGE}[SIGNAL:${signal_type}] ${signal_line}\n"
      ;;
  esac
done <<< "${UNCONSUMED_SIGNALS}"

if [ -z "${SYSTEM_MESSAGE}" ] || [ "${SIGNAL_COUNT}" -eq 0 ]; then
  exit 0
fi

# === 设置 consumed_at 以标记信号为已消费 ===
# 原子更新: 在新文件中附加 consumed_at 并覆盖
CONSUMED_TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
LOCK_DIR="${STATE_DIR}/.breezing-signals.lock"

_lock_acquired=0
for _i in $(seq 1 20); do
  if mkdir "${LOCK_DIR}" 2>/dev/null; then
    _lock_acquired=1
    break
  fi
  sleep 0.1
done

if [ "${_lock_acquired}" -eq 1 ]; then
  TMP_NEW_SIGNALS="$(mktemp /tmp/breezing-signals-new.XXXXXX)"

  if command -v jq >/dev/null 2>&1; then
    # 附加 consumed_at 并重写所有信号
    while IFS= read -r line; do
      [ -z "${line}" ] && continue
      consumed="$(printf '%s' "${line}" | jq -r '.consumed_at // "null"' 2>/dev/null)"
      if [ "${consumed}" = "null" ]; then
        printf '%s' "${line}" | jq -c --arg ts "${CONSUMED_TS}" '. + {consumed_at: $ts}' 2>/dev/null >> "${TMP_NEW_SIGNALS}" || printf '%s\n' "${line}" >> "${TMP_NEW_SIGNALS}"
      else
        printf '%s\n' "${line}" >> "${TMP_NEW_SIGNALS}"
      fi
    done < "${SIGNALS_FILE}"

    mv "${TMP_NEW_SIGNALS}" "${SIGNALS_FILE}" 2>/dev/null || rm -f "${TMP_NEW_SIGNALS}"
  else
    rm -f "${TMP_NEW_SIGNALS}"
  fi

  rmdir "${LOCK_DIR}" 2>/dev/null || true
fi

# === 作为 systemMessage 输出 ===
HEADER="[breezing-signal-injector] 有 ${SIGNAL_COUNT} 个未消费信号:\n"
FULL_MESSAGE="${HEADER}${SYSTEM_MESSAGE}"

if command -v jq >/dev/null 2>&1; then
  jq -nc --arg msg "${FULL_MESSAGE}" '{"systemMessage": $msg}'
else
  # 如果没有 jq 则使用简易转义
  _escaped="${FULL_MESSAGE//\\/\\\\}"
  _escaped="${_escaped//\"/\\\"}"
  printf '{"systemMessage":"%s"}\n' "${_escaped}"
fi

exit 0
