#!/bin/bash
# review-ai-residuals.sh
# 从差分或目标文件中静态检测 AI 实现的残留代码。
#
# Usage:
#   bash scripts/review-ai-residuals.sh --base-ref <git-ref>
#   bash scripts/review-ai-residuals.sh path/to/file.ts path/to/config.sh
#
# Exit:
#   0: 无论是否检测到问题都正常退出（由 review 侧判定 verdict）
#   2: 使用方法错误

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/review-ai-residuals.sh --base-ref <git-ref>
  bash scripts/review-ai-residuals.sh <file> [<file> ...]

Options:
  --base-ref <git-ref>  通过 git diff 自动收集变更文件
  --help                显示此帮助信息

Output:
  Stable JSON:
  {
    "tool": "review-ai-residuals",
    "scan_mode": "diff|files",
    "base_ref": "HEAD~1" | null,
    "files_scanned": ["src/app.ts"],
    "summary": {
      "verdict": "APPROVE|REQUEST_CHANGES",
      "major": 0,
      "minor": 0,
      "recommendation": 0,
      "total": 0
    },
    "observations": []
  }
EOF
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\t'/\\t}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\n'/\\n}"
  printf '%s' "$value"
}

trim_match_text() {
  local value="$1"
  value="$(printf '%s' "$value" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  if [ "${#value}" -gt 180 ]; then
    printf '%s...' "${value:0:177}"
  else
    printf '%s' "$value"
  fi
}

redact_secret_line() {
  printf '%s' "$1" | sed -E \
    "s/((api[_-]?key|secret|token|password|passwd|client[_-]?secret)[^:=]{0,20}[:=][[:space:]]*['\"]).+(['\"])/\1<redacted>\3/I"
}

should_ignore_path() {
  case "$1" in
    *.md|*.mdx|*.txt|*.rst|*.adoc) return 0 ;;
    docs/*|*/docs/*) return 0 ;;
    examples/*|*/examples/*) return 0 ;;
    tests/fixtures/*|*/tests/fixtures/*) return 0 ;;
    */node_modules/*|node_modules/*) return 0 ;;
    .git/*|*/.git/*) return 0 ;;
  esac
  return 1
}

is_scannable_file() {
  case "$1" in
    *.sh|*.bash|*.zsh|*.js|*.jsx|*.mjs|*.cjs|*.ts|*.tsx|*.py|*.rb|*.php|*.go|*.rs|*.java|*.kt|*.kts|*.swift|*.json|*.yml|*.yaml|*.toml|*.ini|*.cfg|*.conf|*.env)
      return 0
      ;;
  esac
  return 1
}

append_json_string_array() {
  local file="$1"
  local first=1
  printf '['
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [ "$first" -eq 0 ]; then
      printf ','
    fi
    printf '"%s"' "$(json_escape "$line")"
    first=0
  done < "$file"
  printf ']'
}

append_json_object_array() {
  local file="$1"
  local first=1
  printf '['
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [ "$first" -eq 0 ]; then
      printf ','
    fi
    printf '%s' "$line"
    first=0
  done < "$file"
  printf ']'
}

SEARCH_TOOL=""
if command -v rg >/dev/null 2>&1; then
  SEARCH_TOOL="rg"
else
  echo '{"tool":"review-ai-residuals","scan_mode":"files","base_ref":null,"files_scanned":[],"summary":{"verdict":"APPROVE","major":0,"minor":0,"recommendation":0,"total":0},"observations":[],"warning":"rg_not_found"}'
  exit 0
fi

SCAN_MODE="files"
BASE_REF_INPUT=""
POSITIONAL_FILES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --base-ref)
      if [ $# -lt 2 ]; then
        echo "error: --base-ref requires a value" >&2
        usage >&2
        exit 2
      fi
      SCAN_MODE="diff"
      BASE_REF_INPUT="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      POSITIONAL_FILES+=("$1")
      shift
      ;;
  esac
done

if [ "$SCAN_MODE" = "diff" ] && [ ${#POSITIONAL_FILES[@]} -gt 0 ]; then
  echo "error: --base-ref and explicit files cannot be combined" >&2
  usage >&2
  exit 2
fi

if [ "$SCAN_MODE" = "files" ] && [ ${#POSITIONAL_FILES[@]} -eq 0 ]; then
  if [ -n "${BASE_REF:-}" ]; then
    SCAN_MODE="diff"
    BASE_REF_INPUT="${BASE_REF}"
  else
    SCAN_MODE="diff"
    BASE_REF_INPUT="HEAD~1"
  fi
fi

TMP_FILES="$(mktemp)"
TMP_OBS="$(mktemp)"
TMP_DIFF="$(mktemp)"
cleanup() {
  rm -f "$TMP_FILES" "$TMP_OBS" "$TMP_DIFF"
}
trap cleanup EXIT

collect_diff_files() {
  local base_ref="$1"
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 1
  fi
  git diff --name-only --diff-filter=ACMR "$base_ref" -- 2>/dev/null || return 1
}

queue_file_if_scannable() {
  local path="$1"
  path="${path#./}"
  [ -f "$path" ] || return 0
  should_ignore_path "$path" && return 0
  is_scannable_file "$path" || return 0
  printf '%s\n' "$path" >> "$TMP_FILES"
}

if [ "$SCAN_MODE" = "diff" ]; then
  if collect_diff_files "$BASE_REF_INPUT" >"$TMP_DIFF" 2>/dev/null; then
    while IFS= read -r path; do
      queue_file_if_scannable "$path"
    done < "$TMP_DIFF"
  fi
else
  for path in "${POSITIONAL_FILES[@]}"; do
    queue_file_if_scannable "$path"
  done
fi

sort -u "$TMP_FILES" -o "$TMP_FILES"

MAJOR_COUNT=0
MINOR_COUNT=0
RECOMMENDATION_COUNT=0

append_observation() {
  local severity="$1"
  local rule="$2"
  local location="$3"
  local issue="$4"
  local suggestion="$5"
  local match_text="$6"

  case "$severity" in
    major) MAJOR_COUNT=$((MAJOR_COUNT + 1)) ;;
    minor) MINOR_COUNT=$((MINOR_COUNT + 1)) ;;
    recommendation) RECOMMENDATION_COUNT=$((RECOMMENDATION_COUNT + 1)) ;;
  esac

  printf '{"severity":"%s","category":"AI Residuals","rule":"%s","location":"%s","issue":"%s","suggestion":"%s","match":"%s"}\n' \
    "$(json_escape "$severity")" \
    "$(json_escape "$rule")" \
    "$(json_escape "$location")" \
    "$(json_escape "$issue")" \
    "$(json_escape "$suggestion")" \
    "$(json_escape "$match_text")" \
    >> "$TMP_OBS"
}

scan_file() {
  local file="$1"
  while IFS=$'\t' read -r rule severity pattern issue suggestion; do
    [ -n "$rule" ] || continue
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      local line_num line_text location match_text
      line_num="${hit%%:*}"
      line_text="${hit#*:}"
      location="${file}:${line_num}"
      match_text="$(trim_match_text "$line_text")"
      if [ "$rule" = "hardcoded-secret" ]; then
        match_text="$(trim_match_text "$(redact_secret_line "$match_text")")"
      fi
      append_observation "$severity" "$rule" "$location" "$issue" "$suggestion" "$match_text"
    done < <("${SEARCH_TOOL}" --no-config -n -I --pcre2 "$pattern" -- "$file" 2>/dev/null || true)
  done <<'EOF'
test-skip	major	\b(it|describe|test)\.skip\s*\(	被禁用的测试仍然存在。可能会绕过代码审查。	移除 skip，或者如果确实必要，请在注释和 issue 中说明原因。
localhost-reference	major	\b(localhost|127\.0\.0\.1|0\.0\.0\.0)\b	仅限本地的连接目标仍然存在。在生产或共享环境中容易导致配置错误。	请通过环境变量或公共配置注入 URL / host。
hardcoded-secret	major	(?i)\b(api[_-]?key|secret|token|password|passwd|client[_-]?secret)\b[^:=\n]{0,20}[:=][[:space:]]*['"][^'"]{8,}['"]	疑似密钥信息被硬编码。存在泄露和环境固定的双重风险。	请替换为环境变量、密钥存储或安全的配置注入。
hardcoded-env-url	major	https?://(dev|staging|internal|sandbox)[.-][A-Za-z0-9._/-]+	环境依赖的 URL 被固定在代码中。会导致部署目标连接错误。	请拆分为各环境的配置。
mock-data	minor	\bmockData\b	mock 用变量名仍然存在。需要确认是否是临时数据。	请替换为真实数据，或者如果必要，请明确标识为测试专用。
dummy-value	minor	\bdummy[A-Za-z0-9_]*\b	dummy 临时值仍然存在。	请替换为实际值，或改为意图明确的变量名。
fake-data	minor	\bfake(Data)?\b	fake 数据来源的名称仍然存在。	如果是生产代码请替换为实现，如果是测试代码请明确用途。
todo-fixme	minor	\b(TODO|FIXME)\b	未完成的 TODO / FIXME 仍然存在。	请在发布前解决，或在注释中留下追踪链接。
provisional-comment	recommendation	(?i)(temporary implementation|stub implementation|placeholder implementation|replace later|hardcoded for now|wire real service)	临时实现的注释仍然存在。虽然不一定会立即出问题，但明确意图会更安全。	请在注释或 issue 中记录截止日期、追踪链接和永久解决方案的计划。
EOF
}

while IFS= read -r file; do
  [ -n "$file" ] || continue
  scan_file "$file"
done < "$TMP_FILES"

TOTAL_COUNT=$((MAJOR_COUNT + MINOR_COUNT + RECOMMENDATION_COUNT))
VERDICT="APPROVE"
if [ "$MAJOR_COUNT" -gt 0 ]; then
  VERDICT="REQUEST_CHANGES"
fi

if [ -n "$BASE_REF_INPUT" ] && [ "$SCAN_MODE" = "diff" ]; then
  BASE_REF_JSON="\"$(json_escape "$BASE_REF_INPUT")\""
else
  BASE_REF_JSON="null"
fi

printf '{'
printf '"tool":"review-ai-residuals",'
printf '"scan_mode":"%s",' "$(json_escape "$SCAN_MODE")"
printf '"base_ref":%s,' "$BASE_REF_JSON"
printf '"files_scanned":%s,' "$(append_json_string_array "$TMP_FILES")"
printf '"summary":{"verdict":"%s","major":%s,"minor":%s,"recommendation":%s,"total":%s},' \
  "$VERDICT" \
  "$MAJOR_COUNT" \
  "$MINOR_COUNT" \
  "$RECOMMENDATION_COUNT" \
  "$TOTAL_COUNT"
printf '"observations":%s' "$(append_json_object_array "$TMP_OBS")"
printf '}\n'
