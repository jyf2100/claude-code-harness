# Evals v4 統合ガイド

## 全体フロー

```
1. タスク定義 (YAML)
   ↓
2. 評価ランナー実行
   ├─ クリーン環境作成
   ├─ SDK経由でClaude Code実行 (with-plugin / without-plugin)
   ├─ トランスクリプト記録
   └─ 結果保存
   ↓
3. グレーディング
   ├─ Code-based grader (成果物検証)
   └─ Model-based grader (LLM評価)
   ↓
4. 統計分析
   ├─ pass@k / pass^k 計算
   ├─ 効果量 (Cohen's d)
   └─ 信頼区間
   ↓
5. レポート生成
```

## 実行例

### 1. 単一タスクの評価

```bash
cd benchmarks/evals-v4

# Workflowタスク WF-01 を1回実行
./runners/run_eval.sh \
  --task-yaml tasks/workflow/workflow-tasks.yaml \
  --task-id WF-01 \
  --iterations 1
```

### 2. 複数イテレーションの評価

```bash
# 10回実行して統計的に有意な結果を得る
./runners/run_eval.sh \
  --task-yaml tasks/workflow/workflow-tasks.yaml \
  --task-id WF-01 \
  --iterations 10
```

### 3. 統計分析

```bash
# 結果を分析してレポート生成
./metrics/run_analysis.sh results/ WF-01 markdown report.md
```

### 4. グレーディング

```bash
# Code-based grading
python3 graders/code_grader.py results/WF-01/with-plugin/iter_1/project --json

# Model-based grading (API key必要)
export ANTHROPIC_API_KEY=your_key
python3 graders/model_grader.py results/WF-01/with-plugin/iter_1/project --json
```

## ディレクトリ構造

```
evals-v4/
├── README.md
├── SDK_SPEC.md
├── FAILURE_ANALYSIS.md
├── INTEGRATION.md (このファイル)
├── tasks/
│   ├── workflow/workflow-tasks.yaml
│   ├── ssot/ssot-tasks.yaml
│   └── guardrails/guardrails-tasks.yaml
├── runners/
│   ├── eval_runner.py
│   ├── run_eval.sh
│   └── requirements.txt
├── graders/
│   ├── code_grader.py
│   └── model_grader.py
├── metrics/
│   ├── statistical_analysis.py
│   └── run_analysis.sh
└── results/
    └── {task_id}/
        ├── with-plugin/
        │   └── iter_{n}/
        │       ├── transcript.json
        │       ├── result.json
        │       └── project/
        └── without-plugin/
            └── iter_{n}/
                ├── transcript.json
                ├── result.json
                └── project/
```

## トラブルシューティング

### SDKがインストールされていない

```bash
pip3 install -r runners/requirements.txt
```

### APIキーが設定されていない（Model-based grader用）

```bash
export ANTHROPIC_API_KEY=your_key
```

### プラグインディレクトリが見つからない

```bash
# プラグインディレクトリを明示的に指定
./runners/run_eval.sh \
  --task-yaml tasks/workflow/workflow-tasks.yaml \
  --task-id WF-01 \
  --plugin-dir /path/to/claude-code-harness
```

## 次のステップ

1. スモークテスト: 最小タスクで動作確認
2. 小規模評価: N=5で試行
3. 本番評価: N=20-30で統計的に有意な結果を得る
