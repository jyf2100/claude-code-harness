#!/bin/bash
# codex-exec-wrapper.sh
# codex exec 前处理（规则注入）与后处理（结果记录、标记提取）的自动化包装器
#
# Usage: ./scripts/codex/codex-exec-wrapper.sh <prompt_file> [timeout_seconds]
#   prompt_file      : 传递给 codex exec 的提示文件路径
#   timeout_seconds  : 超时秒数（默认: 120）
#
# 环境变量:
#   HARNESS_CODEX_NO_SYNC : 设为 1 时跳过 sync-rules-to-agents.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
EXECUTION_ROOT="${HARNESS_CODEX_EXECUTION_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CONTRACT_TEMPLATE="${SCRIPT_DIR}/../lib/codex-hardening-contract.txt"
HARDENING_MARKER="HARNESS_HARDENING_CONTRACT_V1"

PROMPT_FILE="${1:-}"
TIMEOUT_SEC="${2:-120}"

# === 参数检查 ===
if [ -z "${PROMPT_FILE}" ]; then
  echo "Usage: $0 <prompt_file> [timeout_seconds]" >&2
  exit 1
fi

if [ ! -f "${PROMPT_FILE}" ]; then
  echo "Error: prompt file not found: ${PROMPT_FILE}" >&2
  exit 1
fi

# === timeout 命令检测（macOS 兼容）===
TIMEOUT=$(command -v timeout || command -v gtimeout || echo "")

# === 前处理: 确认 AGENTS.md 为最新 ===
SYNC_SCRIPT="${SCRIPT_DIR}/sync-rules-to-agents.sh"
if [ "${HARNESS_CODEX_NO_SYNC:-}" != "1" ] && [ -f "${SYNC_SCRIPT}" ]; then
  echo "[codex-exec-wrapper] 正在执行 sync-rules-to-agents.sh..." >&2
  bash "${SYNC_SCRIPT}" >&2 || {
    echo "[codex-exec-wrapper] Warning: sync-rules-to-agents.sh 执行失败（继续执行）" >&2
  }
fi

# === Hardening contract ===
generate_hardening_contract() {
  if [ ! -f "${CONTRACT_TEMPLATE}" ]; then
    echo "[codex-exec-wrapper] Error: hardening contract template not found: ${CONTRACT_TEMPLATE}" >&2
    exit 1
  fi
  cat "${CONTRACT_TEMPLATE}"
}

# Generate the injected contract once so the prompt, base instructions, and state artifact stay aligned.
build_hardening_contract_artifact() {
  local output_dir="$1"
  mkdir -p "$output_dir"
  generate_hardening_contract > "$output_dir/hardening-contract.txt"
}

prepend_hardening_contract_if_missing() {
  local file_path="$1"
  local tmp_file=""
  if [ ! -f "${file_path}" ]; then
    return 0
  fi
  if grep -Fq "${HARDENING_MARKER}" "${file_path}" 2>/dev/null; then
    return 0
  fi
  tmp_file="$(mktemp /tmp/codex-contract-sync.XXXXXX)"
  {
    generate_hardening_contract
    printf '\n---\n\n'
    cat "${file_path}"
  } > "${tmp_file}"
  mv "${tmp_file}" "${file_path}"
}

# === 创建已注入提示 ===
CODEX_STATE_DIR="${HARNESS_CODEX_STATE_DIR:-${EXECUTION_ROOT}/.claude/state/codex-worker}"
TMP_PROMPT="$(mktemp /tmp/codex-exec-prompt.XXXXXX)"
build_hardening_contract_artifact "$CODEX_STATE_DIR"
prepend_hardening_contract_if_missing "${CODEX_STATE_DIR}/base-instructions.txt"
prepend_hardening_contract_if_missing "${CODEX_STATE_DIR}/prompt.txt"
if grep -Fq "${HARDENING_MARKER}" "${PROMPT_FILE}" 2>/dev/null; then
  cp "${PROMPT_FILE}" "${TMP_PROMPT}"
else
  {
    generate_hardening_contract
    printf '\n---\n\n'
    cat "${PROMPT_FILE}"
  } > "${TMP_PROMPT}"
fi

# === 准备临时文件 ===
TMP_OUT="$(mktemp /tmp/codex-exec-out.XXXXXX)"
TMP_LEARNING="$(mktemp /tmp/codex-learning.XXXXXX)"
trap 'rm -f "${TMP_OUT}" "${TMP_LEARNING}" "${TMP_PROMPT}"' EXIT

# === 主体: 执行 codex exec ===
echo "[codex-exec-wrapper] 正在执行 codex exec（timeout=${TIMEOUT_SEC}s）..." >&2

EXIT_CODE=0
# 通过 stdin 传递提示（避免超过 ARG_MAX）
# "-" 是 codex exec 的官方 stdin 输入指定
if [ -n "${TIMEOUT}" ]; then
  cat "${TMP_PROMPT}" | ${TIMEOUT} "${TIMEOUT_SEC}" codex exec - --full-auto > "${TMP_OUT}" 2>>/tmp/harness-codex-$$.log || EXIT_CODE=$?
else
  cat "${TMP_PROMPT}" | codex exec - --full-auto > "${TMP_OUT}" 2>>/tmp/harness-codex-$$.log || EXIT_CODE=$?
fi

# 超时（exit 124）时也输出日志
if [ "${EXIT_CODE}" -eq 124 ]; then
  echo "[codex-exec-wrapper] Warning: codex exec 超时（${TIMEOUT_SEC}s）" >&2
fi

# === 后处理: 提取 [HARNESS-LEARNING] 标记行 ===
# NOTE: Codex CLI 的 --output-schema 选项可输出结构化 JSON。
# 从标记 grep 方式迁移到 --output-schema 方式将在未来考虑（需要定义 schema）。
# 从 stdout 中仅提取以 `[HARNESS-LEARNING]` 开头的行并移除标记
LEARNING_COUNT=0
if grep -q '^\[HARNESS-LEARNING\]' "${TMP_OUT}" 2>/dev/null; then
  grep '^\[HARNESS-LEARNING\]' "${TMP_OUT}" | sed 's/^\[HARNESS-LEARNING\] *//' > "${TMP_LEARNING}"
  LEARNING_COUNT="$(wc -l < "${TMP_LEARNING}" | tr -d ' ')"
  echo "[codex-exec-wrapper] 检测到 ${LEARNING_COUNT} 条学习标记" >&2

  # === 密钥过滤器 ===
  # 移除包含 token/key/password/secret/credential/api_key 的行（忽略大小写）
  TMP_FILTERED="$(mktemp /tmp/codex-filtered.XXXXXX)"
  trap 'rm -f "${TMP_OUT}" "${TMP_LEARNING}" "${TMP_FILTERED}"' EXIT
  grep -viE '(token|key|password|secret|credential|api_key)' "${TMP_LEARNING}" > "${TMP_FILTERED}" 2>/dev/null || true
  FILTERED_COUNT="$(wc -l < "${TMP_FILTERED}" | tr -d ' ')"
  REMOVED=$((LEARNING_COUNT - FILTERED_COUNT))
  if [ "${REMOVED}" -gt 0 ]; then
    echo "[codex-exec-wrapper] Warning: 移除了 ${REMOVED} 行疑似密钥内容" >&2
  fi

  # === 原子追加到 codex-learnings.md（mkdir 锁方式，兼容 macOS）===
  MEMORY_DIR="${HARNESS_CODEX_MEMORY_DIR:-${EXECUTION_ROOT}/.claude/memory}"
  mkdir -p "${MEMORY_DIR}"
  LEARNINGS_FILE="${MEMORY_DIR}/codex-learnings.md"
  LOCK_DIR="${MEMORY_DIR}/.codex-learnings.lock"
  TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  DATE_ONLY="$(date -u +"%Y-%m-%d")"
  PROMPT_BASENAME="$(basename "${PROMPT_FILE}")"

  # 获取锁（最多等待 10 秒）
  _lock_acquired=0
  for _i in $(seq 1 20); do
    if mkdir "${LOCK_DIR}" 2>/dev/null; then
      _lock_acquired=1
      break
    fi
    sleep 0.5
  done

  if [ "${_lock_acquired}" -eq 1 ]; then
    # 文件不存在时创建标题
    if [ ! -f "${LEARNINGS_FILE}" ]; then
      printf '# codex-learnings.md\n\n从 codex exec 提取的学习内容记录。\n\n' > "${LEARNINGS_FILE}"
    fi

    # 添加章节标题后追加
    if [ "${FILTERED_COUNT}" -gt 0 ]; then
      {
        printf '\n## %s %s\n\n' "${DATE_ONLY}" "${PROMPT_BASENAME}"
        while IFS= read -r line; do
          printf '- %s\n' "${line}"
        done < "${TMP_FILTERED}"
      } >> "${LEARNINGS_FILE}" 2>/dev/null || true
    fi

    # 释放锁
    rmdir "${LOCK_DIR}" 2>/dev/null || true
  else
    echo "[codex-exec-wrapper] Warning: 获取锁超时，跳过追加到 codex-learnings.md" >&2
  fi

  # 学习内容同时保存为 JSONL 到 state 目录（保持兼容）
  STATE_DIR="${HARNESS_CODEX_GENERAL_STATE_DIR:-${EXECUTION_ROOT}/.claude/state}"
  mkdir -p "${STATE_DIR}"
  LEARNING_FILE="${STATE_DIR}/codex-learning.jsonl"

  while IFS= read -r line; do
    if command -v jq >/dev/null 2>&1; then
      jq -nc \
        --arg ts "${TS}" \
        --arg prompt_file "${PROMPT_FILE}" \
        --arg content "${line}" \
        '{timestamp:$ts, prompt_file:$prompt_file, content:$content}' \
        >> "${LEARNING_FILE}" 2>/dev/null || true
    else
      printf '{"timestamp":"%s","prompt_file":"%s","content":"%s"}\n' \
        "${TS}" "${PROMPT_FILE}" "${line//\"/\\\"}" \
        >> "${LEARNING_FILE}" 2>/dev/null || true
    fi
  done < "${TMP_FILTERED}"
fi

# === 透传 stdout ===
cat "${TMP_OUT}"

# === 传递 exit code ===
exit "${EXIT_CODE}"
