#!/usr/bin/env bash
# scripts/hook-handlers/evolution-health-check.sh
# Stop/SessionEnd hook: 分析技能健康状态，生成进化提案
#
# 用法: 作为 Stop 或 SessionEnd hook 触发
# 读取近期使用数据，计算健康分数，对低于阈值的技能生成 FIX/DERIVED 提案

set -euo pipefail

# ============================================================
# 配置
# ============================================================

STATE_DB="${PROJECT_ROOT:-$(pwd)}/.harness/state.db"
HEALTH_THRESHOLD="${EVOLUTION_HEALTH_THRESHOLD:-0.7}"
DERIVED_USAGE_THRESHOLD="${EVOLUTION_DERIVED_THRESHOLD:-50}"
CAPTURED_SUCCESS_THRESHOLD="${EVOLUTION_CAPTURED_THRESHOLD:-0.95}"
SEVEN_DAYS_AGO=$(($(date +%s) - 7 * 24 * 3600))

# ============================================================
# 检查前置条件
# ============================================================

if [[ ! -f "$STATE_DB" ]]; then
  exit 0
fi

# 读取 stdin（忽略，仅触发时使用）
cat > /dev/null 2>&1 || true

# ============================================================
# 1. 为所有有使用记录的技能更新健康分数
# ============================================================

SKILLS=$(sqlite3 "$STATE_DB" "
  SELECT DISTINCT skill_name
  FROM skill_usage_metrics
  WHERE recorded_at >= $SEVEN_DAYS_AGO
" 2>/dev/null || echo "")

if [[ -z "$SKILLS" ]]; then
  exit 0
fi

while IFS= read -r SKILL; do
  [[ -z "$SKILL" ]] && continue

  # 获取使用统计
  STATS=$(sqlite3 "$STATE_DB" "
    SELECT
      COUNT(*) as total,
      SUM(success) as ok
    FROM skill_usage_metrics
    WHERE skill_name = '$(echo "$SKILL" | sed "s/'/''/g")'
      AND recorded_at >= $SEVEN_DAYS_AGO
  " 2>/dev/null || echo "0|0")

  TOTAL=$(echo "$STATS" | cut -d'|' -f1)
  OK=$(echo "$STATS" | cut -d'|' -f2)
  [[ -z "$TOTAL" || "$TOTAL" == "0" ]] && continue

  SUCCESS_RATE=$(echo "scale=4; $OK / $TOTAL" | bc 2>/dev/null || echo "1.0")

  # 使用频率分
  if [[ "$TOTAL" -le 1 ]]; then
    USAGE_SCORE="0.2"
  elif [[ "$TOTAL" -le 10 ]]; then
    USAGE_SCORE="0.4"
  elif [[ "$TOTAL" -le 50 ]]; then
    USAGE_SCORE="0.7"
  else
    USAGE_SCORE="1.0"
  fi

  HEALTH=$(echo "scale=4; $SUCCESS_RATE * 0.6 + $USAGE_SCORE * 0.4" | bc 2>/dev/null || echo "1.0")

  # 更新或插入进化记录
  sqlite3 "$STATE_DB" "
    INSERT INTO skill_evolution(skill_name, health_score, usage_count, success_rate, last_used_at)
    VALUES ('$(echo "$SKILL" | sed "s/'/''/g")', $HEALTH, $TOTAL, $SUCCESS_RATE, $(date +%s))
    ON CONFLICT(skill_name) DO UPDATE SET
      health_score = $HEALTH,
      usage_count = $TOTAL,
      success_rate = $SUCCESS_RATE,
      last_used_at = $(date +%s);
  " 2>/dev/null || true

  # ============================================================
  # 2. 生成进化提案
  # ============================================================

  PENDING=$(sqlite3 "$STATE_DB" "
    SELECT evolution_pending FROM skill_evolution
    WHERE skill_name = '$(echo "$SKILL" | sed "s/'/''/g")'
  " 2>/dev/null || echo "none")

  [[ "$PENDING" != "none" ]] && continue

  # FIX: 健康分数低于阈值
  IS_LOW=$(echo "$HEALTH < $HEALTH_THRESHOLD" | bc 2>/dev/null || echo "0")
  if [[ "$IS_LOW" == "1" ]]; then
    # 获取失败模式
    ERRORS=$(sqlite3 "$STATE_DB" "
      SELECT error_message FROM skill_usage_metrics
      WHERE skill_name = '$(echo "$SKILL" | sed "s/'/''/g")'
        AND success = 0
        AND recorded_at >= $SEVEN_DAYS_AGO
      ORDER BY recorded_at DESC LIMIT 5
    " 2>/dev/null | tr '\n' '; ' | head -c 500)

    sqlite3 "$STATE_DB" "
      INSERT INTO skill_evolution_proposals(skill_name, proposal_type, proposal_json, created_at)
      VALUES (
        '$(echo "$SKILL" | sed "s/'/''/g")',
        'fix',
        json('{
          \"reason\": \"健康分数 ${HEALTH} 低于阈值 ${HEALTH_THRESHOLD}\",
          \"failure_patterns\": [\"${ERRORS}\"],
          \"priority\": 3
        }'),
        $(date +%s)
      );
      UPDATE skill_evolution SET evolution_pending = 'fix',
        evolution_reason = '健康分数 ${HEALTH} 低于阈值'
      WHERE skill_name = '$(echo "$SKILL" | sed "s/'/''/g")';
    " 2>/dev/null || true
    continue
  fi

  # DERIVED: 使用次数超过阈值
  if [[ "$TOTAL" -ge "$DERIVED_USAGE_THRESHOLD" ]]; then
    sqlite3 "$STATE_DB" "
      INSERT INTO skill_evolution_proposals(skill_name, proposal_type, proposal_json, created_at)
      VALUES (
        '$(echo "$SKILL" | sed "s/'/''/g")',
        'derived',
        json('{
          \"reason\": \"使用次数 ${TOTAL} 超过衍生阈值 ${DERIVED_USAGE_THRESHOLD}\",
          \"suggested_changes\": \"考虑拆分为更专业的子技能\",
          \"priority\": 2
        }'),
        $(date +%s)
      );
      UPDATE skill_evolution SET evolution_pending = 'review',
        evolution_reason = '使用频率高，考虑衍生'
      WHERE skill_name = '$(echo "$SKILL" | sed "s/'/''/g")';
    " 2>/dev/null || true
    continue
  fi

  # CAPTURED: 成功率极高
  IS_HIGH=$(echo "$SUCCESS_RATE >= $CAPTURED_SUCCESS_THRESHOLD" | bc 2>/dev/null || echo "0")
  if [[ "$IS_HIGH" == "1" && "$TOTAL" -ge 10 ]]; then
    sqlite3 "$STATE_DB" "
      INSERT INTO skill_evolution_proposals(skill_name, proposal_type, proposal_json, created_at)
      VALUES (
        '$(echo "$SKILL" | sed "s/'/''/g")',
        'captured',
        json('{
          \"reason\": \"成功率 ${SUCCESS_RATE} 超过捕获阈值 ${CAPTURED_SUCCESS_THRESHOLD}\",
          \"new_capabilities\": [\"考虑提取成功模式为独立技能\"],
          \"priority\": 1
        }'),
        $(date +%s)
      );
      UPDATE skill_evolution SET evolution_pending = 'review',
        evolution_reason = '高成功率，考虑提取模式'
      WHERE skill_name = '$(echo "$SKILL" | sed "s/'/''/g")';
    " 2>/dev/null || true
  fi

done <<< "$SKILLS"

exit 0
