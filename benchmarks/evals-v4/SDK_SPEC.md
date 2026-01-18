# Claude Agent SDK 仕様書（評価システム用）

## 目的

評価システムで使用するClaude Agent SDKのインターフェース仕様を確定し、後から壊れない前提を作る。

## 基本API

### Python

```python
from claude_agent_sdk import query, ClaudeAgentOptions
import asyncio

async def run_eval_task(prompt: str, use_plugin: bool, project_dir: str):
    options = ClaudeAgentOptions(
        system_prompt="claude_code",
        allowed_tools=["Read", "Write", "Glob", "Grep", "Bash", "Skill"],
        setting_sources=["project"] if use_plugin else [],
        cwd=project_dir,
        permission_mode="bypassPermissions",
        max_turns=50,  # 必要に応じて調整
    )
    
    transcript = []
    async for message in query(prompt=prompt, options=options):
        transcript.append(message)
        # メッセージタイプ: 'user', 'assistant', 'tool_use', 'tool_result'
    
    return transcript
```

### TypeScript

```typescript
import { query, ClaudeAgentOptions } from '@anthropic-ai/claude-agent-sdk';

async function runEvalTask(
  prompt: string,
  usePlugin: boolean,
  projectDir: string
): Promise<any[]> {
  const options: ClaudeAgentOptions = {
    systemPrompt: 'claude_code',
    allowedTools: ['Read', 'Write', 'Glob', 'Grep', 'Bash', 'Skill'],
    settingSources: usePlugin ? ['project'] : [],
    cwd: projectDir,
    permissionMode: 'bypassPermissions',
    maxTurns: 50,
  };

  const transcript: any[] = [];
  for await (const message of query({ prompt, options })) {
    transcript.push(message);
  }

  return transcript;
}
```

## プラグイン有無の切り替え

**重要**: `settingSources`パラメータで制御する。

- **プラグイン有効**: `settingSources=["project"]` または `settingSources: ["project"]`
- **プラグイン無効**: `settingSources=[]` または `settingSources: []`

`settingSources`に`"project"`を含めると、プロジェクトディレクトリの`.claude-plugin/`が読み込まれ、プラグインが有効になる。

## 環境変数

- `ANTHROPIC_API_KEY`: APIキー使用時（オプション）
- ローカル認証: Claude Codeにログイン済みなら自動で使用される

## トランスクリプト形式

各メッセージは以下の形式:

```python
{
    "type": "user" | "assistant" | "tool_use" | "tool_result",
    "content": [...],  # メッセージ内容
    "id": "...",       # メッセージID
    # その他のメタデータ
}
```

## エラーハンドリング

```python
try:
    async for message in query(prompt=prompt, options=options):
        # 処理
        pass
except Exception as e:
    # エラー処理
    print(f"Error: {e}")
```

## 制約事項

1. **非決定論性**: 同じプロンプトでも異なる結果が返る可能性がある → 複数トライアル必須
2. **タイムアウト**: 長時間実行は`max_turns`で制限
3. **リソース**: 各試行は完全に独立した環境で実行する必要がある

## 検証済みバージョン

- Python: `claude-agent-sdk` (最新)
- TypeScript: `@anthropic-ai/claude-agent-sdk` (最新)

## 参考リンク

- [Python SDK Docs](https://docs.claude.com/en/docs/agent-sdk/python)
- [TypeScript SDK Docs](https://docs.claude.com/en/docs/agent-sdk/typescript)
