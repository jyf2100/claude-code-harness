#!/usr/bin/env bash
#
# codex-worker-common.sh
# Codex Worker 脚本通用库
#
# Usage: source "$SCRIPT_DIR/lib/codex-worker-common.sh"
#

# 防止重复加载
if [[ -n "${_CODEX_WORKER_COMMON_LOADED:-}" ]]; then
    return 0
fi
_CODEX_WORKER_COMMON_LOADED=1

# ============================================
# 颜色定义
# ============================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# ============================================
# 日志函数
# ============================================
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_gate() { echo -e "${BLUE}[GATE]${NC} $1"; }
log_merge() { echo -e "${BLUE}[MERGE]${NC} $1"; }

# ============================================
# 时间函数
# ============================================

# ISO8601 UTC 当前时间
now_utc() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

# ISO8601 UTC 转换为 epoch 秒（macOS/Linux 兼容）
parse_utc_to_epoch() {
    local ts="$1"
    local ts_no_z="${ts%Z}"

    # macOS (BSD date)
    if date -u -j -f "%Y-%m-%dT%H:%M:%S" "$ts_no_z" "+%s" 2>/dev/null; then
        return 0
    fi

    # Linux (GNU date)
    if date -u -d "$ts" "+%s" 2>/dev/null; then
        return 0
    fi

    # 回退方案
    echo 0
}

# ============================================
# 哈希计算（跨平台）
# ============================================

# SHA256 哈希计算
# Usage:
#   calculate_sha256 "input string" [chars]   # 从参数
#   echo "input" | calculate_sha256 "" [chars] # 从 stdin
calculate_sha256() {
    local input="${1:-}"
    local chars="${2:-64}"  # 默认: 全部 64 字符

    # shasum (macOS / Linux with coreutils)
    if command -v shasum &>/dev/null; then
        if [[ -n "$input" ]]; then
            printf '%s' "$input" | shasum -a 256 | cut -c1-"$chars"
        else
            shasum -a 256 | cut -c1-"$chars"
        fi
        return 0
    fi

    # sha256sum (Linux)
    if command -v sha256sum &>/dev/null; then
        if [[ -n "$input" ]]; then
            printf '%s' "$input" | sha256sum | cut -c1-"$chars"
        else
            sha256sum | cut -c1-"$chars"
        fi
        return 0
    fi

    log_error "未找到 SHA256 命令 (shasum / sha256sum)"
    return 1
}

# 文件的 SHA256 哈希计算（含 BOM/CR 标准化）
calculate_file_hash() {
    local file="$1"
    local chars="${2:-8}"  # 默认: 前 8 字符

    if [[ ! -f "$file" ]]; then
        log_error "文件不存在: $file"
        return 1
    fi

    # BOM 移除 + CR 移除 + SHA256（跨平台）
    local content
    content=$(sed '1s/^\xEF\xBB\xBF//' "$file" | tr -d '\r')

    # shasum (macOS / Linux with coreutils)
    if command -v shasum &>/dev/null; then
        printf '%s' "$content" | shasum -a 256 | cut -c1-"$chars"
        return 0
    fi

    # sha256sum (Linux)
    if command -v sha256sum &>/dev/null; then
        printf '%s' "$content" | sha256sum | cut -c1-"$chars"
        return 0
    fi

    log_error "未找到 SHA256 命令"
    return 1
}

# ============================================
# 路径验证（安全强化）
# ============================================

# 获取仓库根目录
get_repo_root() {
    git rev-parse --show-toplevel 2>/dev/null || {
        log_error "不在 Git 仓库内"
        return 1
    }
}

# 验证路径是否在仓库内
# Security: 防止 symlink 攻击
# Note: 即使文件不存在，只要父目录存在即可验证
# Note: worktree 等 repo 外路径请使用 validate_worktree_path()
validate_repo_path() {
    local path="$1"
    local repo_root

    repo_root=$(get_repo_root) || return 1

    # 空路径检查
    if [[ -z "$path" ]]; then
        log_error "路径为空"
        return 1
    fi

    # 将路径解析为实际路径
    local real_path
    local target_path

    if [[ "$path" == /* ]]; then
        target_path="$path"
    else
        target_path="$repo_root/$path"
    fi

    # 文件/目录存在时直接解析
    if [[ -e "$target_path" ]]; then
        real_path=$(realpath "$target_path" 2>/dev/null) || {
            log_error "无法解析路径: $path"
            return 1
        }
    else
        # 不存在时解析父目录并添加 basename
        local parent_dir
        local base_name
        parent_dir=$(dirname "$target_path")
        base_name=$(basename "$target_path")

        # 确认父目录是否存在
        if [[ -d "$parent_dir" ]]; then
            local real_parent
            real_parent=$(realpath "$parent_dir" 2>/dev/null) || {
                log_error "无法解析父目录: $parent_dir"
                return 1
            }
            real_path="$real_parent/$base_name"
        else
            # 父目录也不存在时，仅进行逻辑路径验证
            # 转换为绝对路径并确认相对于 repo_root 的位置
            real_path=$(cd "$repo_root" && realpath -m "$path" 2>/dev/null) || {
                # realpath -m 不存在的环境（部分 BSD）的回退方案
                real_path="$repo_root/$path"
            }
        fi
    fi

    # 同时解析仓库根目录
    local real_repo_root
    real_repo_root=$(realpath "$repo_root" 2>/dev/null) || real_repo_root="$repo_root"

    # 确认实际路径是否在仓库内（Security: 为区分 /repo 和 /repo2，比较时包含 /）
    if [[ "$real_path" != "$real_repo_root" && "$real_path" != "$real_repo_root/"* ]]; then
        log_error "仓库外的路径: $path (resolved: $real_path)"
        return 1
    fi

    return 0
}

# worktree 路径验证
# Note: worktree 通常位于 repo 外（如 ../worktrees），因此不进行 repo 内限制
# 而是通过 git worktree list 验证是同一仓库的 worktree
validate_worktree_path() {
    local worktree="$1"

    # 空路径检查
    if [[ -z "$worktree" ]]; then
        log_error "worktree 路径为空"
        return 1
    fi

    # 目录存在确认
    if [[ ! -d "$worktree" ]]; then
        log_error "worktree 目录不存在: $worktree"
        return 1
    fi

    # 确认是否为 Git 仓库
    if ! (cd "$worktree" && git rev-parse --show-toplevel >/dev/null 2>&1); then
        log_error "worktree 不是 Git 仓库: $worktree"
        return 1
    fi

    # 确认是否为同一仓库的 worktree（精确匹配）
    local worktree_abs
    worktree_abs=$(cd "$worktree" && pwd)

    # 使用 git worktree list --porcelain 进行精确匹配
    local found=false
    while IFS= read -r line; do
        if [[ "$line" == "worktree $worktree_abs" ]]; then
            found=true
            break
        fi
    done < <(git worktree list --porcelain 2>/dev/null)

    if [[ "$found" != "true" ]]; then
        log_error "指定路径不是此仓库的 worktree: $worktree"
        log_error "请通过 git worktree list 确认"
        return 1
    fi

    return 0
}

# 路径标准化（移除 ./、转换 \ → /）
normalize_path() {
    local path="$1"
    path="${path#./}"
    path="${path//\\//}"
    printf '%s' "$path"
}

# ============================================
# 配置文件管理
# ============================================

# 配置文件路径
readonly CONFIG_FILE="${CONFIG_FILE:-.claude/state/codex-worker-config.json}"

# 默认配置（Security: fail-closed defaults）
declare -A CONFIG_DEFAULTS=(
    [ttl_minutes]="30"
    [heartbeat_minutes]="10"
    [max_retries]="3"
    [approval_policy]="never"
    [sandbox]="workspace-write"
    [base_branch]=""
    [require_gate_pass_for_merge]="true"  # Security: default to true
    [gate_skip_allowlist]="[]"
)

# 获取配置值
get_config() {
    local key="$1"
    local default="${CONFIG_DEFAULTS[$key]:-}"

    # 配置文件不存在时使用默认值
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "$default"
        return 0
    fi

    # 通过 jq 获取值，否则使用默认值
    local value
    value=$(jq -r --arg key "$key" '.[$key] // empty' "$CONFIG_FILE" 2>/dev/null)

    if [[ -n "$value" && "$value" != "null" ]]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# 读取整个配置文件
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        cat "$CONFIG_FILE"
    else
        echo '{}'
    fi
}

# 配置文件验证（基于 schema）
# Returns: 0 if valid, 1 if invalid
validate_config() {
    local config_file="${1:-$CONFIG_FILE}"

    if [[ ! -f "$config_file" ]]; then
        # 配置文件不存在时使用默认值，因此 valid
        return 0
    fi

    # JSON 语法检查
    if ! jq empty "$config_file" 2>/dev/null; then
        log_error "配置文件是无效的 JSON: $config_file"
        return 1
    fi

    # 必填字段的类型检查（基本验证）
    local validation_errors=()

    # ttl_minutes: integer, 1-1440
    local ttl
    ttl=$(jq -r '.ttl_minutes // empty' "$config_file")
    if [[ -n "$ttl" ]] && ! [[ "$ttl" =~ ^[0-9]+$ && "$ttl" -ge 1 && "$ttl" -le 1440 ]]; then
        validation_errors+=("ttl_minutes must be integer 1-1440")
    fi

    # max_retries: integer, 1-10
    local retries
    retries=$(jq -r '.max_retries // empty' "$config_file")
    if [[ -n "$retries" ]] && ! [[ "$retries" =~ ^[0-9]+$ && "$retries" -ge 1 && "$retries" -le 10 ]]; then
        validation_errors+=("max_retries must be integer 1-10")
    fi

    # approval_policy: enum
    local policy
    policy=$(jq -r '.approval_policy // empty' "$config_file")
    if [[ -n "$policy" ]] && ! [[ "$policy" =~ ^(untrusted|on-failure|on-request|never)$ ]]; then
        validation_errors+=("approval_policy must be one of: untrusted, on-failure, on-request, never")
    fi

    # sandbox: enum
    local sandbox
    sandbox=$(jq -r '.sandbox // empty' "$config_file")
    if [[ -n "$sandbox" ]] && ! [[ "$sandbox" =~ ^(read-only|workspace-write|danger-full-access)$ ]]; then
        validation_errors+=("sandbox must be one of: read-only, workspace-write, danger-full-access")
    fi

    # require_gate_pass_for_merge: boolean
    local gate_pass
    gate_pass=$(jq -r '.require_gate_pass_for_merge // empty' "$config_file")
    if [[ -n "$gate_pass" ]] && ! [[ "$gate_pass" =~ ^(true|false)$ ]]; then
        validation_errors+=("require_gate_pass_for_merge must be boolean")
    fi

    if [[ ${#validation_errors[@]} -gt 0 ]]; then
        log_error "配置文件验证错误:"
        for err in "${validation_errors[@]}"; do
            log_error "  - $err"
        done
        return 1
    fi

    return 0
}

# ============================================
# 依赖命令检查
# ============================================

# 确认必需命令是否存在
# 无参数时检查默认的依赖命令
check_dependencies() {
    local commands=("$@")
    local missing=()

    # 无参数时设置默认的依赖命令
    if [[ ${#commands[@]} -eq 0 ]]; then
        commands=("git" "jq")
        # SHA256 命令只要有 shasum 或 sha256sum 其中之一即可
        if ! command -v shasum &>/dev/null && ! command -v sha256sum &>/dev/null; then
            missing+=("shasum or sha256sum")
        fi
    fi

    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "未找到必需命令: ${missing[*]}"
        return 1
    fi

    return 0
}

# ============================================
# 包管理器检测
# ============================================

# 检测项目的包管理器
detect_package_manager() {
    local project_dir="${1:-.}"
    local pkg_json="$project_dir/package.json"

    # 1. package.json 的 packageManager 字段
    if [[ -f "$pkg_json" ]]; then
        local pm
        pm=$(jq -r '.packageManager // empty' "$pkg_json" 2>/dev/null | cut -d@ -f1)
        if [[ -n "$pm" ]]; then
            echo "$pm"
            return 0
        fi
    fi

    # 2. 通过 lock 文件判定
    if [[ -f "$project_dir/pnpm-lock.yaml" ]]; then
        echo "pnpm"
    elif [[ -f "$project_dir/yarn.lock" ]]; then
        echo "yarn"
    elif [[ -f "$project_dir/bun.lockb" ]]; then
        echo "bun"
    elif [[ -f "$project_dir/package-lock.json" ]]; then
        echo "npm"
    else
        # 默认
        echo "npm"
    fi
}

# 包管理器的 run 命令
get_pm_run_command() {
    local pm="${1:-npm}"

    case "$pm" in
        npm)  echo "npm run" ;;
        pnpm) echo "pnpm run" ;;
        yarn) echo "yarn" ;;
        bun)  echo "bun run" ;;
        *)    echo "npm run" ;;
    esac
}

# ============================================
# 基础分支获取
# ============================================

# 获取默认分支
get_default_branch() {
    local config_branch
    config_branch=$(get_config "base_branch")

    # 1. 配置文件中指定时
    if [[ -n "$config_branch" ]]; then
        echo "$config_branch"
        return 0
    fi

    # 2. 从 Git 的 symbolic-ref 获取
    local remote_head
    remote_head=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')

    if [[ -n "$remote_head" ]]; then
        echo "$remote_head"
        return 0
    fi

    # 3. 回退方案
    echo "main"
}

# ============================================
# Worktree 元数据管理
# ============================================

readonly WORKTREE_META_FILE=".codex-worker-meta.json"

# 保存元数据
save_worktree_meta() {
    local worktree="$1"
    local task_id="$2"
    local owns="$3"
    local target_branch="$4"

    local meta_file="$worktree/$WORKTREE_META_FILE"

    jq -n \
        --arg task_id "$task_id" \
        --arg owns "$owns" \
        --arg target_branch "$target_branch" \
        --arg gate_status "pending" \
        --arg created_at "$(now_utc)" \
        '{
            task_id: $task_id,
            owns: $owns,
            target_branch: $target_branch,
            gate_status: $gate_status,
            created_at: $created_at
        }' > "$meta_file"

    # 权限设置（Security）
    chmod 600 "$meta_file"
}

# 读取元数据
load_worktree_meta() {
    local worktree="$1"
    local meta_file="$worktree/$WORKTREE_META_FILE"

    if [[ -f "$meta_file" ]]; then
        cat "$meta_file"
    else
        echo '{}'
    fi
}

# 更新元数据
update_worktree_meta() {
    local worktree="$1"
    local key="$2"
    local value="$3"

    local meta_file="$worktree/$WORKTREE_META_FILE"

    if [[ ! -f "$meta_file" ]]; then
        log_error "元数据不存在: $meta_file"
        return 1
    fi

    local tmp_file
    tmp_file=$(mktemp)

    jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$meta_file" > "$tmp_file"
    mv "$tmp_file" "$meta_file"
    chmod 600 "$meta_file"
}

# ============================================
# Gate 结果管理（Security: 在 worktree 外集中管理）
# ============================================

readonly GATE_RESULTS_DIR=".claude/state/gates"

# 保存 Gate 结果（为防止 Worker 篡改而保存在 worktree 外）
# Usage: save_gate_result "$worktree" "$status" "$details"
# Note: 不依赖 CWD，从 worktree 解析中央仓库
save_gate_result() {
    local worktree="$1"
    local status="$2"
    local details="${3:-}"

    # 从 worktree 解析中央仓库根目录（消除 CWD 依赖）
    local repo_root
    repo_root=$(cd "$worktree" && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/.git$||') || {
        # 回退: 使用当前的 repo root
        repo_root=$(get_repo_root) || return 1
    }

    # 获取 worktree 的 HEAD commit hash
    local head_commit
    head_commit=$(cd "$worktree" && git rev-parse HEAD 2>/dev/null) || {
        log_error "无法获取 worktree 的 HEAD: $worktree"
        return 1
    }

    # 创建 Gate 结果目录
    local gate_dir="$repo_root/$GATE_RESULTS_DIR"
    mkdir -p "$gate_dir"
    chmod 700 "$gate_dir"

    # 结果文件（通过 commit hash 识别）
    local result_file="$gate_dir/${head_commit}.json"

    jq -n \
        --arg worktree "$(basename "$worktree")" \
        --arg head "$head_commit" \
        --arg status "$status" \
        --arg details "$details" \
        --arg verified_at "$(now_utc)" \
        '{
            worktree: $worktree,
            head: $head,
            status: $status,
            details: $details,
            verified_at: $verified_at
        }' > "$result_file"

    chmod 600 "$result_file"
    log_info "Gate 结果已保存: $result_file (status=$status)"
}

# 验证 Gate 结果（merge 时使用）
# Usage: verify_gate_result "$worktree"
# Returns: 0 if passed, 1 if not passed or not found
# Note: 不依赖 CWD，从 worktree 解析中央仓库
verify_gate_result() {
    local worktree="$1"

    # 从 worktree 解析中央仓库根目录（消除 CWD 依赖）
    local repo_root
    repo_root=$(cd "$worktree" && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/.git$||') || {
        # 回退: 使用当前的 repo root
        repo_root=$(get_repo_root) || return 1
    }

    # 获取 worktree 的 HEAD commit hash
    local head_commit
    head_commit=$(cd "$worktree" && git rev-parse HEAD 2>/dev/null) || {
        log_error "无法获取 worktree 的 HEAD: $worktree"
        return 1
    }

    # Gate 结果文件
    local result_file="$repo_root/$GATE_RESULTS_DIR/${head_commit}.json"

    if [[ ! -f "$result_file" ]]; then
        log_error "未找到 Gate 结果: $result_file"
        log_error "请执行质量 Gate: ./scripts/codex-worker-quality-gate.sh --worktree $worktree"
        return 1
    fi

    # 状态确认
    local status
    status=$(jq -r '.status' "$result_file" 2>/dev/null)

    if [[ "$status" == "passed" ]]; then
        log_info "Gate 结果验证通过: commit=$head_commit, status=$status"
        return 0
    else
        log_error "Gate 未通过: commit=$head_commit, status=$status"
        return 1
    fi
}

# ============================================
# 文件权限管理（Security）
# ============================================

# 安全文件创建
create_secure_file() {
    local file="$1"
    local content="${2:-}"

    # 创建目录
    mkdir -p "$(dirname "$file")"

    # 使用 umask 077 创建（仅本人可读写）
    (
        umask 077
        if [[ -n "$content" ]]; then
            printf '%s' "$content" > "$file"
        else
            touch "$file"
        fi
    )
}

# 创建临时文件（通过 trap 自动删除，保留现有 trap）
create_temp_file() {
    local prefix="${1:-codex-worker}"
    local tmp_file

    tmp_file=$(mktemp "/tmp/${prefix}.XXXXXX")

    # 保留现有的 EXIT trap 并追加
    local prev_trap
    prev_trap=$(trap -p EXIT 2>/dev/null | sed "s/trap -- '\\(.*\\)' EXIT/\\1/" || echo "")

    # shellcheck disable=SC2064  # 故意用当前值设置 trap
    if [[ -n "$prev_trap" ]]; then
        trap "rm -f '$tmp_file'; $prev_trap" EXIT
    else
        trap "rm -f '$tmp_file'" EXIT
    fi

    echo "$tmp_file"
}

# ============================================
# 初始化
# ============================================

# 获取脚本目录的辅助函数
get_script_dir() {
    local source="${BASH_SOURCE[1]:-$0}"
    local dir
    dir=$(cd "$(dirname "$source")" && pwd)
    echo "$dir"
}
