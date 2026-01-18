# Evals v4: SDK-Based Evaluation System

## 概要

Claude Agent SDKを使用したヘッドレス評価システム。UI操作やexpect依存を排除し、再現性と信頼性を確保する。

## アーキテクチャ

```
EvalHarness (Python/TypeScript)
  ├─ TaskDefinitions (YAML)
  ├─ IsolatedEnv (クリーンな作業ディレクトリ)
  ├─ AgentHarness (Claude Agent SDK)
  │   ├─ with-plugin mode (settingSources=["project"])
  │   └─ without-plugin mode (settingSources=[])
  ├─ TranscriptLog (全トランザクション記録)
  ├─ Graders (Code-based + Model-based)
  └─ Metrics (pass@k, pass^k, 統計)
```

## SDK仕様（確定）

### Python API

```python
from claude_agent_sdk import query, ClaudeAgentOptions

# プラグイン有効モード
options_with_plugin = ClaudeAgentOptions(
    system_prompt="claude_code",  # Claude Codeのシステムプロンプト
    allowed_tools=["Read", "Write", "Skill", "Bash", ...],
    setting_sources=["project"],  # プラグイン読み込み
    cwd="/path/to/project",
    permission_mode="bypassPermissions",
)

# プラグイン無効モード
options_without_plugin = ClaudeAgentOptions(
    system_prompt="claude_code",
    allowed_tools=["Read", "Write", "Bash", ...],
    setting_sources=[],  # プラグイン読み込みなし
    cwd="/path/to/project",
    permission_mode="bypassPermissions",
)

# 実行
async for message in query(prompt="タスクプロンプト", options=options_with_plugin):
    # メッセージ処理
    pass
```

### TypeScript API

```typescript
import { query, ClaudeAgentOptions } from '@anthropic-ai/claude-agent-sdk';

const optionsWithPlugin: ClaudeAgentOptions = {
  systemPrompt: 'claude_code',
  allowedTools: ['Read', 'Write', 'Skill', 'Bash', ...],
  settingSources: ['project'],  // プラグイン読み込み
  cwd: '/path/to/project',
  permissionMode: 'bypassPermissions',
};

const optionsWithoutPlugin: ClaudeAgentOptions = {
  systemPrompt: 'claude_code',
  allowedTools: ['Read', 'Write', 'Bash', ...],
  settingSources: [],  // プラグイン読み込みなし
  cwd: '/path/to/project',
  permissionMode: 'bypassPermissions',
};

for await (const message of query({
  prompt: 'タスクプロンプト',
  options: optionsWithPlugin
})) {
  // メッセージ処理
}
```

## 評価次元

1. **Workflow**: Plan→Work→Reviewの標準化効果
2. **SSOT**: decisions.md/patterns.mdの知識蓄積効果
3. **Guardrails**: Hooksによるガードレール効果

## ディレクトリ構造

```
evals-v4/
├── README.md (このファイル)
├── tasks/           # タスク定義YAML
│   ├── workflow/
│   ├── ssot/
│   └── guardrails/
├── runners/         # 評価ランナー
│   ├── eval_runner.py
│   └── eval_runner.ts
├── graders/         # グレーダー
│   ├── code_grader.py
│   └── model_grader.py
├── metrics/         # 統計分析
│   └── statistical_analysis.py
├── results/         # 評価結果
└── reference/       # 参照解
```

## 実装状況

### 完了項目

- [x] SDK仕様の確定 (`SDK_SPEC.md`)
- [x] v3失敗分析 (`FAILURE_ANALYSIS.md`)
- [x] タスク定義の再設計 (3軸: workflow, ssot, guardrails)
- [x] 評価ランナーの実装 (`runners/eval_runner.py`)
- [x] グレーダーの実装 (`graders/code_grader.py`, `graders/model_grader.py`)
- [x] 統計分析の実装 (`metrics/statistical_analysis.py`)
- [x] スモークテスト (`runners/smoke_test.py`)
- [x] 統合ガイド (`INTEGRATION.md`, `QUICKSTART.md`)

### 使用方法

詳細は `QUICKSTART.md` を参照。

```bash
# スモークテスト
python3 runners/smoke_test.py

# 評価実行
./runners/run_eval.sh --task-yaml tasks/workflow/workflow-tasks.yaml --task-id WF-01 --iterations 1

# 統計分析
./metrics/run_analysis.sh results/ WF-01 markdown report.md
```

## 参考

- [Anthropic: Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)
- [Claude Agent SDK Documentation](https://docs.claude.com/en/docs/agent-sdk/overview)
- [Deepchecks: LLM Evaluation Framework](https://www.deepchecks.com/llm-evaluation/framework/)
