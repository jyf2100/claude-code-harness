#!/bin/bash
# auto-test-runner.sh - 文件变更时的自动测试执行
# 由 PostToolUse hook 调用

set +e  # 遇错不停止

# 获取变更的文件（stdin JSON 优先 / 兼容: $1,$2）
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

CHANGED_FILE="${1:-}"
TOOL_NAME="${2:-}"
CWD=""

if [ -n "$INPUT" ]; then
  if command -v jq >/dev/null 2>&1; then
    TOOL_NAME_FROM_STDIN="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
    FILE_PATH_FROM_STDIN="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)"
    CWD_FROM_STDIN="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
  elif command -v python3 >/dev/null 2>&1; then
    eval "$(printf '%s' "$INPUT" | python3 -c '
import json, shlex, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
tool_name = data.get("tool_name") or ""
cwd = data.get("cwd") or ""
tool_input = data.get("tool_input") or {}
tool_response = data.get("tool_response") or {}
file_path = tool_input.get("file_path") or tool_response.get("filePath") or ""
print(f"TOOL_NAME_FROM_STDIN={shlex.quote(tool_name)}")
print(f"CWD_FROM_STDIN={shlex.quote(cwd)}")
print(f"FILE_PATH_FROM_STDIN={shlex.quote(file_path)}")
' 2>/dev/null)"
  fi

  [ -z "$CHANGED_FILE" ] && CHANGED_FILE="${FILE_PATH_FROM_STDIN:-}"
  [ -z "$TOOL_NAME" ] && TOOL_NAME="${TOOL_NAME_FROM_STDIN:-}"
  CWD="${CWD_FROM_STDIN:-}"
fi

# 如果可能则规范化为项目相对路径
if [ -n "$CWD" ] && [ -n "$CHANGED_FILE" ] && [[ "$CHANGED_FILE" == "$CWD/"* ]]; then
  CHANGED_FILE="${CHANGED_FILE#$CWD/}"
fi

# 排除测试的文件
EXCLUDED_PATTERNS=(
    "*.md"
    "*.json"
    "*.yml"
    "*.yaml"
    ".gitignore"
    "*.lock"
    "node_modules/*"
    ".git/*"
)

# 判断是否需要运行测试
should_run_tests() {
    local file="$1"

    # 文件为空则跳过
    [ -z "$file" ] && return 1

    # 匹配排除模式则跳过
    for pattern in "${EXCLUDED_PATTERNS[@]}"; do
        if [[ "$file" == $pattern ]]; then
            return 1
        fi
    done

    # 测试文件本身的变更
    if [[ "$file" == *".test."* ]] || [[ "$file" == *".spec."* ]] || [[ "$file" == *"__tests__"* ]]; then
        return 0
    fi

    # 源代码文件的变更
    if [[ "$file" == *.ts ]] || [[ "$file" == *.tsx ]] || [[ "$file" == *.js ]] || [[ "$file" == *.jsx ]]; then
        return 0
    fi

    if [[ "$file" == *.py ]]; then
        return 0
    fi

    if [[ "$file" == *.go ]]; then
        return 0
    fi

    if [[ "$file" == *.rs ]]; then
        return 0
    fi

    return 1
}

# 检测测试命令
detect_test_command() {
    # 存在 package.json 的情况
    if [ -f "package.json" ]; then
        if grep -q '"test"' package.json 2>/dev/null; then
            echo "npm test"
            return 0
        fi
    fi

    # pytest
    if [ -f "pytest.ini" ] || [ -f "pyproject.toml" ] || [ -d "tests" ]; then
        if command -v pytest &>/dev/null; then
            echo "pytest"
            return 0
        fi
    fi

    # go test
    if [ -f "go.mod" ]; then
        echo "go test ./..."
        return 0
    fi

    # cargo test
    if [ -f "Cargo.toml" ]; then
        echo "cargo test"
        return 0
    fi

    return 1
}

# 检测相关的测试文件
find_related_tests() {
    local file="$1"
    local basename="${file%.*}"
    local dirname=$(dirname "$file")

    # 测试文件的模式
    local test_patterns=(
        "${basename}.test.ts"
        "${basename}.test.tsx"
        "${basename}.test.js"
        "${basename}.test.jsx"
        "${basename}.spec.ts"
        "${basename}.spec.tsx"
        "${basename}.spec.js"
        "${basename}.spec.jsx"
        "${dirname}/__tests__/$(basename "$basename").test.ts"
        "${dirname}/__tests__/$(basename "$basename").test.tsx"
        "test_${basename##*/}.py"
        "${basename##*/}_test.go"
    )

    for pattern in "${test_patterns[@]}"; do
        if [ -f "$pattern" ]; then
            echo "$pattern"
            return 0
        fi
    done

    return 1
}

# 实际执行测试并写入结果文件（HARNESS_AUTO_TEST=run 模式）
run_tests() {
    local test_cmd="$1"
    local related_test="$2"

    STATE_DIR=".claude/state"
    mkdir -p "$STATE_DIR"

    RESULT_FILE="${STATE_DIR}/test-result.json"
    TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    # 确定执行命令（如有相关测试则缩小范围）
    if [ -n "$related_test" ]; then
        EXEC_CMD="$test_cmd -- $related_test"
    else
        EXEC_CMD="$test_cmd"
    fi

    # 带超时的测试执行（最长 60 秒）
    TIMEOUT_CMD=$(command -v timeout || command -v gtimeout || echo "")
    TMP_OUT="${STATE_DIR}/test-output.tmp"

    if [ -n "$TIMEOUT_CMD" ]; then
        $TIMEOUT_CMD 60 bash -c "$EXEC_CMD" > "$TMP_OUT" 2>&1
        EXIT_CODE=$?
    else
        bash -c "$EXEC_CMD" > "$TMP_OUT" 2>&1
        EXIT_CODE=$?
    fi

    # 获取输出（最多 200 行）
    OUTPUT=$(head -200 "$TMP_OUT" 2>/dev/null || true)
    rm -f "$TMP_OUT"

    # 成功/失败判定
    if [ "$EXIT_CODE" -eq 0 ]; then
        STATUS="passed"
    elif [ "$EXIT_CODE" -eq 124 ]; then
        STATUS="timeout"
    else
        STATUS="failed"
    fi

    # 以 JSON 格式写入结果
    if command -v jq >/dev/null 2>&1; then
        jq -n \
            --arg ts "$TIMESTAMP" \
            --arg file "$CHANGED_FILE" \
            --arg cmd "$EXEC_CMD" \
            --arg status "$STATUS" \
            --argjson code "$EXIT_CODE" \
            --arg out "$OUTPUT" \
            '{timestamp:$ts,changed_file:$file,command:$cmd,status:$status,exit_code:$code,output:$out}' \
            > "$RESULT_FILE" 2>/dev/null || true
    else
        # 没有 jq 的情况下输出最小化的 JSON
        ESCAPED_OUT=$(printf '%s' "$OUTPUT" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
        cat > "$RESULT_FILE" << EOF
{"timestamp":"$TIMESTAMP","changed_file":"$CHANGED_FILE","command":"$EXEC_CMD","status":"$STATUS","exit_code":$EXIT_CODE,"output":"$ESCAPED_OUT"}
EOF
    fi

    return "$EXIT_CODE"
}

# 主处理
main() {
    # 检查是否需要运行测试
    if ! should_run_tests "$CHANGED_FILE"; then
        exit 0
    fi

    # 检测测试命令
    TEST_CMD=$(detect_test_command)
    if [ -z "$TEST_CMD" ]; then
        exit 0
    fi

    # 检测相关测试文件
    RELATED_TEST=$(find_related_tests "$CHANGED_FILE")

    # 记录到状态文件
    STATE_DIR=".claude/state"
    mkdir -p "$STATE_DIR"

    # HARNESS_AUTO_TEST=run 时实际执行测试
    if [ "${HARNESS_AUTO_TEST:-}" = "run" ]; then
        run_tests "$TEST_CMD" "$RELATED_TEST"
        EXIT_CODE=$?

        # 将结果摘要输出到 stderr（用于 hooks 日志）
        RESULT_FILE="${STATE_DIR}/test-result.json"
        if [ -f "$RESULT_FILE" ]; then
            STATUS=$(command -v jq >/dev/null 2>&1 && jq -r '.status // "unknown"' "$RESULT_FILE" 2>/dev/null || grep -o '"status":"[^"]*"' "$RESULT_FILE" | head -1 | sed 's/"status":"\([^"]*\)"/\1/')
            OUTPUT_SNIPPET=$(command -v jq >/dev/null 2>&1 && jq -r '.output // ""' "$RESULT_FILE" 2>/dev/null | head -30 || true)
            echo "[auto-test-runner] run mode: $STATUS (exit=$EXIT_CODE) file=$CHANGED_FILE" >&2

            # 将测试结果作为 additionalContext 通知 Claude
            if [ "$STATUS" = "passed" ]; then
                CONTEXT_MSG="[Auto Test Runner] Tests passed / 测试成功
Command: $TEST_CMD
File: $CHANGED_FILE
Status: PASSED (exit=0)"
            elif [ "$STATUS" = "timeout" ]; then
                CONTEXT_MSG="[Auto Test Runner] Tests timed out / 测试超时 (60s)
Command: $TEST_CMD
File: $CHANGED_FILE
Status: TIMEOUT

Output:
${OUTPUT_SNIPPET}"
            else
                CONTEXT_MSG="[Auto Test Runner] Tests failed / 测试失败
Command: $TEST_CMD
File: $CHANGED_FILE
Status: FAILED (exit=$EXIT_CODE)

Output:
${OUTPUT_SNIPPET}

Fix the implementation to make the tests pass. / 请修复实现以使测试通过。"
            fi

            # JSON 输出（additionalContext）
            if command -v jq >/dev/null 2>&1; then
                jq -nc --arg ctx "$CONTEXT_MSG" \
                    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
            else
                ESCAPED_CTX=$(printf '%s' "$CONTEXT_MSG" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')
                printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$ESCAPED_CTX"
            fi
        fi
        exit 0
    fi

    # 默认: recommend 模式（记录测试推荐）
    cat > "${STATE_DIR}/test-recommendation.json" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "changed_file": "$CHANGED_FILE",
  "test_command": "$TEST_CMD",
  "related_test": "$RELATED_TEST",
  "recommendation": "建议执行测试"
}
EOF

    # 输出通知
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🧪 建议运行测试"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📁 变更文件: $CHANGED_FILE"
    if [ -n "$RELATED_TEST" ]; then
        echo "🔗 相关测试: $RELATED_TEST"
    fi
    echo "📋 推荐命令: $TEST_CMD"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

main
