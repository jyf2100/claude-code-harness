#!/usr/bin/env bash
# scripts/evolver.sh
# 进化引擎 CLI 工具
#
# 用法:
#   ./scripts/evolver.sh health              # 显示所有技能健康状态
#   ./scripts/evolver.sh proposals           # 列出待处理提案
#   ./scripts/evolver.sh approve <id>        # 批准提案
#   ./scripts/evolver.sh reject <id>         # 拒绝提案
#   ./scripts/evolver.sh apply <id>          # 应用提案（标记为已应用）
#   ./scripts/evolver.sh snapshot <skill>    # 创建技能快照
#   ./scripts/evolver.sh rollback <key>      # 从快照回滚
#   ./scripts/evolver.sh recalc [skill]      # 重新计算健康分数

set -euo pipefail

# ============================================================
# 配置
# ============================================================

STATE_DB="${PROJECT_ROOT:-$(pwd)}/.harness/state.db"
SKILLS_DIR="${PROJECT_ROOT:-$(pwd)}/skills"

# ============================================================
# 辅助函数
# ============================================================

die() { echo "错误: $*" >&2; exit 1; }
info() { echo "ℹ $*"; }
ok() { echo "✓ $*"; }
warn() { echo "⚠ $*"; }

require_db() {
  [[ -f "$STATE_DB" ]] || die "数据库不存在: $STATE_DB\n请先运行 Harness 初始化。"
}

# ============================================================
# 子命令
# ============================================================

cmd_health() {
  require_db

  info "=== 技能健康状态报告 ==="
  info ""

  ROWS=$(sqlite3 -header -column "$STATE_DB" "
    SELECT
      skill_name AS '技能',
      version AS '版本',
      status AS '状态',
      ROUND(health_score, 2) AS '健康',
      usage_count AS '使用次数',
      ROUND(success_rate, 2) AS '成功率',
      evolution_pending AS '待处理',
      evolution_reason AS '原因'
    FROM skill_evolution
    ORDER BY health_score ASC
  " 2>/dev/null || echo "(无数据)")

  echo "$ROWS"
  echo ""

  # 统计摘要
  TOTAL=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM skill_evolution" 2>/dev/null || echo "0")
  UNHEALTHY=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM skill_evolution WHERE health_score < 0.7" 2>/dev/null || echo "0")
  PENDING=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM skill_evolution WHERE evolution_pending != 'none'" 2>/dev/null || echo "0")

  info "总计: ${TOTAL} 技能 | 不健康: ${UNHEALTHY} | 待进化: ${PENDING}"
}

cmd_proposals() {
  require_db

  info "=== 进化提案（待处理）==="
  echo ""

  ROWS=$(sqlite3 -header -column "$STATE_DB" "
    SELECT
      p.id AS 'ID',
      p.skill_name AS '技能',
      p.proposal_type AS '类型',
      json_extract(p.proposal_json, '$.reason') AS '原因',
      datetime(p.created_at, 'unixepoch', 'localtime') AS '创建时间'
    FROM skill_evolution_proposals p
    WHERE p.status = 'pending'
    ORDER BY p.created_at ASC
  " 2>/dev/null || echo "(无待处理提案)")

  echo "$ROWS"

  # 也显示已处理的历史
  echo ""
  info "=== 近期已处理提案 ==="
  sqlite3 -header -column "$STATE_DB" "
    SELECT
      p.id AS 'ID',
      p.skill_name AS '技能',
      p.proposal_type AS '类型',
      p.status AS '状态',
      datetime(p.reviewed_at, 'unixepoch', 'localtime') AS '处理时间'
    FROM skill_evolution_proposals p
    WHERE p.status != 'pending'
    ORDER BY p.reviewed_at DESC
    LIMIT 10
  " 2>/dev/null || echo "(无历史)"
}

cmd_approve() {
  local id="${1:?用法: evolver.sh approve <id>}"
  require_db

  # 验证提案存在
  EXISTS=$(sqlite3 "$STATE_DB" "
    SELECT COUNT(*) FROM skill_evolution_proposals WHERE id = $id AND status = 'pending'
  " 2>/dev/null || echo "0")

  [[ "$EXISTS" == "1" ]] || die "提案 #${id} 不存在或已处理"

  sqlite3 "$STATE_DB" "
    UPDATE skill_evolution_proposals
    SET status = 'approved', reviewed_at = $(date +%s), reviewed_by = 'cli'
    WHERE id = $id;
  " 2>/dev/null

  ok "提案 #${id} 已批准"
}

cmd_reject() {
  local id="${1:?用法: evolver.sh reject <id>}"
  require_db

  SKILL=$(sqlite3 "$STATE_DB" "
    SELECT skill_name FROM skill_evolution_proposals WHERE id = $id AND status = 'pending'
  " 2>/dev/null || echo "")

  [[ -n "$SKILL" ]] || die "提案 #${id} 不存在或已处理"

  sqlite3 "$STATE_DB" "
    UPDATE skill_evolution_proposals
    SET status = 'rejected', reviewed_at = $(date +%s), reviewed_by = 'cli'
    WHERE id = $id;
    UPDATE skill_evolution
    SET evolution_pending = 'none', evolution_reason = NULL
    WHERE skill_name = '$(echo "$SKILL" | sed "s/'/''/g")';
  " 2>/dev/null

  ok "提案 #${id} 已拒绝，${SKILL} 的进化待处理已清除"
}

cmd_apply() {
  local id="${1:?用法: evolver.sh apply <id>}"
  require_db

  # 验证提案已批准
  ROW=$(sqlite3 "$STATE_DB" "
    SELECT skill_name, proposal_type FROM skill_evolution_proposals
    WHERE id = $id AND status = 'approved'
  " 2>/dev/null || echo "")

  [[ -n "$ROW" ]] || die "提案 #${id} 不存在或未批准"

  SKILL=$(echo "$ROW" | cut -d'|' -f1)
  TYPE=$(echo "$ROW" | cut -d'|' -f2)

  # 先创建快照
  SKILL_FILE="${SKILLS_DIR}/${SKILL}/SKILL.md"
  if [[ -f "$SKILL_FILE" ]]; then
    SNAPSHOT_KEY="snapshot:${SKILL}:$(date +%s)"
    CONTENT=$(cat "$SKILL_FILE" | base64)
    sqlite3 "$STATE_DB" "
      INSERT INTO schema_meta(key, value) VALUES ('${SNAPSHOT_KEY}', '${CONTENT}')
      ON CONFLICT(key) DO UPDATE SET value = excluded.value;
    " 2>/dev/null
    info "已创建快照: ${SNAPSHOT_KEY}"
  fi

  # 标记为已应用
  sqlite3 "$STATE_DB" "
    UPDATE skill_evolution_proposals
    SET status = 'applied', applied_at = $(date +%s)
    WHERE id = $id;
    UPDATE skill_evolution
    SET evolution_pending = 'none',
        evolution_reason = NULL,
        evolution_type = '$(echo "$TYPE" | sed "s/'/''/g")',
        last_evolved_at = $(date +%s)
    WHERE skill_name = '$(echo "$SKILL" | sed "s/'/''/g")';
  " 2>/dev/null

  ok "提案 #${id} 已应用到 ${SKILL}"
  info "请手动修改 ${SKILL_FILE} 以完成进化"
}

cmd_snapshot() {
  local skill="${1:?用法: evolver.sh snapshot <skill_name>}"
  require_db

  SKILL_FILE="${SKILLS_DIR}/${skill}/SKILL.md"
  [[ -f "$SKILL_FILE" ]] || die "技能文件不存在: ${SKILL_FILE}"

  SNAPSHOT_KEY="snapshot:${skill}:$(date +%s)"
  CONTENT=$(cat "$SKILL_FILE" | base64)
  sqlite3 "$STATE_DB" "
    INSERT INTO schema_meta(key, value) VALUES ('${SNAPSHOT_KEY}', '${CONTENT}')
    ON CONFLICT(key) DO UPDATE SET value = excluded.value;
  " 2>/dev/null

  ok "快照已创建: ${SNAPSHOT_KEY}"
}

cmd_rollback() {
  local snapshot_key="${1:?用法: evolver.sh rollback <snapshot_key>}"
  require_db

  # 从快照键名中提取技能名
  SKILL=$(echo "$snapshot_key" | sed 's/snapshot:\([^:]*\):.*/\1/')
  SKILL_FILE="${SKILLS_DIR}/${SKILL}/SKILL.md"

  CONTENT_B64=$(sqlite3 "$STATE_DB" "
    SELECT value FROM schema_meta WHERE key = '$(echo "$snapshot_key" | sed "s/'/''/g")'
  " 2>/dev/null || echo "")

  [[ -n "$CONTENT_B64" ]] || die "快照不存在: ${snapshot_key}"

  echo "$CONTENT_B64" | base64 -d > "$SKILL_FILE"
  ok "已从快照回滚 ${SKILL} → ${SKILL_FILE}"
}

cmd_recalc() {
  require_db

  if [[ -n "${1:-}" ]]; then
    SKILLS="$1"
  else
    SKILLS=$(sqlite3 "$STATE_DB" "
      SELECT DISTINCT skill_name FROM skill_usage_metrics
    " 2>/dev/null || echo "")
  fi

  [[ -n "$SKILLS" ]] || { info "无技能使用数据"; exit 0; }

  SEVEN_DAYS_AGO=$(($(date +%s) - 7 * 24 * 3600))

  while IFS= read -r SKILL; do
    [[ -z "$SKILL" ]] && continue

    STATS=$(sqlite3 "$STATE_DB" "
      SELECT COUNT(*), SUM(success)
      FROM skill_usage_metrics
      WHERE skill_name = '$(echo "$SKILL" | sed "s/'/''/g")' AND recorded_at >= $SEVEN_DAYS_AGO
    " 2>/dev/null || echo "0|0")

    TOTAL=$(echo "$STATS" | cut -d'|' -f1)
    OK=$(echo "$STATS" | cut -d'|' -f2)
    [[ "$TOTAL" == "0" || -z "$TOTAL" ]] && continue

    SUCCESS_RATE=$(echo "scale=4; $OK / $TOTAL" | bc 2>/dev/null || echo "1.0")

    if [[ "$TOTAL" -le 1 ]]; then US="0.2"
    elif [[ "$TOTAL" -le 10 ]]; then US="0.4"
    elif [[ "$TOTAL" -le 50 ]]; then US="0.7"
    else US="1.0"; fi

    HEALTH=$(echo "scale=4; $SUCCESS_RATE * 0.6 + $US * 0.4" | bc 2>/dev/null || echo "1.0")

    sqlite3 "$STATE_DB" "
      UPDATE skill_evolution
      SET health_score = $HEALTH, usage_count = $TOTAL, success_rate = $SUCCESS_RATE
      WHERE skill_name = '$(echo "$SKILL" | sed "s/'/''/g")';
    " 2>/dev/null || true

    info "${SKILL}: health=${HEALTH} usage=${TOTAL} success_rate=${SUCCESS_RATE}"
  done <<< "$SKILLS"

  ok "健康分数重新计算完成"
}

# ============================================================
# 主入口
# ============================================================

CMD="${1:-health}"
shift || true

case "$CMD" in
  health)    cmd_health ;;
  proposals) cmd_proposals ;;
  approve)   cmd_approve "$@" ;;
  reject)    cmd_reject "$@" ;;
  apply)     cmd_apply "$@" ;;
  snapshot)  cmd_snapshot "$@" ;;
  rollback)  cmd_rollback "$@" ;;
  recalc)    cmd_recalc "$@" ;;
  *)
    echo "用法: evolver.sh <command> [args]"
    echo ""
    echo "命令:"
    echo "  health              显示技能健康状态"
    echo "  proposals           列出进化提案"
    echo "  approve <id>        批准提案"
    echo "  reject <id>         拒绝提案"
    echo "  apply <id>          应用提案"
    echo "  snapshot <skill>    创建技能快照"
    echo "  rollback <key>      从快照回滚"
    echo "  recalc [skill]      重新计算健康分数"
    exit 1
    ;;
esac
