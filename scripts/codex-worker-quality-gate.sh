#!/usr/bin/env bash
#
# codex-worker-quality-gate.sh
# Orchestrator 对 Worker 成果物的质量验证
#
# Usage:
#   ./scripts/codex-worker-quality-gate.sh --worktree PATH [--skip-gate GATE --reason TEXT]
#

set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共库
# shellcheck source=lib/codex-worker-common.sh
source "$SCRIPT_DIR/lib/codex-worker-common.sh"

# ============================================
# 本地设置
# ============================================
GATE_SKIP_LOG=".claude/state/gate-skips.log"
AGENTS_SUMMARY_PATTERN='AGENTS_SUMMARY:[[:space:]]*(.+?)[[:space:]]*\|[[:space:]]*HASH:([A-Fa-f0-9]{8})'

# 跳过日志记录
log_skip() {
    local gate="$1"
    local reason="$2"
    local user="${USER:-unknown}"

    mkdir -p "$(dirname "$GATE_SKIP_LOG")"
    printf '%s\t%s\t%s\t%s\n' "$(now_utc)" "$gate" "$reason" "$user" >> "$GATE_SKIP_LOG"
}

# 解析 diff 的起点（默认分支的 merge-base，不存在则用 HEAD~1，最后用 HEAD）
resolve_diff_base() {
    local worktree="$1"
    local default_branch
    default_branch=$(get_default_branch)

    local diff_base
    diff_base=$(cd "$worktree" && git merge-base HEAD "origin/$default_branch" 2>/dev/null || git rev-parse HEAD~1 2>/dev/null || echo "")

    if [[ -z "$diff_base" ]]; then
        diff_base=$(cd "$worktree" && git rev-parse HEAD 2>/dev/null || echo "")
    fi

    echo "$diff_base"
}

# 获取指定范围内的添加行（直接以换行返回）
collect_added_lines() {
    local worktree="$1"
    local diff_base="$2"

    cd "$worktree" && git diff "$diff_base"..HEAD --unified=0 -- \
        '*.ts' '*.tsx' '*.js' '*.jsx' '*.mjs' '*.cjs' \
        '*.sh' '*.md' '*.json' '*.yaml' '*.yml' '*.toml' \
        '*.py' '*.go' '*.rs' '*.txt' 2>/dev/null | grep '^+' | grep -v '^+++ ' || true
}

# 获取指定范围内的变更文件
collect_changed_files() {
    local worktree="$1"
    local diff_base="$2"

    cd "$worktree" && git diff --name-only "$diff_base"..HEAD -- \
        '*.ts' '*.tsx' '*.js' '*.jsx' '*.mjs' '*.cjs' \
        '*.sh' '*.md' '*.json' '*.yaml' '*.yml' '*.toml' \
        '*.py' '*.go' '*.rs' '*.txt' 2>/dev/null || true
}

# Gate 1: 凭证验证
gate_evidence() {
    local worktree="$1"
    local output_file="$2"

    log_gate "Gate 1: 凭证验证 (evidence)"

    # 计算 AGENTS.md 的哈希值
    local agents_file="$worktree/AGENTS.md"
    if [[ ! -f "$agents_file" ]]; then
        echo '{"status": "critical", "details": "AGENTS.md not found"}' > "$output_file"
        return 2  # Critical: AGENTS.md 必须存在
    fi

    # 哈希计算（与 engine 完全一致：去除 BOM、去除 CR、SHA256 前8位）
    local expected_hash
    expected_hash=$(calculate_file_hash "$agents_file" 8)

    # 从 Worker 输出中搜索 AGENTS_SUMMARY
    # 1. Worker 输出日志（优先）
    # 2. 最新提交消息（回退）
    local worker_output_log="$worktree/.claude/state/worker-output.log"
    local search_content=""
    local found_in_log=false

    if [[ -f "$worker_output_log" ]]; then
        search_content=$(cat "$worker_output_log")
        if echo "$search_content" | grep -qE "$AGENTS_SUMMARY_PATTERN"; then
            found_in_log=true
        fi
    fi

    # 日志中未检测到时，回退搜索提交消息
    if [[ "$found_in_log" == "false" ]]; then
        local commit_msg
        commit_msg=$(cd "$worktree" && git log -1 --pretty=%B 2>/dev/null || echo "")
        if echo "$commit_msg" | grep -qE "$AGENTS_SUMMARY_PATTERN"; then
            search_content="$commit_msg"
        fi
    fi

    # 模式匹配（仅从 AGENTS_SUMMARY 行提取 HASH）
    if echo "$search_content" | grep -qE "$AGENTS_SUMMARY_PATTERN"; then
        local found_hash
        # 仅从包含 AGENTS_SUMMARY 的行提取 HASH（避免拾取无关的 HASH）
        found_hash=$(echo "$search_content" | grep -E 'AGENTS_SUMMARY' | grep -oE 'HASH:[A-Fa-f0-9]{8}' | head -1 | cut -d: -f2)

        if [[ "${found_hash,,}" == "${expected_hash,,}" ]]; then
            echo '{"status": "passed", "details": "凭证确认OK"}' > "$output_file"
            return 0
        else
            echo "{\"status\": \"failed\", \"details\": \"哈希不匹配: expected=$expected_hash, found=$found_hash\"}" > "$output_file"
            return 1  # High: 哈希不匹配可重试
        fi
    else
        echo '{"status": "critical", "details": "未找到 AGENTS_SUMMARY 凭证（立即失败）"}' > "$output_file"
        return 2  # Critical: 凭证缺失立即失败
    fi
}

# Gate 2: 结构检查
gate_structure() {
    local worktree="$1"
    local output_file="$2"

    log_gate "Gate 2: 结构检查 (structure)"

    local lint_result=0
    local type_result=0
    local details=""

    # package.json 不存在时视为跳过
    if [[ ! -f "$worktree/package.json" ]]; then
        echo '{"status": "passed", "details": "无 package.json（跳过）"}' > "$output_file"
        return 0
    fi

    # Quality: 自动检测包管理器
    local pm
    pm=$(detect_package_manager "$worktree")
    local pm_run
    pm_run=$(get_pm_run_command "$pm")
    log_info "检测到包管理器: $pm"

    # 使用 jq 准确判断 scripts 键
    # lint 检查
    if jq -e '.scripts.lint' "$worktree/package.json" > /dev/null 2>&1; then
        if ! (cd "$worktree" && $pm_run lint --silent 2>&1); then
            lint_result=1
            details="lint 错误"
        fi
    fi

    # type-check
    if jq -e '.scripts["type-check"]' "$worktree/package.json" > /dev/null 2>&1; then
        if ! (cd "$worktree" && $pm_run type-check --silent 2>&1); then
            type_result=1
            details="${details:+$details, }type 错误"
        fi
    fi

    if [[ $lint_result -eq 0 ]] && [[ $type_result -eq 0 ]]; then
        echo '{"status": "passed", "details": "结构检查OK"}' > "$output_file"
        return 0
    else
        echo "{\"status\": \"failed\", \"details\": \"$details\"}" > "$output_file"
        return 1
    fi
}

# Gate 3: 测试
gate_test() {
    local worktree="$1"
    local output_file="$2"

    log_gate "Gate 3: 测试 (test)"

    # 篡改检测模式（用于添加行）
    # Critical: 明确的篡改 —— 测试无效化模式
    local tamper_critical_patterns=(
        # JS/TS skip 化
        'it\.skip\s*\('
        'test\.skip\s*\('
        'describe\.skip\s*\('
        'xit\s*\('
        'xdescribe\s*\('
        # .only 化（其他测试不会执行）
        '(it|test|describe)\.only\s*\('
        'fit\s*\('
        'fdescribe\s*\('
        # Python skip 化
        '@pytest\.mark\.skip'
        '@unittest\.skip'
        'self\.skipTest\s*\('
    )
    # Warning: 可能有正当理由，但需要注意
    local tamper_warn_patterns=(
        'eslint-disable'
        '@ts-ignore'
        '@ts-expect-error'
        '@ts-nocheck'
    )

    # 删除行用模式（断言删除检测）
    local tamper_remove_patterns=(
        'expect\s*\('
        'assert\s*\('
        '\.should\s*\('
        '\.to\.\w+'
        'self\.assert'
    )

    # 基于 diff 的篡改检测（来自默认分支的所有变更）
    local default_branch
    default_branch=$(get_default_branch)
    local merge_base
    merge_base=$(cd "$worktree" && git merge-base HEAD "origin/$default_branch" 2>/dev/null || git rev-parse HEAD~1 2>/dev/null || echo "")

    if [[ -n "$merge_base" ]]; then
        # 检测添加行（以 + 开头的行，排除 +++ 头部）
        # 也包括 Python 测试文件（test_*.py, *_test.py）
        local added_lines
        added_lines=$(cd "$worktree" && git diff "$merge_base"..HEAD --unified=0 -- '*.ts' '*.tsx' '*.js' '*.jsx' '*.spec.*' '*.test.*' '*.py' 2>/dev/null | grep '^+' | grep -v '^+++ ' || echo "")

        # Critical 模式检测（skip 系 - 明确篡改）
        for pattern in "${tamper_critical_patterns[@]}"; do
            if echo "$added_lines" | grep -qE "$pattern"; then
                echo "{\"status\": \"critical\", \"details\": \"检测到篡改: 添加行中包含 '$pattern' 模式\"}" > "$output_file"
                return 2  # Critical: 检测到篡改
            fi
        done

        # Warning 模式检测（eslint-disable - 可能有正当理由）
        for pattern in "${tamper_warn_patterns[@]}"; do
            if echo "$added_lines" | grep -qE "$pattern"; then
                log_warn "需要确认: 添加行中包含 '$pattern' 模式（可能的篡改）"
                # 作为 Warning 记录，但不是 Critical
            fi
        done

        # 检测删除行（以 - 开头的行）- 仅测试文件
        local removed_lines
        removed_lines=$(cd "$worktree" && git diff "$merge_base"..HEAD --unified=0 -- '*.spec.*' '*.test.*' 'test_*.py' '*_test.py' 2>/dev/null | grep '^-' | grep -v '^---' || echo "")

        for pattern in "${tamper_remove_patterns[@]}"; do
            local removed_count
            removed_count=$(echo "$removed_lines" | grep -cE "$pattern" 2>/dev/null || echo 0)

            if [[ "$removed_count" -gt 2 ]]; then
                echo "{\"status\": \"critical\", \"details\": \"检测到篡改: 从测试中删除了 $removed_count 个 '$pattern'\"}" > "$output_file"
                return 2  # Critical: 大量断言删除
            fi
        done

        # 检测 Catch-all 断言（总是成功的无意义断言）
        # expect(true).toBe(true), expect(1).toBe(1) 等
        if echo "$added_lines" | grep -qE 'expect\((true|false|1|0|null|undefined)\)\.(toBe|toEqual|toStrictEqual)\((true|false|1|0|null|undefined)\)'; then
            log_warn "需要确认: 检测到 catch-all 断言（expect(true).toBe(true) 等）"
        fi
        # 对常量的弱断言: expect(false).toBeFalsy() 等
        if echo "$added_lines" | grep -qE 'expect\((true|false|null|undefined|0)\)\.(toBeUndefined|toBeNull|toBeFalsy|toBeTruthy)\(\)'; then
            log_warn "需要确认: 检测到对常量的弱断言"
        fi

        # 检测超时值的大幅提高（≥30000ms）
        local timeout_hit
        timeout_hit=$(echo "$added_lines" | grep -E 'jest\.setTimeout\(|jasmine\.DEFAULT_TIMEOUT_INTERVAL|[[:space:]]timeout[[:space:]]*:' | grep -oE '[0-9]+' | awk '$1 >= 30000 {found=1} END {print found+0}' 2>/dev/null || echo 0)
        if [[ "${timeout_hit:-0}" -gt 0 ]]; then
            log_warn "需要确认: 检测到超时值大幅提高（≥30000ms）"
        fi

        # 检测配置文件放宽（lint/CI/TypeScript strict）
        local config_diff
        config_diff=$(cd "$worktree" && git diff "$merge_base"..HEAD --unified=0 -- '.eslintrc*' 'eslint.config.*' 'tsconfig.json' 'tsconfig.*.json' 'biome.json' 'jest.config.*' 'vitest.config.*' '.github/workflows/*.yml' '.github/workflows/*.yaml' 2>/dev/null | grep '^+' | grep -v '^+++ ' || echo "")
        if [[ -n "$config_diff" ]]; then
            # lint 规则禁用
            if echo "$config_diff" | grep -qE '"off"|:[[:space:]]*0'; then
                log_warn "需要确认: 检测到配置文件中禁用 lint 规则"
            fi
            # CI continue-on-error
            if echo "$config_diff" | grep -qE 'continue-on-error:[[:space:]]*true'; then
                log_warn "需要确认: 检测到 CI 中添加 continue-on-error"
            fi
            # TypeScript strict 模式放宽
            if echo "$config_diff" | grep -qE '"strict"[[:space:]]*:[[:space:]]*false|"noImplicitAny"[[:space:]]*:[[:space:]]*false'; then
                echo '{"status": "critical", "details": "检测到篡改: TypeScript strict 模式被放宽"}' > "$output_file"
                return 2
            fi
        fi
    fi

    # 运行测试（自动检测包管理器）
    if [[ -f "$worktree/package.json" ]]; then
        if jq -e '.scripts.test' "$worktree/package.json" > /dev/null 2>&1; then
            local pm
            pm=$(detect_package_manager "$worktree")
            local pm_run
            pm_run=$(get_pm_run_command "$pm")

            if ! (cd "$worktree" && $pm_run test 2>&1); then
                echo '{"status": "failed", "details": "测试失败"}' > "$output_file"
                return 1
            fi
        fi
    fi

    echo '{"status": "passed", "details": "测试OK"}' > "$output_file"
    return 0
}

# Gate 4: Hardening parity
gate_hardening() {
    local worktree="$1"
    local output_file="$2"

    log_gate "Gate 4: hardening parity"

    local codex_state_dir="$worktree/.claude/state/codex-worker"
    local base_instructions_file="$codex_state_dir/base-instructions.txt"
    local prompt_file="$codex_state_dir/prompt.txt"
    local contract_file="$codex_state_dir/hardening-contract.txt"
    local marker="HARNESS_HARDENING_CONTRACT_V1"

    local status="passed"
    local violations=()

    # 1. 确认注入的 contract 文件
    local contract_files=(
        "$base_instructions_file"
        "$prompt_file"
        "$contract_file"
    )

    for file in "${contract_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            violations+=("Hardening contract artifact missing: $file")
            status="critical"
            continue
        fi

        if ! grep -Fq "$marker" "$file" 2>/dev/null; then
            violations+=("Hardening contract marker missing: $file")
            status="critical"
        fi
    done

    # 2. 基于 Diff 的 hardening 违规检查
    local diff_base
    diff_base=$(resolve_diff_base "$worktree")

    if [[ -n "$diff_base" ]]; then
        local changed_files
        local added_lines
        changed_files=$(collect_changed_files "$worktree" "$diff_base")
        added_lines=$(collect_added_lines "$worktree" "$diff_base")

        # 2-1. bypass flags
        if echo "$added_lines" | grep -qE -- '--no-verify|--no-gpg-sign'; then
            violations+=("Added lines contain bypass flags: --no-verify or --no-gpg-sign")
            [[ "$status" == "passed" ]] && status="failed"
        fi

        # 2-2. protected branch reset
        if echo "$added_lines" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard'; then
            if echo "$added_lines" | grep -qE '(origin/)?(main|master)'; then
                violations+=("Added lines contain protected hard reset command against main/master")
                [[ "$status" == "passed" ]] && status="failed"
            fi
        fi

        # 2-3. protected files
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            case "$file" in
                package.json|Dockerfile|docker-compose.yml|schema.prisma|wrangler.toml|index.html|.github/workflows/*.yml|.github/workflows/*.yaml)
                    violations+=("Protected file changed: $file")
                    [[ "$status" == "passed" ]] && status="failed"
                    ;;
            esac
        done <<< "$changed_files"

        # 2-4. secrets / credentials
        if echo "$added_lines" | grep -qE '(api[_-]?key|secret[_-]?key|auth[_-]?token|access[_-]?token|password|credential|private[_-]?key)[[:space:]]*[:=]'; then
            violations+=("Added lines contain hardcoded secret-like assignment")
            [[ "$status" == "passed" ]] && status="failed"
        fi

        if echo "$added_lines" | grep -qE '(postgres://|mysql://|mongodb://|redis://|amqp://|DATABASE_URL|REDIS_URL)'; then
            violations+=("Added lines contain hardcoded service/database connection string")
            [[ "$status" == "passed" ]] && status="failed"
        fi

        if echo "$added_lines" | grep -qE '(192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+)'; then
            violations+=("Added lines contain private IP address")
            [[ "$status" == "passed" ]] && status="failed"
        fi
    else
        violations+=("Hardening diff base could not be resolved")
        status="critical"
    fi

    local violations_json='[]'
    if [[ ${#violations[@]} -gt 0 ]]; then
        violations_json=$(printf '%s\n' "${violations[@]}" | jq -R . | jq -s '.')
    fi

    local details="hardening parity OK"
    case "$status" in
        critical) details="hardening contract missing or invalid" ;;
        failed) details="hardening violations detected" ;;
    esac

    jq -n \
        --arg status "$status" \
        --arg details "$details" \
        --arg marker "$marker" \
        --argjson violations "$violations_json" \
        '{
            status: $status,
            details: $details,
            marker: $marker,
            violations: $violations
        }' > "$output_file"

    case "$status" in
        passed) return 0 ;;
        failed) return 1 ;;
        critical) return 2 ;;
    esac
}

# 主处理
main() {
    check_dependencies

    local worktree=""
    local skip_gates=()
    local skip_reason=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --worktree)
                if [[ -z "${2:-}" ]]; then
                    log_error "--worktree 需要提供值"
                    exit 1
                fi
                worktree="$2"; shift 2 ;;
            --skip-gate)
                if [[ -z "${2:-}" ]]; then
                    log_error "--skip-gate 需要提供值"
                    exit 1
                fi
                skip_gates+=("$2"); shift 2 ;;
            --reason)
                if [[ -z "${2:-}" ]]; then
                    log_error "--reason 需要提供值"
                    exit 1
                fi
                skip_reason="$2"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) log_error "未知选项: $1"; exit 1 ;;
        esac
    done

    # 必须参数检查
    if [[ -z "$worktree" ]]; then
        log_error "--worktree 是必需的"
        exit 1
    fi

    if [[ ! -d "$worktree" ]]; then
        log_error "Worktree 不存在: $worktree"
        exit 1
    fi

    # Security: 验证是否为同一仓库的 worktree
    if ! validate_worktree_path "$worktree"; then
        exit 1
    fi

    # 跳过时必须提供理由
    if [[ ${#skip_gates[@]} -gt 0 ]] && [[ -z "$skip_reason" ]]; then
        log_error "使用 --skip-gate 时必须提供 --reason"
        exit 1
    fi

    # Security: 确认跳过允许列表（默认拒绝）
    if [[ ${#skip_gates[@]} -gt 0 ]]; then
        local allowlist
        allowlist=$(get_config "gate_skip_allowlist")

        # 允许列表为空或 [] 时，拒绝所有跳过
        if [[ -z "$allowlist" || "$allowlist" == "[]" || "$allowlist" == "null" ]]; then
            log_error "不允许跳过 Gate（允许列表为空）"
            log_error "要允许跳过，请编辑配置文件中的 gate_skip_allowlist"
            exit 1
        fi

        for gate in "${skip_gates[@]}"; do
            # 确认是否在允许列表中
            if ! echo "$allowlist" | jq -e --arg g "$gate" 'index($g) != null' >/dev/null 2>&1; then
                log_error "Gate '$gate' 不在允许列表中"
                log_error "允许的 gate: $allowlist"
                exit 1
            fi
            log_warn "跳过 Gate '$gate': $skip_reason (user=${USER:-unknown})"
        done
    fi

    # 临时目录
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    # 存储结果
    local overall_status="passed"
    local gates_json="{}"
    local skipped_json="[]"
    local errors_json="[]"

    # Gate 1: 凭证验证
    if [[ " ${skip_gates[*]} " =~ " evidence " ]]; then
        log_warn "跳过 Gate 1 (evidence)"
        log_skip "evidence" "$skip_reason"
        skipped_json=$(echo "$skipped_json" | jq '. + ["evidence"]')
        gates_json=$(echo "$gates_json" | jq --arg reason "$skip_reason" '.evidence = {"status": "skipped", "details": $reason}')
    else
        local evidence_exit_code=0
        gate_evidence "$worktree" "$tmp_dir/evidence.json" || evidence_exit_code=$?

        if [[ $evidence_exit_code -eq 0 ]]; then
            gates_json=$(echo "$gates_json" | jq --slurpfile g "$tmp_dir/evidence.json" '.evidence = $g[0]')
        elif [[ $evidence_exit_code -eq 2 ]]; then
            # Critical: 凭证缺失
            overall_status="critical"
            gates_json=$(echo "$gates_json" | jq --slurpfile g "$tmp_dir/evidence.json" '.evidence = $g[0]')
            errors_json=$(echo "$errors_json" | jq '. + ["CRITICAL: 凭证缺失"]')
        else
            overall_status="failed"
            gates_json=$(echo "$gates_json" | jq --slurpfile g "$tmp_dir/evidence.json" '.evidence = $g[0]')
            errors_json=$(echo "$errors_json" | jq '. + ["Gate 1 failed: 哈希不匹配"]')
        fi
    fi

    # Gate 2: 结构检查
    if [[ " ${skip_gates[*]} " =~ " structure " ]]; then
        log_warn "跳过 Gate 2 (structure)"
        log_skip "structure" "$skip_reason"
        skipped_json=$(echo "$skipped_json" | jq '. + ["structure"]')
        gates_json=$(echo "$gates_json" | jq --arg reason "$skip_reason" '.structure = {"status": "skipped", "details": $reason}')
    else
        if gate_structure "$worktree" "$tmp_dir/structure.json"; then
            gates_json=$(echo "$gates_json" | jq --slurpfile g "$tmp_dir/structure.json" '.structure = $g[0]')
        else
            overall_status="failed"
            gates_json=$(echo "$gates_json" | jq --slurpfile g "$tmp_dir/structure.json" '.structure = $g[0]')
            errors_json=$(echo "$errors_json" | jq '. + ["Gate 2 failed"]')
        fi
    fi

    # Gate 3: 测试
    if [[ " ${skip_gates[*]} " =~ " test " ]]; then
        log_warn "跳过 Gate 3 (test)"
        log_skip "test" "$skip_reason"
        skipped_json=$(echo "$skipped_json" | jq '. + ["test"]')
        gates_json=$(echo "$gates_json" | jq --arg reason "$skip_reason" '.test = {"status": "skipped", "details": $reason}')
    else
        local test_exit_code=0
        gate_test "$worktree" "$tmp_dir/test.json" || test_exit_code=$?

        if [[ $test_exit_code -eq 0 ]]; then
            gates_json=$(echo "$gates_json" | jq --slurpfile g "$tmp_dir/test.json" '.test = $g[0]')
        elif [[ $test_exit_code -eq 2 ]]; then
            # Critical: 检测到篡改
            overall_status="critical"
            gates_json=$(echo "$gates_json" | jq --slurpfile g "$tmp_dir/test.json" '.test = $g[0]')
            errors_json=$(echo "$errors_json" | jq '. + ["CRITICAL: 检测到篡改"]')
        else
            overall_status="failed"
            gates_json=$(echo "$gates_json" | jq --slurpfile g "$tmp_dir/test.json" '.test = $g[0]')
            errors_json=$(echo "$errors_json" | jq '. + ["Gate 3 failed"]')
        fi
    fi

    # Gate 4: Hardening parity
    if [[ " ${skip_gates[*]} " =~ " hardening " ]]; then
        log_warn "跳过 Gate 4 (hardening)"
        log_skip "hardening" "$skip_reason"
        skipped_json=$(echo "$skipped_json" | jq '. + ["hardening"]')
        gates_json=$(echo "$gates_json" | jq --arg reason "$skip_reason" '.hardening = {"status": "skipped", "details": $reason}')
    else
        local hardening_exit_code=0
        gate_hardening "$worktree" "$tmp_dir/hardening.json" || hardening_exit_code=$?

        if [[ $hardening_exit_code -eq 0 ]]; then
            gates_json=$(echo "$gates_json" | jq --slurpfile g "$tmp_dir/hardening.json" '.hardening = $g[0]')
        elif [[ $hardening_exit_code -eq 2 ]]; then
            overall_status="critical"
            gates_json=$(echo "$gates_json" | jq --slurpfile g "$tmp_dir/hardening.json" '.hardening = $g[0]')
            errors_json=$(echo "$errors_json" | jq '. + ["CRITICAL: hardening contract missing or invalid"]')
            while IFS= read -r violation; do
                [[ -z "$violation" ]] && continue
                errors_json=$(echo "$errors_json" | jq --arg v "$violation" '. + [$v]')
            done < <(jq -r '.violations[]' "$tmp_dir/hardening.json" 2>/dev/null || true)
        else
            overall_status="failed"
            gates_json=$(echo "$gates_json" | jq --slurpfile g "$tmp_dir/hardening.json" '.hardening = $g[0]')
            errors_json=$(echo "$errors_json" | jq '. + ["Gate 4 failed: hardening violations"]')
            while IFS= read -r violation; do
                [[ -z "$violation" ]] && continue
                errors_json=$(echo "$errors_json" | jq --arg v "$violation" '. + [$v]')
            done < <(jq -r '.violations[]' "$tmp_dir/hardening.json" 2>/dev/null || true)
        fi
    fi

    # 最终结果输出
    local result
    result=$(jq -n \
        --arg status "$overall_status" \
        --argjson gates "$gates_json" \
        --argjson skipped "$skipped_json" \
        --argjson errors "$errors_json" \
        '{
            status: $status,
            gates: $gates,
            skipped: $skipped,
            errors: $errors
        }')

    # Security: 集中管理 gate 结果（保存在 worktree 外）
    local details_summary
    details_summary=$(echo "$result" | jq -c '.errors')
    save_gate_result "$worktree" "$overall_status" "$details_summary"

    echo "$result"

    # 退出码
    case "$overall_status" in
        passed) exit 0 ;;
        failed) exit 1 ;;
        critical) exit 2 ;;
    esac
}

# 使用方法
usage() {
    cat << EOF
Usage: $0 --worktree PATH [OPTIONS]

Options:
  --worktree PATH       要检查的 worktree（必需）
  --skip-gate GATE      跳过特定 gate (evidence, structure, test, hardening)
  --reason TEXT         跳过理由（与 --skip-gate 一起使用，必需）
  -h, --help            显示帮助

Gates:
  evidence   - AGENTS_SUMMARY 凭证验证
  structure  - lint, type-check
  test       - 运行测试、篡改检测
  hardening  - Codex parity hardening（contract, bypass flags, protected files, secrets）

Examples:
  $0 --worktree ../worktrees/worker-1
  $0 --worktree ../worktrees/worker-1 --skip-gate test --reason "测试环境未构建"
EOF
}

main "$@"
