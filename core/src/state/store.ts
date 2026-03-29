/**
 * core/src/state/store.ts
 * Harness v3 SQLite 存储
 *
 * 使用 better-sqlite3 操作 sessions / signals / task_failures / work_states
 * 表的封装类。
 * 利用同步 API（better-sqlite3 的特性），实现简单且健壮的设计。
 */

import { createRequire } from "node:module";
import { ALL_DDL, SCHEMA_VERSION, CREATE_SCHEMA_META, MIGRATION_V2_DDL } from "./schema.js";
import type { Signal, SessionState, TaskFailure, SkillUsageMetric, SkillEvolution, SkillEvolutionProposal } from "../types.js";
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

/** skill_evolution 记录的行类型 */
interface SkillEvolutionRow {
  id: number;
  skill_name: string;
  version: string;
  status: string;
  parent_skill: string | null;
  evolution_type: string | null;
  health_score: number;
  usage_count: number;
  success_rate: number;
  last_used_at: number | null;
  last_evolved_at: number | null;
  evolution_pending: string | null;
  evolution_reason: string | null;
  metadata_json: string;
}

/** skill_evolution_proposals 记录的行类型 */
interface ProposalRow {
  id: number;
  skill_name: string;
  proposal_type: string;
  proposal_json: string;
  created_at: number;
  status: string;
  reviewed_at: number | null;
  reviewed_by: string | null;
  applied_at: number | null;
}

/** 将 SkillEvolutionRow 映射为 SkillEvolution 类型 */
function mapEvolutionRow(row: SkillEvolutionRow): SkillEvolution {
  const result: SkillEvolution = {
    skill_name: row.skill_name,
    version: row.version,
    status: row.status as SkillEvolution["status"],
    health_score: row.health_score,
    usage_count: row.usage_count,
    success_rate: row.success_rate,
    evolution_pending: (row.evolution_pending ?? "none") as SkillEvolution["evolution_pending"],
  };
  if (row.last_used_at !== null) {
    result.last_used_at = new Date(row.last_used_at * 1000).toISOString();
  }
  if (row.evolution_reason !== null && row.evolution_reason !== undefined) {
    result.evolution_reason = row.evolution_reason;
  }
  return result;
}

/** 将 ProposalRow 映射为 SkillEvolutionProposal 类型 */
function mapProposalRow(row: ProposalRow): SkillEvolutionProposal {
  const result: SkillEvolutionProposal = {
    id: row.id,
    skill_name: row.skill_name,
    proposal_type: row.proposal_type as SkillEvolutionProposal["proposal_type"],
    proposal: JSON.parse(row.proposal_json) as SkillEvolutionProposal["proposal"],
    created_at: new Date(row.created_at * 1000).toISOString(),
    status: row.status as SkillEvolutionProposal["status"],
  };
  if (row.reviewed_at !== null) {
    result.reviewed_at = new Date(row.reviewed_at * 1000).toISOString();
  }
  if (row.reviewed_by !== null) {
    result.reviewed_by = row.reviewed_by;
  }
  if (row.applied_at !== null) {
    result.applied_at = new Date(row.applied_at * 1000).toISOString();
  }
  return result;
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
      return;
    }

    // 增量迁移
    const currentVersion = parseInt(versionRow.value, 10);
    if (currentVersion < 2) {
      for (const ddl of MIGRATION_V2_DDL) {
        this.db.exec(ddl);
      }
      this.db
        .prepare("INSERT OR REPLACE INTO schema_meta(key, value) VALUES ('version', ?)")
        .run(String(SCHEMA_VERSION));
    }
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
  // 进化引擎: 技能使用指标
  // ============================================================

  /** 记录技能使用指标 */
  recordSkillUsage(metric: Omit<SkillUsageMetric, "id" | "recorded_at">): number {
    const recordedAt = Math.floor(Date.now() / 1000);
    const contextJson = JSON.stringify(metric.context ?? {});

    const result = this.db
      .prepare<[string, string, string, string, string | null, number, string | null, number | null, number | null, string, number]>(
        `INSERT INTO skill_usage_metrics(
           session_id, skill_name, skill_version, invocation_type, tool_name,
           success, error_message, duration_ms, tokens_used, context_json, recorded_at
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      )
      .run(
        metric.session_id,
        metric.skill_name,
        metric.skill_version ?? "unknown",
        metric.invocation_type,
        metric.tool_name ?? null,
        metric.success ? 1 : 0,
        metric.error_message ?? null,
        metric.duration_ms ?? null,
        metric.tokens_used ?? null,
        contextJson,
        recordedAt
      );

    return result.lastInsertRowid as number;
  }

  /** 获取技能的使用指标（指定时间范围） */
  getSkillUsageStats(
    skillName: string,
    sinceTimestamp: number
  ): { usageCount: number; successCount: number; avgDurationMs: number | null } {
    const row = this.db
      .prepare<[string, number], { cnt: number; ok: number; avg_dur: number | null }>(
        `SELECT
           COUNT(*)   as cnt,
           SUM(success) as ok,
           AVG(duration_ms) as avg_dur
         FROM skill_usage_metrics
         WHERE skill_name = ? AND recorded_at >= ?`
      )
      .get(skillName, sinceTimestamp);

    if (row === undefined) {
      return { usageCount: 0, successCount: 0, avgDurationMs: null };
    }

    return {
      usageCount: row.cnt,
      successCount: row.ok,
      avgDurationMs: row.avg_dur,
    };
  }

  // ============================================================
  // 进化引擎: 技能进化状态
  // ============================================================

  /** 获取或创建技能的进化记录 */
  getOrCreateSkillEvolution(skillName: string): SkillEvolution {
    const row = this.db
      .prepare<[string], SkillEvolutionRow>(
        "SELECT * FROM skill_evolution WHERE skill_name = ?"
      )
      .get(skillName);

    if (row !== undefined) {
      return mapEvolutionRow(row);
    }

    // 首次使用，创建记录
    const now = Math.floor(Date.now() / 1000);
    this.db
      .prepare<[string, number]>(
        `INSERT INTO skill_evolution(skill_name, last_used_at)
         VALUES (?, ?)`
      )
      .run(skillName, now);

    return {
      skill_name: skillName,
      version: "1.0.0",
      status: "active",
      health_score: 1.0,
      usage_count: 0,
      success_rate: 1.0,
      last_used_at: new Date(now * 1000).toISOString(),
      evolution_pending: "none",
    };
  }

  /** 更新技能进化状态 */
  updateSkillEvolution(skillName: string, updates: {
    version?: string;
    status?: SkillEvolution["status"];
    health_score?: number;
    usage_count?: number;
    success_rate?: number;
    evolution_pending?: SkillEvolution["evolution_pending"];
    evolution_reason?: string;
    evolution_type?: SkillEvolution["evolution_type"];
    parent_skill?: string;
  }): void {
    const now = Math.floor(Date.now() / 1000);
    const setClauses: string[] = ["last_used_at = ?"];
    const values: unknown[] = [now];

    if (updates.version !== undefined) {
      setClauses.push("version = ?");
      values.push(updates.version);
    }
    if (updates.status !== undefined) {
      setClauses.push("status = ?");
      values.push(updates.status);
    }
    if (updates.health_score !== undefined) {
      setClauses.push("health_score = ?");
      values.push(updates.health_score);
    }
    if (updates.usage_count !== undefined) {
      setClauses.push("usage_count = ?");
      values.push(updates.usage_count);
    }
    if (updates.success_rate !== undefined) {
      setClauses.push("success_rate = ?");
      values.push(updates.success_rate);
    }
    if (updates.evolution_pending !== undefined) {
      setClauses.push("evolution_pending = ?");
      values.push(updates.evolution_pending);
    }
    if (updates.evolution_reason !== undefined) {
      setClauses.push("evolution_reason = ?");
      values.push(updates.evolution_reason);
    }
    if (updates.evolution_type !== undefined) {
      setClauses.push("evolution_type = ?");
      values.push(updates.evolution_type);
      setClauses.push("last_evolved_at = ?");
      values.push(now);
    }
    if (updates.parent_skill !== undefined) {
      setClauses.push("parent_skill = ?");
      values.push(updates.parent_skill);
    }

    values.push(skillName);
    this.db
      .prepare(`UPDATE skill_evolution SET ${setClauses.join(", ")} WHERE skill_name = ?`)
      .run(...values);
  }

  /** 获取健康分数低于阈值的技能 */
  getUnhealthySkills(threshold: number = 0.7): SkillEvolution[] {
    const rows = this.db
      .prepare<[number], SkillEvolutionRow>(
        "SELECT * FROM skill_evolution WHERE health_score < ? AND status = 'active'"
      )
      .all(threshold);
    return rows.map(mapEvolutionRow);
  }

  /** 重新计算技能健康分数 */
  recalcSkillHealth(skillName: string): number {
    const sevenDaysAgo = Math.floor(Date.now() / 1000) - 7 * 24 * 3600;
    const stats = this.getSkillUsageStats(skillName, sevenDaysAgo);

    if (stats.usageCount === 0) return 1.0;

    const successRate = stats.successCount / stats.usageCount;
    // 使用频率分: 0-1 次用 0.2, 2-10 次用 0.4, 11-50 次用 0.7, 50+ 用 1.0
    let usageScore: number;
    if (stats.usageCount <= 1) usageScore = 0.2;
    else if (stats.usageCount <= 10) usageScore = 0.4;
    else if (stats.usageCount <= 50) usageScore = 0.7;
    else usageScore = 1.0;

    const healthScore = successRate * 0.6 + usageScore * 0.4;

    // 原子更新
    const evo = this.getOrCreateSkillEvolution(skillName);
    this.updateSkillEvolution(skillName, {
      health_score: healthScore,
      usage_count: stats.usageCount,
      success_rate: successRate,
    });

    return healthScore;
  }

  // ============================================================
  // 进化引擎: 提案管理
  // ============================================================

  /** 创建进化提案 */
  createEvolutionProposal(proposal: Omit<SkillEvolutionProposal, "id" | "created_at" | "status">): number {
    const createdAt = Math.floor(Date.now() / 1000);
    const proposalJson = JSON.stringify(proposal.proposal);

    const result = this.db
      .prepare<[string, string, string, number]>(
        `INSERT INTO skill_evolution_proposals(skill_name, proposal_type, proposal_json, created_at)
         VALUES (?, ?, ?, ?)`
      )
      .run(proposal.skill_name, proposal.proposal_type, proposalJson, createdAt);

    // 标记技能为待进化
    this.updateSkillEvolution(proposal.skill_name, {
      evolution_pending: proposal.proposal_type,
      evolution_reason: proposal.proposal.reason,
    });

    return result.lastInsertRowid as number;
  }

  /** 获取待处理的提案 */
  getPendingProposals(): SkillEvolutionProposal[] {
    const rows = this.db
      .prepare<[], ProposalRow>(
        "SELECT * FROM skill_evolution_proposals WHERE status = 'pending' ORDER BY created_at ASC"
      )
      .all();
    return rows.map(mapProposalRow);
  }

  /** 审批提案 */
  reviewProposal(proposalId: number, decision: "approved" | "rejected", reviewer: string): void {
    const now = Math.floor(Date.now() / 1000);
    this.db
      .prepare<[string, number, string, number]>(
        `UPDATE skill_evolution_proposals
         SET status = ?, reviewed_at = ?, reviewed_by = ?
         WHERE id = ?`
      )
      .run(decision, now, reviewer, proposalId);

    if (decision === "rejected") {
      // 拒绝时清除技能的进化待处理标记
      const row = this.db
        .prepare<[number], ProposalRow>(
          "SELECT skill_name FROM skill_evolution_proposals WHERE id = ?"
        )
        .get(proposalId);
      if (row !== undefined) {
        this.updateSkillEvolution(row.skill_name, {
          evolution_pending: "none",
        });
      }
    }
  }

  /** 标记提案为已应用 */
  markProposalApplied(proposalId: number): void {
    const now = Math.floor(Date.now() / 1000);
    this.db
      .prepare<[number, number]>(
        `UPDATE skill_evolution_proposals SET status = 'applied', applied_at = ? WHERE id = ?`
      )
      .run(now, proposalId);
  }

  /** 创建技能快照（用于回滚） */
  createSkillSnapshot(skillName: string, content: string): string {
    const snapshotKey = `snapshot:${skillName}:${Date.now()}`;
    this.setMeta(snapshotKey, content);
    return snapshotKey;
  }

  /** 获取技能快照 */
  getSkillSnapshot(snapshotKey: string): string | null {
    return this.getMeta(snapshotKey);
  }

  // ============================================================
  // 关闭
  // ============================================================

  close(): void {
    this.db.close();
  }
}
