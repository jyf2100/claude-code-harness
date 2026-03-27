#!/usr/bin/env bash
#
# codex-worker-engine.sh
# Codex Worker 执行引擎
#
# Usage: ./scripts/codex-worker-engine.sh --task "任务内容" [--worktree PATH] [--dry-run]
#

set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载通用库
# shellcheck source=lib/codex-worker-common.sh
source "$SCRIPT_DIR/lib/codex-worker-common.sh"

# ============================================
# 本地配置（在 main 中初始化）
# ============================================
MAX_RETRIES=""
APPROVAL_POLICY=""
SANDBOX=""

# 配置初始化（在 check_dependencies 后调用）
init_config() {
    validate_config || {
        log_error "配置文件无效"
        exit 1
    }
    MAX_RETRIES=$(get_config "max_retries")
    APPROVAL_POLICY=$(get_config "approval_policy")
    SANDBOX=$(get_config "sandbox")
}

# 全局变量
TASK=""
WORKTREE_PATH=""
DRY_RUN=false
PROJECT_ROOT=""
AGENTS_HASH=""
CONTRACT_TEMPLATE="$SCRIPT_DIR/lib/codex-hardening-contract.txt"

# 使用说明
usage() {
    cat << EOF
Usage: $0 --task "任务内容" [OPTIONS]

Options:
  --task TEXT       要执行的任务内容（必填）
  --worktree PATH   Worktree 路径（省略时使用当前目录）
  --dry-run         演练模式（不执行，仅显示内容）
  -h, --help        显示帮助

Examples:
  $0 --task "实现登录功能"
  $0 --task "添加 API 端点" --worktree ../worktree-task-1
  $0 --task "修复测试" --dry-run
EOF
}

# 参数解析
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task)
                if [[ -z "${2:-}" ]]; then
                    log_error "--task 需要指定值"
                    exit 1
                fi
                TASK="$2"
                shift 2
                ;;
            --worktree)
                if [[ -z "${2:-}" ]]; then
                    log_error "--worktree 需要指定值"
                    exit 1
                fi
                WORKTREE_PATH="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    if [[ -z "$TASK" ]]; then
        log_error "--task 是必填项"
        usage
        exit 1
    fi
}

# 项目根目录检测
detect_project_root() {
    if [[ -n "$WORKTREE_PATH" ]]; then
        # Security: worktree 路径验证（允许在仓库外，但需确认是同一仓库的 worktree）
        if ! validate_worktree_path "$WORKTREE_PATH"; then
            log_error "无效的 worktree 路径: $WORKTREE_PATH"
            exit 1
        fi
        PROJECT_ROOT="$WORKTREE_PATH"
    else
        PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    fi
    log_info "项目根目录: $PROJECT_ROOT"
}

# AGENTS.md 哈希计算
compute_agents_hash() {
    local agents_file="$PROJECT_ROOT/AGENTS.md"

    if [[ ! -f "$agents_file" ]]; then
        log_error "找不到 AGENTS.md: $agents_file"
        log_error "AGENTS.md 是必需的。中断 Worker 执行。"
        exit 1
    fi

    # 移除 BOM、LF 规范化、SHA256 前 8 位（跨平台兼容）
    AGENTS_HASH=$(calculate_file_hash "$agents_file" 8)
    log_info "AGENTS.md 哈希: $AGENTS_HASH"
}

# Rules 合并（为确保确定性按名称排序）
collect_rules() {
    local rules_dir="$PROJECT_ROOT/.claude/rules"
    local rules_content=""
    local rules_hash=""

    if [[ -d "$rules_dir" ]]; then
        # Quality: 为确保确定性按名称排序后合并
        local rule_files
        rule_files=$(find "$rules_dir" -name "*.md" -type f 2>/dev/null | sort)

        if [[ -n "$rule_files" ]]; then
            while IFS= read -r rule_file; do
                if [[ -f "$rule_file" ]]; then
                    rules_content+="# $(basename "$rule_file")"$'\n'
                    rules_content+="$(cat "$rule_file")"$'\n\n'
                fi
            done <<< "$rule_files"

            # 输出合并结果的哈希（用于调试）
            rules_hash=$(calculate_sha256 "$rules_content" 8 2>/dev/null || echo "unknown")
            log_info "Rules 文件收集: $(echo "$rule_files" | wc -l | tr -d ' ') 个 (hash: $rules_hash)"
        fi
    else
        log_warn "找不到 Rules 目录: $rules_dir"
    fi

    echo "$rules_content"
}

generate_hardening_contract() {
    if [[ ! -f "$CONTRACT_TEMPLATE" ]]; then
        log_error "找不到 hardening contract 模板: $CONTRACT_TEMPLATE"
        exit 1
    fi
    cat "$CONTRACT_TEMPLATE"
}

prepend_hardening_contract() {
    local body="$1"
    printf '%s\n\n---\n\n%s\n' "$(generate_hardening_contract)" "$body"
}

# 生成 base-instructions
generate_base_instructions() {
    local rules_content
    rules_content=$(collect_rules)

    local body
    body=$(cat << EOF
# Codex Worker Instructions

## Rules（项目特定规则）

$rules_content

## AGENTS.md 强制读取指示

请先读取 AGENTS.md，并以以下格式输出凭证：

\`\`\`
AGENTS_SUMMARY: <1行摘要> | HASH:<SHA256前8位>
\`\`\`

请勿在未输出凭证的情况下开始工作。
凭证中的哈希值应从 AGENTS.md 的内容计算得出。

EOF
)
    prepend_hardening_contract "$body"
}

# 生成 prompt
generate_prompt() {
    local body
    body=$(cat << EOF
$TASK

---

重要：在开始工作之前，请以以下格式输出 AGENTS.md 的凭证：

AGENTS_SUMMARY: <AGENTS.md的1行摘要> | HASH:<SHA256前8位>

如果没有此凭证，工作将被视为无效。
EOF
)
    prepend_hardening_contract "$body"
}

# 凭证验证（预期从 Claude Code 内部调用，本脚本内不使用）
# 实际验证由 codex-worker-quality-gate.sh 的 gate_evidence() 执行
verify_agents_summary() {
    local output="$1"

    # 使用正则表达式匹配（大小写兼容）
    if [[ "$output" =~ AGENTS_SUMMARY:[[:space:]]*(.+)[[:space:]]*\|[[:space:]]*HASH:([A-Fa-f0-9]{8}) ]]; then
        local summary="${BASH_REMATCH[1]}"
        local hash="${BASH_REMATCH[2]}"

        if [[ "${hash,,}" == "${AGENTS_HASH,,}" ]]; then
            log_info "凭证验证: OK (哈希匹配, summary: ${summary:0:50}...)"
            return 0
        else
            log_error "凭证验证: NG (哈希不匹配: 期望=$AGENTS_HASH, 实际=$hash)"
            return 1
        fi
    else
        log_error "凭证验证: NG (找不到 AGENTS_SUMMARY)"
        return 1
    fi
}

# 调用 Codex Worker（通过 CLI）
invoke_codex_worker() {
    local base_instructions
    local prompt
    local cwd="$PROJECT_ROOT"

    base_instructions=$(generate_base_instructions)
    prompt=$(generate_prompt)

    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        echo "========================================"
        echo "演练模式：将使用以下内容调用 Codex"
        echo "========================================"
        echo ""
        echo "--- prompt ---"
        echo "$prompt"
        echo ""
        echo "--- base-instructions (前500字符) ---"
        echo "${base_instructions:0:500}..."
        echo ""
        echo "--- 参数 ---"
        echo "cwd: $cwd"
        echo "approval-policy: $APPROVAL_POLICY"
        echo "sandbox: $SANDBOX"
        echo ""
        return 0
    fi

    log_step "正在调用 Codex Worker..."

    # 注：实际的 codex exec 调用从 Claude Code 内部进行
    # 本脚本负责生成 base-instructions 和 prompt
    # 将输出保存到文件供 Claude Code 读取

    local output_dir="$PROJECT_ROOT/.claude/state/codex-worker"
    mkdir -p "$output_dir"

    echo "$base_instructions" > "$output_dir/base-instructions.txt"
    echo "$prompt" > "$output_dir/prompt.txt"

    jq -n \
        --arg prompt "$prompt" \
        --arg base_instructions "$base_instructions" \
        --arg cwd "$cwd" \
        --arg approval_policy "$APPROVAL_POLICY" \
        --arg sandbox "$SANDBOX" \
        '{
            "prompt": $prompt,
            "base-instructions": $base_instructions,
            "cwd": $cwd,
            "approval-policy": $approval_policy,
            "sandbox": $sandbox
        }' > "$output_dir/codex-exec-params.json"

    # 保存验证信息（注：不包含 agents_hash - 安全原因）
    # 强制 Worker 实际读取 AGENTS.md 并输出凭证
    cat > "$output_dir/verify-info.json" << EOF
{
  "max_retries": $MAX_RETRIES,
  "verify_pattern": "AGENTS_SUMMARY:\\\\s*(.+?)\\\\s*\\\\|\\\\s*HASH:([A-Fa-f0-9]{8})",
  "note": "agents_hash 由 quality-gate 在验证时计算（防止泄露给 Worker）"
}
EOF

    log_info "Codex CLI 参数已保存: $output_dir/codex-exec-params.json"
    log_info "验证信息已保存: $output_dir/verify-info.json"
    echo ""
    log_info "后续步骤:"
    log_info "  1. 从 Claude Code 调用 codex exec"
    log_info "  2. 确认输出中包含 AGENTS_SUMMARY 凭证"
    log_info "  3. 确认哈希与 $AGENTS_HASH 匹配"
    log_info "  4. 失败时最多重试 $MAX_RETRIES 次"
}

# 主处理
main() {
    parse_args "$@"

    echo "========================================"
    echo "Codex Worker Engine"
    echo "========================================"
    echo ""

    log_step "1. 检测项目根目录"
    detect_project_root

    log_step "2. 检查依赖命令"
    check_dependencies

    log_step "2.5. 初始化配置"
    init_config

    log_step "3. 计算 AGENTS.md 哈希"
    compute_agents_hash

    log_step "4. 准备调用 Codex Worker"
    invoke_codex_worker

    echo ""
    log_info "完成"
}

main "$@"
