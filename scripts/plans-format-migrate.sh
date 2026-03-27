#!/bin/bash
# plans-format-migrate.sh
# 将 Plans.md 旧格式迁移到新格式

set -uo pipefail

PLANS_FILE="${1:-Plans.md}"
DRY_RUN="${2:-false}"

# 彩色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Plans.md 格式迁移${NC}"
echo "=========================================="
echo ""

# Plans.md 不存在的情况
if [ ! -f "$PLANS_FILE" ]; then
  echo -e "${RED}错误: $PLANS_FILE 未找到${NC}"
  exit 1
fi

# 创建备份
BACKUP_DIR=".claude-code-harness/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp "$PLANS_FILE" "$BACKUP_DIR/Plans.md.backup"
echo -e "${GREEN}✓${NC} 已创建备份: $BACKUP_DIR/Plans.md.backup"

# 更改计数
CHANGES=0

# 1. cursor:WIP → pm:依頼中（解释为等待 PM 审核状态）
# 注意: cursor:WIP 通常意味着 "PM(Cursor) 正在审核"
# 在新格式中相当于 pm:依頼中（实现完成→等待 PM 审核）
if grep -qE 'cursor:WIP' "$PLANS_FILE" 2>/dev/null; then
  echo -e "${YELLOW}→${NC} 检测到 cursor:WIP"
  if [ "$DRY_RUN" = "false" ]; then
    sed -i '' 's/cursor:WIP/pm:依頼中/g' "$PLANS_FILE" 2>/dev/null || \
    sed -i 's/cursor:WIP/pm:依頼中/g' "$PLANS_FILE"
    echo -e "  ${GREEN}✓${NC} cursor:WIP → pm:依頼中 转换完成"
  else
    echo -e "  [预演] cursor:WIP → pm:依頼中 将被转换"
  fi
  ((CHANGES++))
fi

# 2. cursor:完了 → pm:確認済
if grep -qE 'cursor:完了' "$PLANS_FILE" 2>/dev/null; then
  echo -e "${YELLOW}→${NC} 检测到 cursor:完了"
  if [ "$DRY_RUN" = "false" ]; then
    sed -i '' 's/cursor:完了/pm:確認済/g' "$PLANS_FILE" 2>/dev/null || \
    sed -i 's/cursor:完了/pm:確認済/g' "$PLANS_FILE"
    echo -e "  ${GREEN}✓${NC} cursor:完了 → pm:確認済 转换完成"
  else
    echo -e "  [预演] cursor:完了 → pm:確認済 将被转换"
  fi
  ((CHANGES++))
fi

# 3. 检查标记图例部分的更新
if ! grep -qE '## マーカー凡例|## Marker Legend' "$PLANS_FILE" 2>/dev/null; then
  echo -e "${YELLOW}→${NC} 没有标记图例部分"
  echo -e "  ${YELLOW}!${NC} 建议手动添加"
fi

# 显示结果
echo ""
echo "=========================================="
if [ $CHANGES -gt 0 ]; then
  if [ "$DRY_RUN" = "false" ]; then
    echo -e "${GREEN}✓ 迁移完成: $CHANGES 处更改${NC}"
    echo ""
    echo "请确认更改内容:"
    echo "  git diff $PLANS_FILE"
  else
    echo -e "${YELLOW}预演: 计划进行 $CHANGES 处更改${NC}"
    echo ""
    echo "实际执行转换:"
    echo "  ./scripts/plans-format-migrate.sh $PLANS_FILE false"
  fi
else
  echo -e "${GREEN}✓ 无需更改。格式已是最新。${NC}"
fi
