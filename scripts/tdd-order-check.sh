#!/bin/bash
# tdd-order-check.sh
# TDD 默认启用。输出建议测试先行的警告（不阻止操作）
#
# 用途: 在 PostToolUse 中执行 Write|Edit 后运行
# 行为:
#   - Plans.md 中存在 cc:WIP 任务时（TDD 默认启用）
#   - 但带有 [skip:tdd] 标记的 WIP 任务会被跳过
#   - 主体文件（*.ts, *.tsx, *.js, *.jsx）被编辑
#   - 对应的测试文件（*.test.*, *.spec.*）尚未被编辑
#   → 输出警告消息（不阻止操作）

set -euo pipefail

# 获取已编辑的文件信息
TOOL_INPUT="${TOOL_INPUT:-}"
FILE_PATH=""

# 从 TOOL_INPUT 中提取 file_path（兼容 macOS/Linux）
if [[ -n "$TOOL_INPUT" ]]; then
    # 如果 jq 可用则使用 jq（最安全）
    if command -v jq &>/dev/null; then
        FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty' 2>/dev/null || true)
    else
        # 备用方案: 使用 sed 提取（POSIX 兼容）
        FILE_PATH=$(echo "$TOOL_INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' 2>/dev/null || true)
    fi
fi

# 如果没有文件路径则退出
if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# 检查是否为测试文件
is_test_file() {
    local file="$1"
    [[ "$file" =~ \.(test|spec)\.(ts|tsx|js|jsx)$ ]] || \
    [[ "$file" =~ __tests__/ ]] || \
    [[ "$file" =~ /tests?/ ]]
}

# 检查是否为源文件（排除测试文件）
is_source_file() {
    local file="$1"
    [[ "$file" =~ \.(ts|tsx|js|jsx)$ ]] && ! is_test_file "$file"
}

# 检查是否存在活跃的 WIP 任务
has_active_wip_task() {
    if [[ -f "Plans.md" ]]; then
        grep -q 'cc:WIP' Plans.md 2>/dev/null
        return $?
    fi
    return 1
}

# 检查 WIP 任务是否有 [skip:tdd] 标记
is_tdd_skipped() {
    if [[ -f "Plans.md" ]]; then
        grep -q '\[skip:tdd\].*cc:WIP\|cc:WIP.*\[skip:tdd\]' Plans.md 2>/dev/null
        return $?
    fi
    return 1
}

# 检查会话中是否编辑过测试文件（简化版）
test_edited_this_session() {
    # 如果存在 .claude/state/session-changes.json 则检查
    local state_file=".claude/state/session-changes.json"
    if [[ -f "$state_file" ]]; then
        grep -q '\.test\.\|\.spec\.\|__tests__' "$state_file" 2>/dev/null
        return $?
    fi
    return 1
}

# 主处理逻辑
main() {
    # 如果不是源文件则跳过
    if ! is_source_file "$FILE_PATH"; then
        exit 0
    fi

    # 如果是测试文件则跳过
    if is_test_file "$FILE_PATH"; then
        exit 0
    fi

    # 如果没有 WIP 任务则跳过
    if ! has_active_wip_task; then
        exit 0
    fi

    # 如果有 [skip:tdd] 标记则跳过
    if is_tdd_skipped; then
        exit 0
    fi

    # 如果测试文件已被编辑则跳过
    if test_edited_this_session; then
        exit 0
    fi

    # 输出警告（不阻止操作）
    cat << 'EOF'
{
  "decision": "approve",
  "reason": "TDD reminder",
  "systemMessage": "💡 TDD 默认启用。建议先编写测试。\n\n当前您已编辑主体文件，但对应的测试文件尚未编辑。\n\n建议: 请先创建测试文件（*.test.ts, *.spec.ts），然后再实现主体代码。\n\n如需跳过，请在 Plans.md 的相应任务中添加 [skip:tdd] 标记。\n\n这是警告，不会阻止操作。"
}
EOF
}

main
