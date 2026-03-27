/**
 * core/src/state/schema.ts
 * Harness v3 SQLite 表定义
 *
 * 使用 better-sqlite3，将会话状态、代理间信号、
 * 任务失败事件在单个 SQLite 文件中管理。
 */

// ============================================================
// 表创建 DDL
// ============================================================

/**
 * sessions 表
 * - session_id: Claude Code 发行的会话标识符
 * - mode: normal | work | codex | breezing
 * - project_root: 会话关联的项目根目录
 * - started_at: 会话开始时间（Unix 时间戳秒）
 * - ended_at: 会话结束时间（NULL = 活跃）
 * - context_json: 任意附加信息（JSON 文本）
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
` as const;

/**
 * signals 表
 * - id: 自增主键
 * - type: 信号类型（SignalType）
 * - from_session_id: 发送方会话
 * - to_session_id: 接收方会话（NULL = 广播）
 * - payload_json: 载荷（JSON 文本）
 * - sent_at: 发送时间（Unix 时间戳秒）
 * - consumed: 已接收标志
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
` as const;

/**
 * task_failures 表
 * - id: 自增主键
 * - task_id: 失败任务的标识符
 * - session_id: 执行任务的会话（外键引用）
 * - severity: warning | error | critical
 * - message: 失败说明
 * - detail: 堆栈跟踪等详细信息（可为 NULL）
 * - failed_at: 失败时间（Unix 时间戳秒）
 * - attempt: 尝试次数（从 1 开始）
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
` as const;

/**
 * work_states 表
 * - work-active.json 的后继。管理 work/codex/breezing 模式的状态
 * - session_id: 关联的会话 ID
 * - codex_mode: codex 模式标志
 * - bypass_rm_rf: rm -rf 守护绕过标志
 * - bypass_git_push: git push 守护绕过标志
 * - expires_at: 有效期（24 小时后的 Unix 时间戳秒）
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
` as const;

// ============================================================
// 索引
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
] as const;

// ============================================================
// 模式版本管理
// ============================================================

export const SCHEMA_VERSION = 1;

export const CREATE_SCHEMA_META = `
  CREATE TABLE IF NOT EXISTS schema_meta (
    key   TEXT NOT NULL PRIMARY KEY,
    value TEXT NOT NULL
  )
` as const;

// ============================================================
// 导出: 初始化时执行的 DDL 列表
// ============================================================

/** 数据库初始化时按顺序执行的 DDL 数组 */
export const ALL_DDL: readonly string[] = [
  CREATE_SCHEMA_META,
  CREATE_SESSIONS,
  CREATE_SIGNALS,
  CREATE_TASK_FAILURES,
  CREATE_WORK_STATES,
  ...CREATE_INDEXES,
];
