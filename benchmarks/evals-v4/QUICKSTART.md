# Evals v4 クイックスタート

## 前提条件

1. Python 3.10+
2. Claude Agent SDK インストール済み
3. Claude Code にログイン済み（ローカル認証）

## セットアップ

```bash
cd benchmarks/evals-v4

# 依存関係のインストール
pip3 install -r runners/requirements.txt
```

## スモークテスト

最小タスクで全経路が動くことを確認:

```bash
python3 runners/smoke_test.py
```

## 評価実行

### 1. 単一タスク（1回）

```bash
./runners/run_eval.sh \
  --task-yaml tasks/workflow/workflow-tasks.yaml \
  --task-id WF-01 \
  --iterations 1
```

### 2. 統計的に有意な評価（10回）

```bash
./runners/run_eval.sh \
  --task-yaml tasks/workflow/workflow-tasks.yaml \
  --task-id WF-01 \
  --iterations 10
```

### 3. 結果の分析

```bash
./metrics/run_analysis.sh results/ WF-01 markdown report.md
cat report.md
```

## 評価次元

### Workflow (ワークフロー標準化)

```bash
./runners/run_eval.sh \
  --task-yaml tasks/workflow/workflow-tasks.yaml \
  --task-id WF-01 \
  --iterations 10
```

### SSOT (知識蓄積)

```bash
./runners/run_eval.sh \
  --task-yaml tasks/ssot/ssot-tasks.yaml \
  --task-id SSOT-01 \
  --iterations 5
```

### Guardrails (ガードレール)

```bash
./runners/run_eval.sh \
  --task-yaml tasks/guardrails/guardrails-tasks.yaml \
  --task-id GR-01 \
  --iterations 10
```

## トラブルシューティング

### SDKが見つからない

```bash
pip3 install claude-agent-sdk
```

### プラグインディレクトリの自動検出が失敗

```bash
./runners/run_eval.sh \
  --task-yaml tasks/workflow/workflow-tasks.yaml \
  --task-id WF-01 \
  --plugin-dir /path/to/claude-code-harness
```

### Model-based graderでエラー

API keyが必要です:

```bash
export ANTHROPIC_API_KEY=your_key
```

または `--no-llm` フラグでスキップ:

```bash
python3 graders/model_grader.py project_dir --no-llm --json
```
