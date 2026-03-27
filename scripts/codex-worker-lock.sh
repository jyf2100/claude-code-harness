#!/usr/bin/env bash
#
# codex-worker-lock.sh
# 任务所有权与锁机制
#
# Usage:
#   ./scripts/codex-worker-lock.sh acquire --path PATH --worker WORKER_ID
#   ./scripts/codex-worker-lock.sh release --path PATH --worker WORKER_ID
#   ./scripts/codex-worker-lock.sh heartbeat --path PATH --worker WORKER_ID
#   ./scripts/codex-worker-lock.sh check --path PATH
#   ./scripts/codex-worker-lock.sh cleanup
#

set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载通用库
# shellcheck source=lib/codex-worker-common.sh
source "$SCRIPT_DIR/lib/codex-worker-common.sh"

# ============================================
# 本地设置（在 main 中初始化）
# ============================================
TTL_MINUTES=""
HEARTBEAT_MINUTES=""
LOCK_DIR=""  # 以绝对路径初始化
LOCK_LOG=""  # 以绝对路径初始化

# 设置初始化（在 check_dependencies 后调用）
init_lock_config() {
    validate_config || {
        log_error "配置文件无效"
        exit 1
    }
    TTL_MINUTES=$(get_config "ttl_minutes")
    HEARTBEAT_MINUTES=$(get_config "heartbeat_minutes")

    # Security: 以绝对路径固定（消除对 CWD 的依赖）
    local repo_root
    repo_root=$(get_repo_root) || exit 1
    LOCK_DIR="$repo_root/.claude/state/locks"
    LOCK_LOG="$repo_root/.claude/state/locks.log"
}

# ============================================
# 锁专用函数
# ============================================

# 验证并初始化锁目录
# Security: 防止 symlink 攻击（包含父目录）
# Note: LOCK_DIR 已在 init_lock_config() 中设置为绝对路径
init_lock_dir() {
    local repo_root
    repo_root=$(get_repo_root) || exit 1

    # 解析仓库根目录
    local real_repo_root
    real_repo_root=$(realpath "$repo_root" 2>/dev/null) || {
        log_error "无法解析仓库根目录: $repo_root"
        exit 1
    }

    # LOCK_DIR 已是绝对路径（在 init_lock_config 中设置）
    local full_lock_dir="$LOCK_DIR"

    # 父目录的 symlink 检查（Security: 验证各层级）
    local check_path="$repo_root"
    for segment in .claude state locks; do
        check_path="$check_path/$segment"
        if [[ -L "$check_path" ]]; then
            log_error "路径层级包含 symlink（出于安全考虑禁止）: $check_path"
            exit 1
        fi
    done

    # 如果目录存在，确认其在仓库内
    if [[ -e "$full_lock_dir" ]]; then
        local real_lock_dir
        real_lock_dir=$(realpath "$full_lock_dir" 2>/dev/null) || {
            log_error "无法解析锁目录: $full_lock_dir"
            exit 1
        }

        # Security: 区分 /repo 和 /repo2
        if [[ "$real_lock_dir" != "$real_repo_root" && "$real_lock_dir" != "$real_repo_root/"* ]]; then
            log_error "锁目录位于仓库外: $real_lock_dir"
            exit 1
        fi
    fi

    # 创建目录（Security: 700 权限）
    mkdir -p "$full_lock_dir"
    chmod 700 "$full_lock_dir"
}

# 生成锁键（SHA256 前8位）
generate_lock_key() {
    local path="$1"
    local normalized
    normalized=$(normalize_path "$path")
    calculate_sha256 "$normalized" 8
}

# 获取锁文件路径
get_lock_file() {
    local path="$1"
    local key
    key=$(generate_lock_key "$path")
    printf '%s/%s.lock.json' "$LOCK_DIR" "$key"
}

# 一次性读取锁文件的多个字段（性能优化）
# Usage: read_lock_fields "$lock_file" worker heartbeat path
# Returns: 制表符分隔的值
read_lock_fields() {
    local lock_file="$1"
    shift
    local fields=("$@")

    if [[ ! -f "$lock_file" ]]; then
        return 1
    fi

    # 使用单次 jq 调用获取多个字段
    local jq_filter
    jq_filter=$(printf '.%s, ' "${fields[@]}")
    jq_filter="${jq_filter%, }"  # 删除末尾逗号

    jq -r "[$jq_filter] | @tsv" "$lock_file"
}

# 记录日志
log_event() {
    local event="$1"
    local path="$2"
    local worker="$3"
    mkdir -p "$(dirname "$LOCK_LOG")"
    printf '%s\t%s\t%s\t%s\n' "$(now_utc)" "$event" "$path" "$worker" >> "$LOCK_LOG"
}

# 获取锁
cmd_acquire() {
    local path=""
    local worker=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                if [[ -z "${2:-}" ]]; then
                    log_error "--path 需要值"
                    exit 1
                fi
                path="$2"; shift 2 ;;
            --worker)
                if [[ -z "${2:-}" ]]; then
                    log_error "--worker 需要值"
                    exit 1
                fi
                worker="$2"; shift 2 ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [[ -z "$path" ]] || [[ -z "$worker" ]]; then
        log_error "--path 和 --worker 为必选项"
        exit 1
    fi

    # Security: 路径验证
    if ! validate_repo_path "$path"; then
        exit 1
    fi

    # Security: 锁目录验证
    init_lock_dir

    local lock_file
    lock_file=$(get_lock_file "$path")
    local normalized_path
    normalized_path=$(normalize_path "$path")

    # 检查现有锁（性能优化: 使用1次 jq 获取多个字段）
    if [[ -f "$lock_file" ]]; then
        local lock_data
        lock_data=$(read_lock_fields "$lock_file" worker heartbeat) || {
            log_warn "读取锁文件失败: $lock_file"
            rm -f "$lock_file"
        }

        local existing_worker
        local heartbeat
        existing_worker=$(echo "$lock_data" | cut -f1)
        heartbeat=$(echo "$lock_data" | cut -f2)

        # TTL 检查
        local heartbeat_epoch
        local now_epoch
        local ttl_seconds=$((TTL_MINUTES * 60))

        heartbeat_epoch=$(parse_utc_to_epoch "$heartbeat")
        now_epoch=$(date "+%s")

        if (( now_epoch - heartbeat_epoch > ttl_seconds )); then
            log_warn "TTL 超时: 释放现有锁 (worker=$existing_worker)"
            log_event "expired" "$normalized_path" "$existing_worker"
            rm -f "$lock_file"
        else
            log_error "获取锁失败: $normalized_path 正被 $existing_worker 锁定"
            exit 1
        fi
    fi

    # 创建新锁（原子创建）
    local now
    now=$(now_utc)

    # Security: 仅允许所有者读写的权限创建
    local tmp_file
    tmp_file=$(mktemp "$LOCK_DIR/tmp.XXXXXX")
    jq -n \
        --arg path "$normalized_path" \
        --arg worker "$worker" \
        --arg acquired "$now" \
        --arg heartbeat "$now" \
        '{
            path: $path,
            worker: $worker,
            acquired: $acquired,
            heartbeat: $heartbeat
        }' > "$tmp_file"
    chmod 600 "$tmp_file"

    # 使用 ln 进行原子放置（如文件已存在则失败）
    if ! ln "$tmp_file" "$lock_file" 2>/dev/null; then
        rm -f "$tmp_file"
        log_error "获取锁失败: $normalized_path 正被其他 Worker 锁定（竞争）"
        exit 1
    fi

    chmod 600 "$lock_file"
    rm -f "$tmp_file"
    log_event "acquire" "$normalized_path" "$worker"
    log_info "获取锁: $normalized_path (worker=$worker)"
}

# 释放锁
cmd_release() {
    local path=""
    local worker=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                if [[ -z "${2:-}" ]]; then
                    log_error "--path 需要值"
                    exit 1
                fi
                path="$2"; shift 2 ;;
            --worker)
                if [[ -z "${2:-}" ]]; then
                    log_error "--worker 需要值"
                    exit 1
                fi
                worker="$2"; shift 2 ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [[ -z "$path" ]] || [[ -z "$worker" ]]; then
        log_error "--path 和 --worker 为必选项"
        exit 1
    fi

    # Security: 路径验证
    if ! validate_repo_path "$path"; then
        exit 1
    fi

    local lock_file
    lock_file=$(get_lock_file "$path")
    local normalized_path
    normalized_path=$(normalize_path "$path")

    if [[ ! -f "$lock_file" ]]; then
        log_warn "锁不存在: $normalized_path"
        exit 0
    fi

    local existing_worker
    existing_worker=$(jq -r '.worker' "$lock_file")

    if [[ "$existing_worker" != "$worker" ]]; then
        log_error "释放锁失败: $normalized_path 是 $existing_worker 的锁"
        exit 1
    fi

    rm -f "$lock_file"
    log_event "release" "$normalized_path" "$worker"
    log_info "释放锁: $normalized_path (worker=$worker)"
}

# 更新心跳
cmd_heartbeat() {
    local path=""
    local worker=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                if [[ -z "${2:-}" ]]; then
                    log_error "--path 需要值"
                    exit 1
                fi
                path="$2"; shift 2 ;;
            --worker)
                if [[ -z "${2:-}" ]]; then
                    log_error "--worker 需要值"
                    exit 1
                fi
                worker="$2"; shift 2 ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [[ -z "$path" ]] || [[ -z "$worker" ]]; then
        log_error "--path 和 --worker 为必选项"
        exit 1
    fi

    # Security: 路径验证
    if ! validate_repo_path "$path"; then
        exit 1
    fi

    local lock_file
    lock_file=$(get_lock_file "$path")
    local normalized_path
    normalized_path=$(normalize_path "$path")

    if [[ ! -f "$lock_file" ]]; then
        log_error "锁不存在: $normalized_path"
        exit 1
    fi

    local existing_worker
    existing_worker=$(jq -r '.worker' "$lock_file")

    if [[ "$existing_worker" != "$worker" ]]; then
        log_error "更新心跳失败: $normalized_path 是 $existing_worker 的锁"
        exit 1
    fi

    local now
    now=$(now_utc)

    jq --arg heartbeat "$now" '.heartbeat = $heartbeat' "$lock_file" > "$lock_file.tmp"
    # Security: 维持权限
    chmod 600 "$lock_file.tmp"
    mv "$lock_file.tmp" "$lock_file"

    log_info "更新心跳: $normalized_path (worker=$worker)"
}

# 检查锁状态
cmd_check() {
    local path=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                if [[ -z "${2:-}" ]]; then
                    log_error "--path 需要值"
                    exit 1
                fi
                path="$2"; shift 2 ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [[ -z "$path" ]]; then
        log_error "--path 为必选项"
        exit 1
    fi

    # Security: 路径验证
    if ! validate_repo_path "$path"; then
        exit 1
    fi

    local lock_file
    lock_file=$(get_lock_file "$path")
    local normalized_path
    normalized_path=$(normalize_path "$path")

    if [[ ! -f "$lock_file" ]]; then
        echo '{"locked": false}'
        exit 0
    fi

    local worker
    local heartbeat
    worker=$(jq -r '.worker' "$lock_file")
    heartbeat=$(jq -r '.heartbeat' "$lock_file")

    # TTL 检查
    local heartbeat_epoch
    local now_epoch
    local ttl_seconds=$((TTL_MINUTES * 60))

    heartbeat_epoch=$(parse_utc_to_epoch "$heartbeat")
    now_epoch=$(date "+%s")

    if (( now_epoch - heartbeat_epoch > ttl_seconds )); then
        # TTL 超时: 只读（删除操作在 acquire/cleanup 中进行）
        echo '{"locked": false, "expired": true, "hint": "run cleanup or acquire to release"}'
    else
        jq -c '. + {locked: true}' "$lock_file"
    fi
}

# 清理过期锁
cmd_cleanup() {
    # Security: 锁目录验证
    init_lock_dir

    local cleaned=0
    local now_epoch
    now_epoch=$(date "+%s")
    local ttl_seconds=$((TTL_MINUTES * 60))

    for lock_file in "$LOCK_DIR"/*.lock.json; do
        [[ -f "$lock_file" ]] || continue

        # 性能优化: 使用1次 jq 获取多个字段
        local lock_data
        lock_data=$(read_lock_fields "$lock_file" heartbeat worker path) || continue

        local heartbeat
        local worker
        local path
        heartbeat=$(echo "$lock_data" | cut -f1)
        worker=$(echo "$lock_data" | cut -f2)
        path=$(echo "$lock_data" | cut -f3)

        local heartbeat_epoch
        heartbeat_epoch=$(parse_utc_to_epoch "$heartbeat")

        if (( now_epoch - heartbeat_epoch > ttl_seconds )); then
            log_warn "TTL 超时: $path (worker=$worker)"
            log_event "expired" "$path" "$worker"
            rm -f "$lock_file"
            cleaned=$((cleaned + 1))
        fi
    done

    log_info "清理完成: 释放了 $cleaned 个锁"
}

# 使用方法
usage() {
    cat << EOF
Usage: $0 COMMAND [OPTIONS]

Commands:
  acquire   --path PATH --worker WORKER_ID   获取锁
  release   --path PATH --worker WORKER_ID   释放锁
  heartbeat --path PATH --worker WORKER_ID   更新心跳
  check     --path PATH                      检查锁状态
  cleanup                                    清理过期锁

Options:
  --path PATH       目标文件路径
  --worker WORKER_ID Worker 标识符

Settings:
  TTL: $TTL_MINUTES 分钟
  心跳间隔: $HEARTBEAT_MINUTES 分钟
  锁目录: $LOCK_DIR

Examples:
  $0 acquire --path src/auth/login.ts --worker worker-1
  $0 heartbeat --path src/auth/login.ts --worker worker-1
  $0 release --path src/auth/login.ts --worker worker-1
  $0 check --path src/auth/login.ts
  $0 cleanup
EOF
}

# 主处理
main() {
    check_dependencies
    init_lock_config

    if [[ $# -eq 0 ]]; then
        usage
        exit 0
    fi

    local cmd="$1"
    shift

    case "$cmd" in
        acquire)   cmd_acquire "$@" ;;
        release)   cmd_release "$@" ;;
        heartbeat) cmd_heartbeat "$@" ;;
        check)     cmd_check "$@" ;;
        cleanup)   cmd_cleanup ;;
        -h|--help) usage; exit 0 ;;
        *)
            log_error "Unknown command: $cmd"
            usage
            exit 1
            ;;
    esac
}

main "$@"
