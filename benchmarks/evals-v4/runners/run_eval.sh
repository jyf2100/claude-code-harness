#!/usr/bin/env bash
# Eval Runner v4 実行スクリプト

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVALS_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_ROOT="$(cd "$EVALS_DIR/../.." && pwd)"

# デフォルト値
TASK_YAML=""
TASK_ID=""
ITERATIONS=1
RESULTS_DIR="$EVALS_DIR/results"
WORK_DIR=""
AGENT_MODEL_PROVIDER="default"
GLM_ENDPOINT="https://api.z.ai/api/anthropic"
GLM_MODEL="glm-4.7"
GLM_API_KEY=""
GLM_ENV_FILE=""

# ヘルプ
show_help() {
  cat <<EOF
Eval Runner v4: SDK-Based Evaluation Harness

Usage: $0 [OPTIONS]

OPTIONS:
  --task-yaml <path>    Path to task YAML file
  --task-id <id>        Task ID to run
  --iterations <n>      Number of iterations (default: 1)
  --plugin-dir <path>   Path to plugin directory (default: auto-detect)
  --results-dir <path>  Results directory (default: ./results)
  --work-dir <path>     Base work directory (optional)
  --agent-model-provider <name>  Agent model provider (default: default)
  --glm-endpoint <url>   GLM Anthropic-compatible endpoint
  --glm-model <name>     GLM model name
  --glm-api-key <key>    GLM API key (optional)
  --glm-env-file <path>  .env file containing GLM_API_KEY
  --help                Show this help

EXAMPLES:
  # Run workflow task WF-01 once
  $0 --task-yaml tasks/workflow/workflow-tasks.yaml --task-id WF-01

  # Run with 10 iterations
  $0 --task-yaml tasks/workflow/workflow-tasks.yaml --task-id WF-01 --iterations 10

  # Run guardrails task
  $0 --task-yaml tasks/guardrails/guardrails-tasks.yaml --task-id GR-01
EOF
}

# 引数解析
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-yaml)
      TASK_YAML="$2"
      shift 2
      ;;
    --task-id)
      TASK_ID="$2"
      shift 2
      ;;
    --iterations)
      ITERATIONS="$2"
      shift 2
      ;;
    --plugin-dir)
      PLUGIN_DIR="$2"
      shift 2
      ;;
    --results-dir)
      RESULTS_DIR="$2"
      shift 2
      ;;
    --work-dir)
      WORK_DIR="$2"
      shift 2
      ;;
    --agent-model-provider)
      AGENT_MODEL_PROVIDER="$2"
      shift 2
      ;;
    --glm-endpoint)
      GLM_ENDPOINT="$2"
      shift 2
      ;;
    --glm-model)
      GLM_MODEL="$2"
      shift 2
      ;;
    --glm-api-key)
      GLM_API_KEY="$2"
      shift 2
      ;;
    --glm-env-file)
      GLM_ENV_FILE="$2"
      shift 2
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# バリデーション
if [[ -z "$TASK_YAML" || -z "$TASK_ID" ]]; then
  echo "Error: --task-yaml and --task-id are required"
  show_help
  exit 1
fi

# プラグインディレクトリの自動検出
if [[ -z "${PLUGIN_DIR:-}" ]]; then
  PLUGIN_DIR="$PLUGIN_ROOT"
fi

# Python環境の確認
if ! command -v python3 &> /dev/null; then
  echo "Error: python3 is required"
  exit 1
fi

# 依存関係のインストール確認
if ! python3 -c "import claude_agent_sdk" 2>/dev/null; then
  echo "Installing dependencies..."
  pip3 install -r "$SCRIPT_DIR/requirements.txt"
fi

# ランナーを実行
python3 "$SCRIPT_DIR/eval_runner.py" \
  --task-yaml "$TASK_YAML" \
  --task-id "$TASK_ID" \
  --iterations "$ITERATIONS" \
  --plugin-dir "$PLUGIN_DIR" \
  --results-dir "$RESULTS_DIR" \
  --agent-model-provider "$AGENT_MODEL_PROVIDER" \
  --glm-endpoint "$GLM_ENDPOINT" \
  --glm-model "$GLM_MODEL" \
  ${GLM_API_KEY:+--glm-api-key "$GLM_API_KEY"} \
  ${GLM_ENV_FILE:+--glm-env-file "$GLM_ENV_FILE"} \
  ${WORK_DIR:+--work-dir "$WORK_DIR"}

echo ""
echo "=== Evaluation Complete ==="
echo "Results saved to: $RESULTS_DIR"
