#!/usr/bin/env bash
#
# codex-worker-merge.sh
# Worker 成果物合并集成
#
# Usage:
#   ./scripts/codex-worker-merge.sh --worktree PATH --target-branch BRANCH [--squash] [--dry-run]
#

set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载通用库
# shellcheck source=lib/codex-worker-common.sh
source "$SCRIPT_DIR/lib/codex-worker-common.sh"

# 更新 Plans.md
# Note: 为消除 CWD 依赖，使用从仓库根目录开始的绝对路径
update_plans() {
    local task_pattern="$1"
    local repo_root
    repo_root=$(get_repo_root) || return 1
    local plans_file="$repo_root/Plans.md"

    if [[ ! -f "$plans_file" ]]; then
        log_warn "Plans.md 未找到: $plans_file"
        return 1
    fi

    # cc:WIP → cc:done, [ ] → [x]
    if grep -q "$task_pattern" "$plans_file"; then
        sed -i.bak "s/\(.*$task_pattern.*\)cc:WIP/\1cc:done/" "$plans_file"
        sed -i.bak "s/\(.*$task_pattern.*\)\[ \]/\1[x]/" "$plans_file"
        rm -f "$plans_file.bak"
        log_info "Plans.md 更新: $task_pattern → cc:done"
        return 0
    fi

    return 1
}

# cherry-pick 合并
do_cherry_pick() {
    local commit_hash="$1"
    local dry_run="$2"

    log_merge "cherry-pick: $commit_hash"

    if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY-RUN] git cherry-pick $commit_hash"
        return 0
    fi

    if git cherry-pick "$commit_hash" 2>/dev/null; then
        return 0
    else
        # 发生冲突
        git cherry-pick --abort 2>/dev/null || true
        return 1
    fi
}

# squash 合并
do_squash_merge() {
    local worktree="$1"
    local dry_run="$2"

    # 获取 worktree 的分支名
    local branch_name
    branch_name=$(cd "$worktree" && git branch --show-current)

    log_merge "squash merge: $branch_name"

    if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY-RUN] git merge --squash $branch_name"
        return 0
    fi

    if git merge --squash "$branch_name" 2>/dev/null; then
        git commit -m "feat: Worker 成果物合并 ($branch_name)"
        return 0
    else
        git merge --abort 2>/dev/null || true
        return 1
    fi
}

# 主处理
main() {
    check_dependencies

    local worktree=""
    local target_branch=""
    local squash=false
    local dry_run=false
    local force=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --worktree)
                if [[ -z "${2:-}" ]]; then
                    log_error "--worktree 需要提供值"
                    exit 1
                fi
                worktree="$2"; shift 2 ;;
            --target-branch)
                if [[ -z "${2:-}" ]]; then
                    log_error "--target-branch 需要提供值"
                    exit 1
                fi
                target_branch="$2"; shift 2 ;;
            --squash) squash=true; shift ;;
            --dry-run) dry_run=true; shift ;;
            --force) force=true; shift ;;
            -h|--help) usage; exit 0 ;;
            *) log_error "未知选项: $1"; exit 1 ;;
        esac
    done

    # 获取默认分支
    if [[ -z "$target_branch" ]]; then
        target_branch=$(get_default_branch)
    fi

    # 必需参数检查
    if [[ -z "$worktree" ]]; then
        log_error "--worktree 为必需参数"
        exit 1
    fi

    if [[ ! -d "$worktree" ]]; then
        log_error "Worktree 不存在: $worktree"
        exit 1
    fi

    # Security: 验证是否为同一仓库的 worktree（使用通用函数）
    if ! validate_worktree_path "$worktree"; then
        exit 1
    fi

    # Quality: 确认 worktree 的工作区是否干净
    local worktree_status
    worktree_status=$(cd "$worktree" && git status --porcelain 2>/dev/null)
    if [[ -n "$worktree_status" ]]; then
        log_warn "worktree 中存在未提交的更改:"
        echo "$worktree_status" | head -5
        if [[ "$force" != "true" ]]; then
            log_error "存在未提交的更改，已中断。可使用 --force 跳过"
            echo '{"status": "blocked", "reason": "uncommitted_changes"}'
            exit 1
        fi
        log_warn "⚠️ 忽略未提交的更改，继续合并"
    fi

    # Security: 确认质量门通过（验证中央管理的门结果）
    local require_gate_pass
    require_gate_pass=$(get_config "require_gate_pass_for_merge")

    if [[ "$require_gate_pass" == "true" ]]; then
        # verify_gate_result 验证 worktree 的 HEAD 提交对应的门结果
        # 引用 Worker 无法篡改的中央管理结果文件
        if ! verify_gate_result "$worktree"; then
            log_error "请先通过质量门后再合并"
            log_error "可使用 --force 选项跳过，但不推荐"

            if [[ "$force" != "true" ]]; then
                echo '{"status": "blocked", "reason": "gate_not_passed"}'
                exit 1
            fi
            log_warn "⚠️ 质量门未通过，强制执行合并"
        fi
    fi

    # 获取 worktree 的最新提交
    local commit_hash
    commit_hash=$(cd "$worktree" && git log -1 --format="%H")

    if [[ -z "$commit_hash" ]]; then
        log_error "未找到提交"
        echo '{"status": "failed", "commit_hash": null, "conflicts": [], "plans_updated": false}'
        exit 1
    fi

    log_info "Worker 提交: $commit_hash"

    # 确认当前分支
    local current_branch
    current_branch=$(git branch --show-current)

    # 验证目标分支
    if ! git check-ref-format --branch "$target_branch" 2>/dev/null; then
        log_error "无效的分支名: $target_branch"
        echo '{"status": "failed", "commit_hash": null, "conflicts": ["invalid branch name"], "plans_updated": false}'
        exit 1
    fi

    # 切换到目标分支
    if [[ "$current_branch" != "$target_branch" ]]; then
        if [[ "$dry_run" == "false" ]]; then
            git switch "$target_branch"
        else
            log_info "[DRY-RUN] git switch $target_branch"
        fi
    fi

    # 执行合并
    local merge_status="merged"
    local conflicts=()

    if [[ "$squash" == "true" ]]; then
        if ! do_squash_merge "$worktree" "$dry_run"; then
            merge_status="conflict"
            conflicts+=("squash merge failed")
        fi
    else
        if ! do_cherry_pick "$commit_hash" "$dry_run"; then
            merge_status="conflict"
            conflicts+=("cherry-pick failed")
        fi
    fi

    # 更新 Plans.md
    local plans_updated=false
    if [[ "$merge_status" == "merged" ]] && [[ "$dry_run" == "false" ]]; then
        # 从 worktree 名推测任务 ID（worker-1 → task-1 等）
        local worker_id
        worker_id=$(basename "$worktree" | sed 's/worker-//')

        if update_plans "task-$worker_id\|Task $worker_id" 2>/dev/null; then
            plans_updated=true
        fi
    fi

    # 输出结果
    local conflicts_json
    conflicts_json=$(printf '%s\n' "${conflicts[@]:-}" | jq -R -s -c 'split("\n") | map(select(length > 0))')

    local result
    result=$(jq -n \
        --arg status "$merge_status" \
        --arg commit_hash "$commit_hash" \
        --argjson conflicts "$conflicts_json" \
        --argjson plans_updated "$plans_updated" \
        '{
            status: $status,
            commit_hash: $commit_hash,
            conflicts: $conflicts,
            plans_updated: $plans_updated
        }')

    echo "$result"

    # 返回原分支（合并后）
    if [[ "$dry_run" == "false" ]] && [[ -n "$current_branch" ]] && [[ "$current_branch" != "$target_branch" ]]; then
        git switch "$current_branch" 2>/dev/null || log_warn "无法返回原分支: $current_branch"
    fi

    # 退出码
    if [[ "$merge_status" == "merged" ]]; then
        exit 0
    else
        exit 1
    fi
}

# 使用方法
usage() {
    cat << EOF
Usage: $0 --worktree PATH [OPTIONS]

Options:
  --worktree PATH         Worker 的 worktree 路径（必需）
  --target-branch BRANCH  合并目标分支（默认: main）
  --squash                使用 squash merge
  --dry-run               仅确认，不实际合并
  --force                 质量门未通过也强制合并（不推荐）
  -h, --help              显示帮助

Examples:
  $0 --worktree ../worktrees/worker-1
  $0 --worktree ../worktrees/worker-1 --target-branch develop
  $0 --worktree ../worktrees/worker-1 --squash
  $0 --worktree ../worktrees/worker-1 --dry-run
  $0 --worktree ../worktrees/worker-1 --force  # 跳过质量门（注意）
EOF
}

main "$@"
