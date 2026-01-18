#!/usr/bin/env bash
# Statistical Analysis Runner

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVALS_DIR="$(dirname "$SCRIPT_DIR")"

RESULTS_DIR="${1:-$EVALS_DIR/results}"
TASK_ID="${2:-}"
FORMAT="${3:-markdown}"
OUTPUT="${4:-}"

python3 "$SCRIPT_DIR/statistical_analysis.py" \
  "$RESULTS_DIR" \
  ${TASK_ID:+--task-id "$TASK_ID"} \
  --format "$FORMAT" \
  ${OUTPUT:+--output "$OUTPUT"}
