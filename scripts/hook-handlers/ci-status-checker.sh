#!/bin/bash
# ci-status-checker.sh
# PostToolUse (Bash matcher) 异步检查 git push / gh pr 后的 CI 状态
# CI 失败检测时通过 additionalContext 注入推荐 spawn ci-cd-fixer 的消息
#
# Input: stdin JSON from Claude Code hooks (PostToolUse/Bash)
# Output: JSON to approve the event (with optional additionalContext)

set +e  # 出错时不停止

# === 从 stdin 读取 JSON 载荷 ===
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

# 载荷为空时跳过
if [ -z "${INPUT}" ]; then
  echo '{"decision":"approve","reason":"ci-status-checker: no payload"}'
  exit 0
fi

# === 从 Bash 工具输出获取命令和退出码 ===
TOOL_NAME=""
BASH_CMD=""
BASH_EXIT_CODE=""
BASH_OUTPUT=""

if command -v jq >/dev/null 2>&1; then
  _parsed="$(printf '%s' "${INPUT}" | jq -r '[
    (.tool_name // ""),
    (.tool_input.command // ""),
    ((.tool_response.exit_code // .tool_response.exitCode // -1) | tostring),
    ((.tool_response.output // .tool_response.stdout // "") | .[0:500])
  ] | @tsv' 2>/dev/null)"
  if [ -n "${_parsed}" ]; then
    IFS=$'\t' read -r TOOL_NAME BASH_CMD BASH_EXIT_CODE BASH_OUTPUT <<< "${_parsed}"
  fi
elif command -v python3 >/dev/null 2>&1; then
  _parsed="$(printf '%s' "${INPUT}" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    tr = d.get('tool_response', {})
    ti = d.get('tool_input', {})
    print(d.get('tool_name', ''))
    print(ti.get('command', ''))
    print(str(tr.get('exit_code', tr.get('exitCode', -1))))
    out = tr.get('output', tr.get('stdout', ''))
    print(str(out)[:500])
except:
    print('')
    print('')
    print('-1')
    print('')
" 2>/dev/null)"
  TOOL_NAME="$(echo "${_parsed}" | sed -n '1p')"
  BASH_CMD="$(echo "${_parsed}" | sed -n '2p')"
  BASH_EXIT_CODE="$(echo "${_parsed}" | sed -n '3p')"
  BASH_OUTPUT="$(echo "${_parsed}" | sed -n '4p')"
fi

# === 判断是否为 git push / gh pr 命令 ===
is_push_or_pr_command() {
  local cmd="$1"
  # 检测 git push / gh pr create / gh pr merge / gh workflow run 等命令
  if echo "${cmd}" | grep -Eq '(^|[[:space:]])(git\s+push|gh\s+pr\s+(create|merge|edit)|gh\s+workflow\s+run)'; then
    return 0
  fi
  return 1
}

if ! is_push_or_pr_command "${BASH_CMD}"; then
  echo '{"decision":"approve","reason":"ci-status-checker: not a push/PR command"}'
  exit 0
fi

# === 检测项目根目录 ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
if [ -f "${PARENT_DIR}/path-utils.sh" ]; then
  source "${PARENT_DIR}/path-utils.sh" 2>/dev/null || true
fi
PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || pwd)}"
STATE_DIR="${PROJECT_ROOT}/.claude/state"
mkdir -p "${STATE_DIR}" 2>/dev/null || true

# === 异步确认 CI 状态（后台任务）===
# CI 检查最多轮询 60 秒（仅在 gh 命令存在时执行）
CI_STATUS_FILE="${STATE_DIR}/ci-status.json"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

check_ci_status_async() {
  if ! command -v gh >/dev/null 2>&1; then
    return
  fi

  local max_wait=60
  local poll_interval=10
  local elapsed=0
  local status="unknown"
  local conclusion="unknown"

  while [ "${elapsed}" -lt "${max_wait}" ]; do
    sleep "${poll_interval}"
    elapsed=$(( elapsed + poll_interval ))

    # 获取最新的 PR 检查
    local runs_json
    runs_json="$(gh run list --limit 1 --json status,conclusion,name,url 2>/dev/null)" || runs_json=""
    if [ -z "${runs_json}" ]; then
      continue
    fi

    if command -v jq >/dev/null 2>&1; then
      status="$(printf '%s' "${runs_json}" | jq -r '.[0].status // "unknown"' 2>/dev/null)" || status="unknown"
      conclusion="$(printf '%s' "${runs_json}" | jq -r '.[0].conclusion // "unknown"' 2>/dev/null)" || conclusion="unknown"
    fi

    # 非 completed 状态表示仍在执行中
    if [ "${status}" != "completed" ]; then
      continue
    fi

    # 记录结果
    if command -v jq >/dev/null 2>&1; then
      jq -n \
        --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg trigger_cmd "${BASH_CMD}" \
        --arg status "${status}" \
        --arg conclusion "${conclusion}" \
        '{timestamp:$ts, trigger_command:$trigger_cmd, status:$status, conclusion:$conclusion}' \
        > "${CI_STATUS_FILE}" 2>/dev/null || true
    fi

    # CI 失败时写入信号文件
    if [ "${conclusion}" = "failure" ] || [ "${conclusion}" = "timed_out" ] || [ "${conclusion}" = "cancelled" ]; then
      SIGNALS_FILE="${STATE_DIR}/breezing-signals.jsonl"
      if command -v jq >/dev/null 2>&1; then
        jq -nc \
          --arg signal "ci_failure_detected" \
          --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
          --arg conclusion "${conclusion}" \
          --arg trigger_cmd "${BASH_CMD}" \
          '{signal:$signal, timestamp:$timestamp, conclusion:$conclusion, trigger_command:$trigger_cmd}' \
          >> "${SIGNALS_FILE}" 2>/dev/null || true
      fi
    fi

    return
  done
}

# 在后台执行 CI 检查（不阻塞钩子）
check_ci_status_async &
disown 2>/dev/null || true

# === 检查最近的 CI 失败信号并注入 additionalContext ===
ADDITIONAL_CONTEXT=""
SIGNALS_FILE="${STATE_DIR}/breezing-signals.jsonl"

if [ -f "${SIGNALS_FILE}" ]; then
  # 获取最近一条 ci_failure_detected 信号（10 分钟以内的）
  _recent_failure=""
  if command -v jq >/dev/null 2>&1; then
    _recent_failure="$(grep '"ci_failure_detected"' "${SIGNALS_FILE}" 2>/dev/null | tail -1)" || _recent_failure=""
  fi

  if [ -n "${_recent_failure}" ]; then
    _failure_conclusion=""
    if command -v jq >/dev/null 2>&1; then
      _failure_conclusion="$(printf '%s' "${_recent_failure}" | jq -r '.conclusion // ""' 2>/dev/null)" || _failure_conclusion=""
    fi

    ADDITIONAL_CONTEXT="[检测到 CI 失败]\nCI 状态: ${_failure_conclusion}\n触发命令: ${BASH_CMD}\n\n推荐操作: spawn /breezing 或 ci-cd-fixer agent 来自动修复 CI 故障。\n  示例: 请求 ci-cd-fixer \"CI 失败了，请检查日志并修复。\""
  fi
fi

# === 响应 ===
if [ -n "${ADDITIONAL_CONTEXT}" ]; then
  if command -v jq >/dev/null 2>&1; then
    jq -nc \
      --arg reason "ci-status-checker: push/PR detected, CI failure context injected" \
      --arg ctx "${ADDITIONAL_CONTEXT}" \
      '{"decision":"approve","reason":$reason,"additionalContext":$ctx}'
  else
    echo '{"decision":"approve","reason":"ci-status-checker: push/PR detected, CI failure context injected"}'
  fi
else
  echo '{"decision":"approve","reason":"ci-status-checker: push/PR detected, CI monitoring started"}'
fi
exit 0
