/**
 * core/src/state/schema.ts
 * Harness v3 SQLite テーブル定義
 *
 * better-sqlite3 を使用して、セッション状態・エージェント間シグナル・
 * タスク失敗イベントを単一の SQLite ファイルで管理する。
 */
// ============================================================
// テーブル作成 DDL
// ============================================================
/**
 * sessions テーブル
 * - session_id: Claude Code が発行するセッション識別子
 * - mode: normal | work | codex | breezing
 * - project_root: セッションが紐付くプロジェクトルート
 * - started_at: セッション開始時刻（Unix タイムスタンプ秒）
 * - ended_at: セッション終了時刻（NULL = アクティブ）
 * - context_json: 任意の追加情報（JSON テキスト）
 */
export const CREATE_SESSIONS = `
  CREATE TABLE IF NOT EXISTS sessions (
    session_id   TEXT    NOT NULL PRIMARY KEY,
    mode         TEXT    NOT NULL CHECK(mode IN ('normal','work','codex','breezing')),
    project_root TEXT    NOT NULL,
    started_at   INTEGER NOT NULL,
    ended_at     INTEGER,
    context_json TEXT    DEFAULT '{}'
  )
`;
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
export const CREATE_SIGNALS = `
  CREATE TABLE IF NOT EXISTS signals (
    id              INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    type            TEXT    NOT NULL,
    from_session_id TEXT    NOT NULL,
    to_session_id   TEXT,
    payload_json    TEXT    NOT NULL DEFAULT '{}',
    sent_at         INTEGER NOT NULL,
    consumed        INTEGER NOT NULL DEFAULT 0 CHECK(consumed IN (0,1))
  )
`;
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
export const CREATE_TASK_FAILURES = `
  CREATE TABLE IF NOT EXISTS task_failures (
    id         INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    task_id    TEXT    NOT NULL,
    session_id TEXT    NOT NULL,
    severity   TEXT    NOT NULL CHECK(severity IN ('warning','error','critical')),
    message    TEXT    NOT NULL,
    detail     TEXT,
    failed_at  INTEGER NOT NULL,
    attempt    INTEGER NOT NULL DEFAULT 1 CHECK(attempt >= 1)
  )
`;
/**
 * work_states テーブル
 * - work-active.json の後継。work/codex/breezing モードの状態を管理
 * - session_id: 紐付くセッション ID
 * - codex_mode: codex モードフラグ
 * - bypass_rm_rf: rm -rf ガードバイパスフラグ
 * - bypass_git_push: git push ガードバイパスフラグ
 * - expires_at: 有効期限（24 時間後の Unix タイムスタンプ秒）
 */
export const CREATE_WORK_STATES = `
  CREATE TABLE IF NOT EXISTS work_states (
    session_id      TEXT    NOT NULL PRIMARY KEY,
    codex_mode      INTEGER NOT NULL DEFAULT 0 CHECK(codex_mode IN (0,1)),
    bypass_rm_rf    INTEGER NOT NULL DEFAULT 0 CHECK(bypass_rm_rf IN (0,1)),
    bypass_git_push INTEGER NOT NULL DEFAULT 0 CHECK(bypass_git_push IN (0,1)),
    expires_at      INTEGER NOT NULL,
    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
  )
`;
// ============================================================
// インデックス
// ============================================================
export const CREATE_INDEXES = [
    `CREATE INDEX IF NOT EXISTS idx_signals_to_session
     ON signals(to_session_id, consumed)`,
    `CREATE INDEX IF NOT EXISTS idx_signals_from_session
     ON signals(from_session_id, sent_at)`,
    `CREATE INDEX IF NOT EXISTS idx_task_failures_task
     ON task_failures(task_id, failed_at)`,
    `CREATE INDEX IF NOT EXISTS idx_work_states_expires
     ON work_states(expires_at)`,
];
// ============================================================
// スキーマバージョン管理
// ============================================================
export const SCHEMA_VERSION = 1;
export const CREATE_SCHEMA_META = `
  CREATE TABLE IF NOT EXISTS schema_meta (
    key   TEXT NOT NULL PRIMARY KEY,
    value TEXT NOT NULL
  )
`;
// ============================================================
// エクスポート: 初期化時に実行する DDL リスト
// ============================================================
/** DB 初期化時に順番に実行する DDL の配列 */
export const ALL_DDL = [
    CREATE_SCHEMA_META,
    CREATE_SESSIONS,
    CREATE_SIGNALS,
    CREATE_TASK_FAILURES,
    CREATE_WORK_STATES,
    ...CREATE_INDEXES,
];
//# sourceMappingURL=schema.js.map