#!/usr/bin/env bash
#
# codex-worker-setup.sh
# Codex Worker 功能的设置脚本
#
# Usage: ./scripts/codex-worker-setup.sh [--check-only]
#
# Options:
#   --check-only  仅检查安装状态（不做任何更改）
#

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 最低版本要求
MIN_CODEX_VERSION="0.107.0"
MIN_GIT_VERSION="2.5.0"

# 全局变量
CHECK_ONLY=false
ERRORS=()
WARNINGS=()
CODEX_CLI_OK=false
CODEX_EXEC_OK=false

# 辅助函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    WARNINGS+=("$1")
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ERRORS+=("$1")
}

# 版本比较（semver）
version_gte() {
    local v1="$1"
    local v2="$2"

    # 将版本字符串转换为数值数组
    IFS='.' read -ra V1 <<< "$v1"
    IFS='.' read -ra V2 <<< "$v2"

    # 比较各段
    for i in 0 1 2; do
        local n1="${V1[$i]:-0}"
        local n2="${V2[$i]:-0}"

        if (( n1 > n2 )); then
            return 0
        elif (( n1 < n2 )); then
            return 1
        fi
    done

    return 0
}

# Codex CLI 检查
check_codex_cli() {
    log_info "正在检查 Codex CLI..."

    if ! command -v codex &> /dev/null; then
        log_error "未找到 Codex CLI"
        log_info "安装方法: npm install -g @openai/codex"
        return 1
    fi

    local version
    version=$(codex --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0")

    if version_gte "$version" "$MIN_CODEX_VERSION"; then
        log_info "Codex CLI v$version (>= $MIN_CODEX_VERSION)"
        CODEX_CLI_OK=true
        return 0
    else
        log_error "Codex CLI v$version 版本过旧 (需要 >= $MIN_CODEX_VERSION)"
        return 1
    fi
}

# Codex 认证检查
check_codex_auth() {
    log_info "正在检查 Codex 认证..."

    if [[ "$CODEX_CLI_OK" != true ]]; then
        log_warn "Codex CLI 未安装或版本不足，跳过"
        return 1
    fi

    if codex login status &> /dev/null; then
        log_info "Codex 认证: OK"
        return 0
    else
        log_warn "Codex 未认证: 请运行 'codex login'"
        return 1
    fi
}

# Git 版本检查（worktree 支持）
check_git_version() {
    log_info "正在检查 Git 版本..."

    if ! command -v git &> /dev/null; then
        log_error "未找到 Git"
        return 1
    fi

    local version
    version=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0")

    if version_gte "$version" "$MIN_GIT_VERSION"; then
        log_info "Git v$version (>= $MIN_GIT_VERSION, 支持 worktree)"
        return 0
    else
        log_error "Git v$version 版本过旧 (需要 >= $MIN_GIT_VERSION 以支持 worktree)"
        return 1
    fi
}

# Codex CLI 执行检查（仅 CLI）
check_codex_exec() {
    log_info "正在检查 Codex CLI 执行..."

    if [[ "$CODEX_CLI_OK" != true ]]; then
        log_warn "Codex CLI 未安装或版本不足，跳过"
        return 1
    fi

    local timeout_cmd=""
    if command -v timeout &> /dev/null; then
        timeout_cmd="timeout"
    elif command -v gtimeout &> /dev/null; then
        timeout_cmd="gtimeout"
    fi

    if [[ -z "$timeout_cmd" ]]; then
        log_warn "未找到 timeout/gtimeout（跳过 Codex CLI 执行检查）"
        return 1
    fi

    if "$timeout_cmd" 15 codex exec "echo test" >/dev/null 2>&1; then
        log_info "Codex CLI 执行: OK"
        CODEX_EXEC_OK=true
        return 0
    else
        log_warn "Codex CLI 执行检查失败（请检查认证/连接/超时）"
        return 1
    fi
}

# 配置文件生成
generate_config() {
    local config_dir=".claude/state"
    local config_file="$config_dir/codex-worker-config.json"

    log_info "正在生成配置文件..."

    if [[ "$CHECK_ONLY" == true ]]; then
        if [[ -f "$config_file" ]]; then
            log_info "配置文件: 已存在"
        else
            log_warn "配置文件: 未创建"
        fi
        return 0
    fi

    # 创建目录
    mkdir -p "$config_dir"

    # 获取 Codex 版本
    local codex_version="unknown"
    if [[ "$CODEX_CLI_OK" == true ]]; then
        codex_version=$(codex --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    fi

    # Codex 执行状态
    local codex_exec_ready="false"
    if [[ "$CODEX_EXEC_OK" == true ]]; then
        codex_exec_ready="true"
    fi

    # 生成配置文件（键名需与 common.sh 的 get_config 保持一致）
    cat > "$config_file" << EOF
{
  "codex_version": "$codex_version",
  "codex_exec_ready": $codex_exec_ready,
  "setup_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "approval_policy": "never",
  "sandbox": "workspace-write",
  "ttl_minutes": 30,
  "heartbeat_minutes": 10,
  "max_retries": 3,
  "base_branch": "",
  "gate_skip_allowlist": [],
  "require_gate_pass_for_merge": true,
  "parallel": {
    "enabled": true,
    "max_workers": 3,
    "worktree_base": "../worktrees"
  }
}
EOF

    # 安全性: 仅所有者可读写
    chmod 600 "$config_file"
    log_info "配置文件生成完成: $config_file"
}

# 主处理
main() {
    # 参数解析
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check-only)
                CHECK_ONLY=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    echo "========================================"
    echo "Codex Worker 设置"
    echo "========================================"
    echo ""

    # 执行各项检查
    check_codex_cli || true
    check_codex_auth || true
    check_git_version || true
    check_codex_exec || true
    generate_config || true

    echo ""
    echo "========================================"
    echo "结果摘要"
    echo "========================================"

    if [[ ${#ERRORS[@]} -eq 0 ]] && [[ ${#WARNINGS[@]} -eq 0 ]]; then
        echo -e "${GREEN}所有检查均已通过${NC}"
        exit 0
    fi

    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo -e "${YELLOW}警告 (${#WARNINGS[@]}):${NC}"
        for w in "${WARNINGS[@]}"; do
            echo "  - $w"
        done
    fi

    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        echo -e "${RED}错误 (${#ERRORS[@]}):${NC}"
        for e in "${ERRORS[@]}"; do
            echo "  - $e"
        done
        exit 1
    fi

    exit 0
}

main "$@"
