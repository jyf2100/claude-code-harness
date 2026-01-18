# Evals v3 失敗分析

## 失敗原因の特定

### 1. expectスクリプトによるUI操作依存

**問題点**:
- `claude-qa-expect.exp`がUIの文字列パターンに依存
- UI変更（プロンプト表示、選択肢形式など）で即座に失敗
- タイミング依存（`sleep`で調整）で不安定

**具体例**:
```tcl
# expectスクリプト内
expect {
    -re {❯\s*Try} {
        send "$prompt"
        send "\r"
    }
    timeout {
        puts "ERROR: Timeout waiting for Claude prompt"
        exit 1
    }
}
```

**影響**: UIのマイナーな変更でも評価が動かなくなる。

### 2. HOME環境変数の操作によるプラグイン無効化

**問題点**:
- 一時的なHOMEディレクトリを作成してプラグインを無効化
- 認証情報のコピーが必要で複雑
- 環境依存（特定パス `/Users/tachibanashuuta/.credentials.json` に依存）

**具体例**:
```bash
# run-statistical-eval.sh内
if [[ "$use_plugin" == "false" ]]; then
    temp_home=$(mktemp -d)
    mkdir -p "$temp_home/.claude"
    if [[ -f "/Users/tachibanashuuta/.credentials.json" ]]; then
        cp "/Users/tachibanashuuta/.credentials.json" "$temp_home/.claude/.credentials.json"
    fi
    export HOME="$temp_home"
fi
```

**影響**: 環境ごとに動作が異なり、再現性が低い。

### 3. 対話的なQ&Aが必要

**問題点**:
- 曖昧なプロンプトに対してClaudeが質問を返す
- expectスクリプトで質問に自動回答する必要がある
- 質問の形式が変わると自動回答が失敗

**具体例**:
```bash
# タスク別の回答を定義
TASK_ANSWERS["VP-01"]="とりあえずシンプルなやつでいい|メモリでいい、後でデータベースにできるなら|パスワードは安全に保存してほしい"
```

**影響**: 質問の形式が予測不能で、自動化が困難。

### 4. タイムアウト処理が不十分

**問題点**:
- expectスクリプトのタイムアウトが固定（180秒）
- 長時間実行が必要なタスクで失敗
- エラーハンドリングが不十分

### 5. ログ収集が不完全

**問題点**:
- 標準出力のみをファイルにリダイレクト
- エラーメッセージの詳細が失われる
- トランスクリプトが不完全

## v4での解決策

### 1. SDKベースのヘッドレス実行

- UI操作を完全に排除
- `query()`関数で直接API呼び出し
- トランスクリプトを完全に記録

### 2. `settingSources`によるプラグイン制御

- HOME環境変数の操作不要
- SDKの`settingSources`パラメータで制御
- シンプルで確実

### 3. 非対話タスクへの移行

- 曖昧なプロンプトではなく、明確なタスク定義を使用
- Q&Aを排除し、参照解と比較する方式に変更
- または、SDKで対話制御を実装（より複雑だが可能）

### 4. 適切なタイムアウトとエラーハンドリング

- `max_turns`で制御
- 例外処理を適切に実装
- リトライロジックを追加

### 5. 完全なトランスクリプト記録

- SDKの`query()`が返す全メッセージを記録
- JSON形式で保存
- 後から分析可能

## 移行チェックリスト

- [x] SDK仕様の確定
- [ ] v3の失敗点の文書化（このファイル）
- [ ] v4ランナーの実装
- [ ] タスク定義の再設計
- [ ] グレーダーの刷新
- [ ] スモークテスト
