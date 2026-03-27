#!/bin/bash
# posttooluse-tampering-detector.sh
# 检测测试篡改模式并发出警告（不阻止）
#
# 用途: 在 PostToolUse 中 Write|Edit 后执行
# 行为:
#   - 监控测试文件（*.test.*, *.spec.*）的变更
#   - 检测篡改模式（skip化、断言删除、eslint-disable）
#   - 检测到时将警告作为 additionalContext 输出
#   - 记录日志（.claude/state/tampering.log）
#
# 输出: JSON格式，将警告输出到 hookSpecificOutput.additionalContext
#       → Claude Code 以 system-reminder 形式显示

set +e

# ===== 获取输入 =====
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null || true)"
fi

[ -z "$INPUT" ] && exit 0

# ===== JSON 解析 =====
TOOL_NAME=""
FILE_PATH=""
OLD_STRING=""
NEW_STRING=""
CONTENT=""

if command -v jq >/dev/null 2>&1; then
  TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
  FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
  OLD_STRING=$(printf '%s' "$INPUT" | jq -r '.tool_input.old_string // empty' 2>/dev/null || true)
  NEW_STRING=$(printf '%s' "$INPUT" | jq -r '.tool_input.new_string // empty' 2>/dev/null || true)
  CONTENT=$(printf '%s' "$INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null || true)
elif command -v python3 >/dev/null 2>&1; then
  eval "$(printf '%s' "$INPUT" | python3 -c '
import json, shlex, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
tool_name = data.get("tool_name") or ""
tool_input = data.get("tool_input") or {}
file_path = tool_input.get("file_path") or ""
old_string = tool_input.get("old_string") or ""
new_string = tool_input.get("new_string") or ""
content = tool_input.get("content") or ""
print(f"TOOL_NAME={shlex.quote(tool_name)}")
print(f"FILE_PATH={shlex.quote(file_path)}")
print(f"OLD_STRING={shlex.quote(old_string)}")
print(f"NEW_STRING={shlex.quote(new_string)}")
print(f"CONTENT={shlex.quote(content)}")
' 2>/dev/null)"
fi

# 跳过非 Write/Edit 操作
[[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]] && exit 0

# 跳过无文件路径的情况
[ -z "$FILE_PATH" ] && exit 0

# ===== 测试文件判定 =====
is_test_file() {
  local path="$1"
  case "$path" in
    *.test.ts|*.test.tsx|*.test.js|*.test.jsx) return 0 ;;
    *.spec.ts|*.spec.tsx|*.spec.js|*.spec.jsx) return 0 ;;
    *.test.py|test_*.py|*_test.py) return 0 ;;
    *.test.go|*_test.go) return 0 ;;
    */__tests__/*|*/tests/*) return 0 ;;
  esac
  return 1
}

# lint/CI 配置文件判定
is_config_file() {
  local path="$1"
  case "$path" in
    .eslintrc*|eslint.config.*) return 0 ;;
    .prettierrc*|prettier.config.*) return 0 ;;
    tsconfig.json|tsconfig.*.json) return 0 ;;
    biome.json|.stylelintrc*) return 0 ;;
    jest.config.*|vitest.config.*) return 0 ;;
    .github/workflows/*.yml|.github/workflows/*.yaml) return 0 ;;
    .gitlab-ci.yml|Jenkinsfile) return 0 ;;
  esac
  return 1
}

# 跳过非测试文件和配置文件
if ! is_test_file "$FILE_PATH" && ! is_config_file "$FILE_PATH"; then
  exit 0
fi

# ===== 篡改模式检测 =====
WARNINGS=""

# 待检测的内容
CHECK_CONTENT="${NEW_STRING}${CONTENT}"

# 测试文件的篡改检测
if is_test_file "$FILE_PATH"; then
  # skip 化检测 (JS/TS) / 检测到测试 skip 化
  if [[ "$CHECK_CONTENT" =~ (^|[^a-zA-Z_])(it|describe|test)\.skip[[:space:]]*\(|(^|[^a-zA-Z_])xit[[:space:]]*\(|(^|[^a-zA-Z_])xdescribe[[:space:]]*\( ]]; then
    WARNINGS="${WARNINGS}⚠️ Test skip detected / 检测到测试 skip 化 (it.skip/describe.skip/xit)\n"
  fi

  # skip 化检测 (Python) / 检测到 Python 测试 skip 化
  # @pytest.mark.skip, @pytest.mark.skipIf, @unittest.skip, @unittest.skipIf, self.skipTest()
  if [[ "$CHECK_CONTENT" =~ @pytest\.mark\.skip|@unittest\.skip|self\.skipTest[[:space:]]*\( ]]; then
    WARNINGS="${WARNINGS}⚠️ Python test skip detected / 检测到 Python 测试 skip 化 (@pytest.mark.skip / @unittest.skip / self.skipTest)\n"
  fi

  # .only 化检测 / 检测到测试 .only 化
  if [[ "$CHECK_CONTENT" =~ (^|[^a-zA-Z_])(it|describe|test)\.only[[:space:]]*\(|(^|[^a-zA-Z_])fit[[:space:]]*\(|(^|[^a-zA-Z_])fdescribe[[:space:]]*\( ]]; then
    WARNINGS="${WARNINGS}⚠️ Test .only detected / 检测到测试 .only 化（其他测试将不会执行）\n"
  fi

  # eslint-disable 添加检测 / 检测到 lint/类型检查抑制
  if [[ "$CHECK_CONTENT" =~ eslint-disable|@ts-ignore|@ts-expect-error|@ts-nocheck ]]; then
    WARNINGS="${WARNINGS}⚠️ Lint/type suppression detected / 检测到 lint/类型检查禁用注释\n"
  fi

  # expect 删除检测（Edit 情况）/ 检测到断言删除
  if [ -n "$OLD_STRING" ] && [ -n "$NEW_STRING" ]; then
    OLD_EXPECTS=$(printf '%s' "$OLD_STRING" | grep -c 'expect\s*(' || true)
    NEW_EXPECTS=$(printf '%s' "$NEW_STRING" | grep -c 'expect\s*(' || true)
    if [ "$OLD_EXPECTS" -gt 0 ] && [ "$NEW_EXPECTS" -lt "$OLD_EXPECTS" ]; then
      WARNINGS="${WARNINGS}⚠️ Assertion removal detected / 检测到断言删除 (expect: ${OLD_EXPECTS} → ${NEW_EXPECTS})\n"
    fi
  fi

  # assert 删除检测（Python）/ 检测到断言删除
  if [ -n "$OLD_STRING" ] && [ -n "$NEW_STRING" ]; then
    OLD_ASSERTS=$(printf '%s' "$OLD_STRING" | grep -cE '\bassert\b|self\.assert' || true)
    NEW_ASSERTS=$(printf '%s' "$NEW_STRING" | grep -cE '\bassert\b|self\.assert' || true)
    if [ "$OLD_ASSERTS" -gt 0 ] && [ "$NEW_ASSERTS" -lt "$OLD_ASSERTS" ]; then
      WARNINGS="${WARNINGS}⚠️ Assertion removal detected / 检测到断言删除 (assert: ${OLD_ASSERTS} → ${NEW_ASSERTS})\n"
    fi
  fi

  # 断言弱化检测（Edit 情况）/ 检测到断言弱化
  # 检测 toBe → toBeTruthy/toBeDefined/toBeUndefined/toBeNull/toBeFalsy 等弱断言替换
  if [ -n "$OLD_STRING" ] && [ -n "$NEW_STRING" ]; then
    # 检查 OLD 中是否有严格断言，NEW 中是否替换为弱断言
    OLD_STRICT=$(printf '%s' "$OLD_STRING" | grep -cE '\.toBe\(|\.toEqual\(|\.toStrictEqual\(|\.toHaveBeenCalledWith\(' || true)
    NEW_WEAK=$(printf '%s' "$NEW_STRING" | grep -cE '\.toBeTruthy\(|\.toBeDefined\(|\.toBeUndefined\(|\.toBeNull\(|\.toBeFalsy\(|\.toBeGreaterThanOrEqual\(0\)|\.toHaveBeenCalled\(\)' || true)
    NEW_STRICT=$(printf '%s' "$NEW_STRING" | grep -cE '\.toBe\(|\.toEqual\(|\.toStrictEqual\(|\.toHaveBeenCalledWith\(' || true)
    # 严格断言减少且弱断言增加时发出警告
    if [ "$OLD_STRICT" -gt 0 ] && [ "$NEW_STRICT" -lt "$OLD_STRICT" ] && [ "$NEW_WEAK" -gt 0 ]; then
      WARNINGS="${WARNINGS}⚠️ Assertion weakening detected / 检测到断言弱化 (strict: ${OLD_STRICT} → ${NEW_STRICT}, weak: +${NEW_WEAK}). e.g. toBe → toBeTruthy, toEqual → toBeDefined\n"
    fi
  fi

  # timeout 值大幅增加检测 / 检测到大幅超时增加
  # 检测 jest.setTimeout(N), jasmine.DEFAULT_TIMEOUT_INTERVAL = N, { timeout: N } 等大值（30000ms 以上）
  TIMEOUT_THRESHOLD=30000
  TIMEOUT_HIT=$(printf '%s' "$CHECK_CONTENT" | grep -E 'jest\.setTimeout\(|jasmine\.DEFAULT_TIMEOUT_INTERVAL|[[:space:]]timeout[[:space:]]*:' | grep -oE '[0-9]+' | awk -v thr="$TIMEOUT_THRESHOLD" '$1 >= thr {found=1} END {print found+0}' || true)
  if [ "${TIMEOUT_HIT:-0}" -gt 0 ]; then
    WARNINGS="${WARNINGS}⚠️ Large timeout detected / 检测到超时值大幅增加 (≥${TIMEOUT_THRESHOLD}ms). e.g. jest.setTimeout(30000)\n"
  fi

  # 通配断言检测 / 检测到通配断言
  # 检测 expect(true).toBe(true), expect(1).toBe(1) 等总是成功的无意义断言
  if [[ "$CHECK_CONTENT" =~ expect\((true|false|1|0|null|undefined|[\"\']{2})\)\.(toBe|toEqual|toStrictEqual)\((true|false|1|0|null|undefined|[\"\']{2})\) ]]; then
    WARNINGS="${WARNINGS}⚠️ Catch-all assertion detected / 检测到总是成功的无意义断言 (e.g. expect(true).toBe(true))\n"
  fi

  # 检测对常量值应用 toBeUndefined/toBeNull/toBeFalsy/toBeTruthy 的模式
  if [[ "$CHECK_CONTENT" =~ expect\((true|false|null|undefined|0)\)\.(toBeUndefined|toBeNull|toBeFalsy|toBeTruthy)\(\) ]]; then
    WARNINGS="${WARNINGS}⚠️ Catch-all assertion detected / 检测到对常量的弱断言 (e.g. expect(false).toBeFalsy())\n"
  fi
fi

# 配置文件的放宽检测
if is_config_file "$FILE_PATH"; then
  # eslint 规则禁用 / 检测到 lint 规则禁用
  if [[ "$CHECK_CONTENT" =~ \"off\"|:[[:space:]]*0|\"warn\".*→.*\"off\" ]]; then
    WARNINGS="${WARNINGS}⚠️ Lint rule disabled / 检测到 lint 规则禁用\n"
  fi

  # CI continue-on-error / 检测到 CI continue-on-error
  if [[ "$CHECK_CONTENT" =~ continue-on-error:[[:space:]]*true ]]; then
    WARNINGS="${WARNINGS}⚠️ CI continue-on-error detected / 检测到 CI continue-on-error 添加\n"
  fi

  # strict 模式放宽 / 检测到 TypeScript strict 模式放宽
  if [[ "$CHECK_CONTENT" =~ \"strict\"[[:space:]]*:[[:space:]]*false|\"noImplicitAny\"[[:space:]]*:[[:space:]]*false ]]; then
    WARNINGS="${WARNINGS}⚠️ TypeScript strict mode weakened / 检测到 TypeScript strict 模式放宽\n"
  fi
fi

# ===== 无警告则退出 =====
[ -z "$WARNINGS" ] && exit 0

# ===== 记录日志 =====
STATE_DIR=".claude/state"
LOG_FILE="$STATE_DIR/tampering.log"

if [ -d "$STATE_DIR" ] || mkdir -p "$STATE_DIR" 2>/dev/null; then
  echo "[$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')] FILE=$FILE_PATH TOOL=$TOOL_NAME" >> "$LOG_FILE" 2>/dev/null || true
  printf '%b' "$WARNINGS" | sed 's/^/  /' >> "$LOG_FILE" 2>/dev/null || true
fi

# ===== 输出警告 =====
# 作为 additionalContext 输出，以便 Claude 在下一轮能看到
WARNING_MSG="[Tampering Detector] Suspicious patterns detected in test/config file changes:
[Tampering Detector] 在测试/配置文件变更中检测到以下模式：

$(printf '%b' "$WARNINGS")
File / 文件: $FILE_PATH

If this is an intentional change, no action is needed.
如果这是有意的变更则无需操作，但可能存在测试篡改风险。

⚠️ Fix the implementation, not the tests. / 正确的做法是修复实现，而非篡改测试（skip化、断言删除）。
⚠️ Fix the code, not the config. / 正确的做法是修复代码，而非放宽配置。"

# JSON 输出
if command -v jq >/dev/null 2>&1; then
  jq -nc --arg ctx "$WARNING_MSG" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
else
  # 无 jq 时使用最小转义输出
  ESCAPED_MSG=$(echo "$WARNING_MSG" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"${ESCAPED_MSG}\"}}"
fi

exit 0
