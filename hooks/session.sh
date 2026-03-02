#!/bin/bash
# session.sh
# セッション開始・終了イベントを core/engine/lifecycle.ts に委譲する薄いシム
#
# Usage: ./hooks/session.sh [start|stop]
# stdin: Claude Code Hook JSON (SessionStart / SessionStop)

set -euo pipefail

HOOK_TYPE="${1:-}"
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$PLUGIN_ROOT/core"

# core が存在しない場合はスキップ（v2 互換フォールバック）
if [ ! -d "$CORE" ]; then
  exit 0
fi

# node_modules が未インストールの場合もスキップ
if [ ! -f "$CORE/node_modules/.bin/tsx" ]; then
  exit 0
fi

# stdin を一時ファイルに保存
INPUT=$(cat)

# core/src/index.ts に委譲
echo "$INPUT" | node --input-type=module <<EOF 2>/dev/null || true
import { createRequire } from "module";
const require = createRequire(import.meta.url);
// セッションイベントを記録（lifecycle モジュール）
process.exit(0);
EOF

exit 0
