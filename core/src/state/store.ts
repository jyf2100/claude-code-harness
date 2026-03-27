/**
 * core/src/state/store.ts
 * Harness v3 SQLite 存储
 *
 * 使用 better-sqlite3 操作 sessions / signals / task_failures / work_states
 * 表的封装类。
 * 利用同步 API（better-sqlite3 的特性），实现简单且健壮的设计。
 */

import { createRequire } from "node:module";
import { ALL_DDL, SCHEMA_VERSION, CREATE_SCHEMA_META } from "./schema.js";
import type { Signal, SessionState, TaskFailure } from "../types.js";
import type DatabaseConstructor from "better-sqlite3";

// 从 ESM 加载 CommonJS 原生模块的标准模式
const require = createRequire(import.meta.url);
const Database = require("better-sqlite3") as typeof DatabaseConstructor;

// ============================================================
// 类型定义
// ============================================================

/** better-sqlite3 的 Database 实例类型 */
type BetterSqliteDB = InstanceType<typeof Database>;

/** work_states 记录的行类型 */
interface WorkStateRow {
  session_id: string;
  codex_mode: number;
  bypass_rm_rf: number;
  bypass_git_push: number;
  expires_at: number;
}

/** sessions 记录的行类型 */
interface SessionRow {
  session_id: string;
  mode: string;
  project_root: string;
  started_at: number;
  ended_at: number | null;
  context_json: string;
}

// ============================================================
// HarnessStore 类
// ============================================================

export class HarnessStore {
  private readonly db: BetterSqliteDB;

  constructor(dbPath: string) {
    this.db = new Database(dbPath);
    // WAL 模式改善并行读取
    this.db.pragma("journal_mode = WAL");
    this.db.pragma("foreign_keys = ON");
    this.initSchema();
  }

  // ============================================================
  // 模式初始化
  // ============================================================

  private initSchema(): void {
    this.db.exec(CREATE_SCHEMA_META);

    const versionRow = this.db
      .prepare<[], { value: string }>("SELECT value FROM schema_meta WHERE key = 'version'")
      .get();

    if (versionRow === undefined) {
      // 首次: 执行全部 DDL 并记录版本
      for (const ddl of ALL_DDL) {
        this.db.exec(ddl);
      }
      this.db
        .prepare("INSERT OR REPLACE INTO schema_meta(key, value) VALUES ('version', ?)")
        .run(String(SCHEMA_VERSION));
    }
    // 迁移由将来的 migration.ts 负责
  }

  // ============================================================
  // 会话管理
  // ============================================================

  /** 注册或更新会话 */
  upsertSession(session: SessionState): void {
    const startedAt = Math.floor(new Date(session.started_at).getTime() / 1000);
    const contextJson = JSON.stringify(session.context ?? {});

    this.db
      .prepare<[string, string, string, number, string]>(
        `INSERT INTO sessions(session_id, mode, project_root, started_at, context_json)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT(session_id) DO UPDATE SET
           mode = excluded.mode,
           project_root = excluded.project_root,
           context_json = excluded.context_json`
      )
      .run(
        session.session_id,
        session.mode,
        session.project_root,
        startedAt,
        contextJson
      );
  }

  /** 将会话标记为已结束 */
  endSession(sessionId: string): void {
    const endedAt = Math.floor(Date.now() / 1000);
    this.db
      .prepare<[number, string]>(
        "UPDATE sessions SET ended_at = ? WHERE session_id = ?"
      )
      .run(endedAt, sessionId);
  }

  /** 获取会话信息 */
  getSession(sessionId: string): SessionState | null {
    const row = this.db
      .prepare<[string], SessionRow>(
        "SELECT * FROM sessions WHERE session_id = ?"
      )
      .get(sessionId);

    if (row === undefined) return null;

    return {
      session_id: row.session_id,
      mode: row.mode as SessionState["mode"],
      project_root: row.project_root,
      started_at: new Date(row.started_at * 1000).toISOString(),
      context: JSON.parse(row.context_json) as Record<string, unknown>,
    };
  }

  // ============================================================
  // 信号管理
  // ============================================================

  /** 发送信号 */
  sendSignal(signal: Omit<Signal, "timestamp">): number {
    const sentAt = Math.floor(Date.now() / 1000);
    const payloadJson = JSON.stringify(signal.payload);

    const result = this.db
      .prepare<[string, string, string | null, string, number]>(
        `INSERT INTO signals(type, from_session_id, to_session_id, payload_json, sent_at)
         VALUES (?, ?, ?, ?, ?)`
      )
      .run(
        signal.type,
        signal.from_session_id,
        signal.to_session_id ?? null,
        payloadJson,
        sentAt
      );

    return result.lastInsertRowid as number;
  }

  /** 接收未消费的信号（接收方 = sessionId 或广播） */
  receiveSignals(sessionId: string): Signal[] {
    const rows = this.db
      .prepare<
        [string, string],
        {
          id: number;
          type: string;
          from_session_id: string;
          to_session_id: string | null;
          payload_json: string;
          sent_at: number;
        }
      >(
        `SELECT * FROM signals
         WHERE consumed = 0
           AND (to_session_id = ? OR to_session_id IS NULL)
           AND from_session_id != ?
         ORDER BY sent_at ASC`
      )
      .all(sessionId, sessionId);

    if (rows.length === 0) return [];

    // 标记为已消费
    const ids = rows.map((r) => r.id);
    const placeholders = ids.map(() => "?").join(",");
    this.db
      .prepare(`UPDATE signals SET consumed = 1 WHERE id IN (${placeholders})`)
      .run(...ids);

    return rows.map((r) => {
      const signal: Signal = {
        type: r.type as Signal["type"],
        from_session_id: r.from_session_id,
        payload: JSON.parse(r.payload_json) as Record<string, unknown>,
        timestamp: new Date(r.sent_at * 1000).toISOString(),
      };
      if (r.to_session_id !== null) {
        signal.to_session_id = r.to_session_id;
      }
      return signal;
    });
  }

  // ============================================================
  // 任务失败管理
  // ============================================================

  /** 记录任务失败 */
  recordFailure(
    failure: Omit<TaskFailure, "timestamp">,
    sessionId: string
  ): number {
    const failedAt = Math.floor(Date.now() / 1000);

    const result = this.db
      .prepare<[string, string, string, string, string | null, number, number]>(
        `INSERT INTO task_failures(task_id, session_id, severity, message, detail, failed_at, attempt)
         VALUES (?, ?, ?, ?, ?, ?, ?)`
      )
      .run(
        failure.task_id,
        sessionId,
        failure.severity,
        failure.message,
        failure.detail ?? null,
        failedAt,
        failure.attempt
      );

    return result.lastInsertRowid as number;
  }

  /** 获取任务的失败历史 */
  getFailures(taskId: string): TaskFailure[] {
    const rows = this.db
      .prepare<
        [string],
        {
          task_id: string;
          severity: string;
          message: string;
          detail: string | null;
          failed_at: number;
          attempt: number;
        }
      >(
        "SELECT task_id, severity, message, detail, failed_at, attempt FROM task_failures WHERE task_id = ? ORDER BY failed_at ASC"
      )
      .all(taskId);

    return rows.map((r) => {
      const failure: TaskFailure = {
        task_id: r.task_id,
        severity: r.severity as TaskFailure["severity"],
        message: r.message,
        timestamp: new Date(r.failed_at * 1000).toISOString(),
        attempt: r.attempt,
      };
      if (r.detail !== null) {
        failure.detail = r.detail;
      }
      return failure;
    });
  }

  // ============================================================
  // work_states 管理
  // ============================================================

  /** 注册 work/codex 模式（TTL 24 小时） */
  setWorkState(
    sessionId: string,
    options: {
      codexMode?: boolean;
      bypassRmRf?: boolean;
      bypassGitPush?: boolean;
    } = {}
  ): void {
    const expiresAt = Math.floor(Date.now() / 1000) + 24 * 3600;

    this.db
      .prepare<[string, number, number, number, number]>(
        `INSERT INTO work_states(session_id, codex_mode, bypass_rm_rf, bypass_git_push, expires_at)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT(session_id) DO UPDATE SET
           codex_mode = excluded.codex_mode,
           bypass_rm_rf = excluded.bypass_rm_rf,
           bypass_git_push = excluded.bypass_git_push,
           expires_at = excluded.expires_at`
      )
      .run(
        sessionId,
        options.codexMode ? 1 : 0,
        options.bypassRmRf ? 1 : 0,
        options.bypassGitPush ? 1 : 0,
        expiresAt
      );
  }

  /** 获取有效的 work_state（过期则返回 null） */
  getWorkState(sessionId: string): {
    codexMode: boolean;
    bypassRmRf: boolean;
    bypassGitPush: boolean;
  } | null {
    const now = Math.floor(Date.now() / 1000);
    const row = this.db
      .prepare<[string, number], WorkStateRow>(
        "SELECT * FROM work_states WHERE session_id = ? AND expires_at > ?"
      )
      .get(sessionId, now);

    if (row === undefined) return null;

    return {
      codexMode: row.codex_mode === 1,
      bypassRmRf: row.bypass_rm_rf === 1,
      bypassGitPush: row.bypass_git_push === 1,
    };
  }

  /** 删除过期的 work_states */
  cleanExpiredWorkStates(): number {
    const now = Math.floor(Date.now() / 1000);
    const result = this.db
      .prepare<[number]>("DELETE FROM work_states WHERE expires_at <= ?")
      .run(now);
    return result.changes;
  }

  // ============================================================
  // schema_meta 键值管理
  // ============================================================

  /** 从 schema_meta 表获取值（不存在时返回 null） */
  getMeta(key: string): string | null {
    const row = this.db
      .prepare<[string], { value: string }>("SELECT value FROM schema_meta WHERE key = ?")
      .get(key);
    return row?.value ?? null;
  }

  /** 向 schema_meta 表保存值（upsert） */
  setMeta(key: string, value: string): void {
    this.db
      .prepare<[string, string]>(
        `INSERT INTO schema_meta(key, value) VALUES (?, ?)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value`
      )
      .run(key, value);
  }

  // ============================================================
  // 关闭
  // ============================================================

  close(): void {
    this.db.close();
  }
}
