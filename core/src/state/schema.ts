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
// 进化引擎表（v2 schema）
// ============================================================

/**
 * skill_usage_metrics 表
 * - 记录技能调用的使用指标
 * - 用于计算技能健康分数和触发进化提案
 */
export const CREATE_SKILL_USAGE_METRICS = `
  CREATE TABLE IF NOT EXISTS skill_usage_metrics (
    id              INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    session_id      TEXT    NOT NULL,
    skill_name      TEXT    NOT NULL,
    skill_version   TEXT    DEFAULT 'unknown',
    invocation_type TEXT    NOT NULL CHECK(invocation_type IN ('skill','command','agent','derived')),
    tool_name       TEXT,
    success         INTEGER NOT NULL DEFAULT 1 CHECK(success IN (0,1)),
    error_message   TEXT,
    duration_ms     INTEGER,
    tokens_used     INTEGER,
    recorded_at     INTEGER NOT NULL,
    context_json    TEXT    DEFAULT '{}'
  )
` as const;

/**
 * skill_evolution 表
 * - 每个技能的进化状态跟踪
 * - 健康分数 = success_rate * 0.6 + usage_score * 0.4
 */
export const CREATE_SKILL_EVOLUTION = `
  CREATE TABLE IF NOT EXISTS skill_evolution (
    id                INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    skill_name        TEXT    NOT NULL UNIQUE,
    version           TEXT    NOT NULL DEFAULT '1.0.0',
    status            TEXT    NOT NULL DEFAULT 'active'
                              CHECK(status IN ('active', 'deprecated', 'derived', 'captured')),
    parent_skill      TEXT,
    evolution_type    TEXT    CHECK(evolution_type IN ('fix', 'derived', 'captured')),
    health_score      REAL    NOT NULL DEFAULT 1.0,
    usage_count       INTEGER NOT NULL DEFAULT 0,
    success_rate      REAL    NOT NULL DEFAULT 1.0,
    last_used_at      INTEGER,
    last_evolved_at   INTEGER,
    evolution_pending TEXT    CHECK(evolution_pending IN ('none', 'fix', 'review', 'deprecate')),
    evolution_reason  TEXT,
    metadata_json     TEXT    DEFAULT '{}'
  )
` as const;

/**
 * skill_evolution_proposals 表
 * - 进化提案的工作流管理
 * - pending → approved/rejected → applied
 */
export const CREATE_SKILL_EVOLUTION_PROPOSALS = `
  CREATE TABLE IF NOT EXISTS skill_evolution_proposals (
    id              INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    skill_name      TEXT    NOT NULL,
    proposal_type   TEXT    NOT NULL
                            CHECK(proposal_type IN ('fix', 'derived', 'captured', 'deprecate')),
    proposal_json   TEXT    NOT NULL,
    created_at      INTEGER NOT NULL,
    status          TEXT    NOT NULL DEFAULT 'pending'
                            CHECK(status IN ('pending', 'approved', 'rejected', 'applied')),
    reviewed_at     INTEGER,
    reviewed_by     TEXT,
    applied_at      INTEGER
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
  `CREATE INDEX IF NOT EXISTS idx_skill_usage_skill_time
     ON skill_usage_metrics(skill_name, recorded_at)`,
  `CREATE INDEX IF NOT EXISTS idx_skill_usage_session
     ON skill_usage_metrics(session_id)`,
  `CREATE INDEX IF NOT EXISTS idx_skill_evolution_health
     ON skill_evolution(health_score)`,
  `CREATE INDEX IF NOT EXISTS idx_skill_evolution_pending
     ON skill_evolution(evolution_pending)`,
  `CREATE INDEX IF NOT EXISTS idx_evolution_proposals_status
     ON skill_evolution_proposals(status, created_at)`,
] as const;

// ============================================================
// 模式版本管理
// ============================================================

export const SCHEMA_VERSION = 2;

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
  CREATE_SKILL_USAGE_METRICS,
  CREATE_SKILL_EVOLUTION,
  CREATE_SKILL_EVOLUTION_PROPOSALS,
  ...CREATE_INDEXES,
];

/** v1 → v2 迁移 DDL（仅添加进化引擎表） */
export const MIGRATION_V2_DDL: readonly string[] = [
  CREATE_SKILL_USAGE_METRICS,
  CREATE_SKILL_EVOLUTION,
  CREATE_SKILL_EVOLUTION_PROPOSALS,
  `CREATE INDEX IF NOT EXISTS idx_skill_usage_skill_time
     ON skill_usage_metrics(skill_name, recorded_at)`,
  `CREATE INDEX IF NOT EXISTS idx_skill_usage_session
     ON skill_usage_metrics(session_id)`,
  `CREATE INDEX IF NOT EXISTS idx_skill_evolution_health
     ON skill_evolution(health_score)`,
  `CREATE INDEX IF NOT EXISTS idx_skill_evolution_pending
     ON skill_evolution(evolution_pending)`,
  `CREATE INDEX IF NOT EXISTS idx_evolution_proposals_status
     ON skill_evolution_proposals(status, created_at)`,
];
