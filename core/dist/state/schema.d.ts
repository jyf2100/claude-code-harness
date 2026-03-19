/**
 * core/src/state/schema.ts
 * Harness v3 SQLite テーブル定義
 *
 * better-sqlite3 を使用して、セッション状態・エージェント間シグナル・
 * タスク失敗イベントを単一の SQLite ファイルで管理する。
 */
/**
 * sessions テーブル
 * - session_id: Claude Code が発行するセッション識別子
 * - mode: normal | work | codex | breezing
 * - project_root: セッションが紐付くプロジェクトルート
 * - started_at: セッション開始時刻（Unix タイムスタンプ秒）
 * - ended_at: セッション終了時刻（NULL = アクティブ）
 * - context_json: 任意の追加情報（JSON テキスト）
 */
export declare const CREATE_SESSIONS: "\n  CREATE TABLE IF NOT EXISTS sessions (\n    session_id   TEXT    NOT NULL PRIMARY KEY,\n    mode         TEXT    NOT NULL CHECK(mode IN ('normal','work','codex','breezing')),\n    project_root TEXT    NOT NULL,\n    started_at   INTEGER NOT NULL,\n    ended_at     INTEGER,\n    context_json TEXT    DEFAULT '{}'\n  )\n";
/**
 * signals テーブル
 * - id: 自動採番 PK
 * - type: シグナル種別（SignalType）
 * - from_session_id: 送信元セッション
 * - to_session_id: 宛先セッション（NULL = ブロードキャスト）
 * - payload_json: ペイロード（JSON テキスト）
 * - sent_at: 送信時刻（Unix タイムスタンプ秒）
 * - consumed: 受信済みフラグ
 */
export declare const CREATE_SIGNALS: "\n  CREATE TABLE IF NOT EXISTS signals (\n    id              INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,\n    type            TEXT    NOT NULL,\n    from_session_id TEXT    NOT NULL,\n    to_session_id   TEXT,\n    payload_json    TEXT    NOT NULL DEFAULT '{}',\n    sent_at         INTEGER NOT NULL,\n    consumed        INTEGER NOT NULL DEFAULT 0 CHECK(consumed IN (0,1))\n  )\n";
/**
 * task_failures テーブル
 * - id: 自動採番 PK
 * - task_id: 失敗したタスクの識別子
 * - session_id: タスクを実行していたセッション（外部参照）
 * - severity: warning | error | critical
 * - message: 失敗の説明
 * - detail: スタックトレース等の詳細情報（NULL 可）
 * - failed_at: 失敗時刻（Unix タイムスタンプ秒）
 * - attempt: 試行回数（1 始まり）
 */
export declare const CREATE_TASK_FAILURES: "\n  CREATE TABLE IF NOT EXISTS task_failures (\n    id         INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,\n    task_id    TEXT    NOT NULL,\n    session_id TEXT    NOT NULL,\n    severity   TEXT    NOT NULL CHECK(severity IN ('warning','error','critical')),\n    message    TEXT    NOT NULL,\n    detail     TEXT,\n    failed_at  INTEGER NOT NULL,\n    attempt    INTEGER NOT NULL DEFAULT 1 CHECK(attempt >= 1)\n  )\n";
/**
 * work_states テーブル
 * - work-active.json の後継。work/codex/breezing モードの状態を管理
 * - session_id: 紐付くセッション ID
 * - codex_mode: codex モードフラグ
 * - bypass_rm_rf: rm -rf ガードバイパスフラグ
 * - bypass_git_push: git push ガードバイパスフラグ
 * - expires_at: 有効期限（24 時間後の Unix タイムスタンプ秒）
 */
export declare const CREATE_WORK_STATES: "\n  CREATE TABLE IF NOT EXISTS work_states (\n    session_id      TEXT    NOT NULL PRIMARY KEY,\n    codex_mode      INTEGER NOT NULL DEFAULT 0 CHECK(codex_mode IN (0,1)),\n    bypass_rm_rf    INTEGER NOT NULL DEFAULT 0 CHECK(bypass_rm_rf IN (0,1)),\n    bypass_git_push INTEGER NOT NULL DEFAULT 0 CHECK(bypass_git_push IN (0,1)),\n    expires_at      INTEGER NOT NULL,\n    FOREIGN KEY (session_id) REFERENCES sessions(session_id)\n  )\n";
export declare const CREATE_INDEXES: readonly ["CREATE INDEX IF NOT EXISTS idx_signals_to_session\n     ON signals(to_session_id, consumed)", "CREATE INDEX IF NOT EXISTS idx_signals_from_session\n     ON signals(from_session_id, sent_at)", "CREATE INDEX IF NOT EXISTS idx_task_failures_task\n     ON task_failures(task_id, failed_at)", "CREATE INDEX IF NOT EXISTS idx_work_states_expires\n     ON work_states(expires_at)"];
export declare const SCHEMA_VERSION = 1;
export declare const CREATE_SCHEMA_META: "\n  CREATE TABLE IF NOT EXISTS schema_meta (\n    key   TEXT NOT NULL PRIMARY KEY,\n    value TEXT NOT NULL\n  )\n";
/** DB 初期化時に順番に実行する DDL の配列 */
export declare const ALL_DDL: readonly string[];
//# sourceMappingURL=schema.d.ts.map