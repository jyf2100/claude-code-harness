/**
 * core/src/state/migration.ts
 * Harness v2 JSON / JSONL → v3 SQLite 迁移脚本
 *
 * 将 v2 的状态文件导入 v3 SQLite 数据库。
 * 迁移目标:
 *   .claude/state/session.json      → sessions 表
 *   .claude/state/session.events.jsonl → signals 表（task_completed 等）
 *   .claude/work-active.json         → work_states 表
 *
 * 幂等设计: 已迁移的情况下重新执行也是安全的。
 */

import { readFileSync, existsSync, renameSync } from "node:fs";
import { resolve } from "node:path";
import type { SignalType } from "../types.js";
import { HarnessStore } from "./store.js";

// ============================================================
// 类型定义（v2 JSON 结构）
// ============================================================

interface V2Session {
  session_id?: string;
  id?: string; // 旧字段名
  mode?: string;
  project_root?: string;
  started_at?: string | number;
  ended_at?: string | number | null;
  context?: Record<string, unknown>;
}

interface V2Event {
  type?: string;
  event?: string; // 旧字段名
  session_id?: string;
  from_session_id?: string;
  to_session_id?: string | null;
  payload?: Record<string, unknown>;
  data?: Record<string, unknown>; // 旧字段名
  timestamp?: string | number;
  sent_at?: string | number; // 旧字段名
}

interface V2WorkActive {
  session_id?: string;
  codex_mode?: boolean;
  bypass_rm_rf?: boolean;
  bypass_git_push?: boolean;
  mode?: string;
}

// ============================================================
// 辅助函数
// ============================================================

/** 将 ISO 日期字符串或 Unix 时间戳规范化为 ISO 字符串 */
function toIsoString(value: string | number | null | undefined): string {
  if (value === null || value === undefined) {
    return new Date().toISOString();
  }
  if (typeof value === "number") {
    // 判断 Unix 时间戳是秒还是毫秒
    const ms = value > 1e10 ? value : value * 1000;
    return new Date(ms).toISOString();
  }
  // 如果已经是 ISO 字符串则直接返回
  return value;
}

/** 将 v2 模式字符串规范化为 v3 模式 */
function normalizeMode(mode: string | undefined): "normal" | "work" | "codex" | "breezing" {
  switch (mode) {
    case "work":
    case "codex":
    case "breezing":
      return mode;
    default:
      return "normal";
  }
}

/** 检查字符串是否为有效的 SignalType */
function normalizeSignalType(type: string | undefined): SignalType {
  // 有效的 SignalType 列表（与 types.ts 中的 SignalType 同步）
  const valid: SignalType[] = [
    "task_completed", "task_failed", "teammate_idle",
    "session_start", "session_end", "stop_failure", "request_review",
  ];
  if (type && (valid as string[]).includes(type)) return type as SignalType;
  return "task_completed"; // 未知类型回退到默认值
}

// ============================================================
// JSON 文件读取工具
// ============================================================

/** 安全地读取 JSON 文件。不存在时返回 null */
function readJsonFile<T>(filePath: string): T | null {
  if (!existsSync(filePath)) return null;
  try {
    const content = readFileSync(filePath, "utf8");
    return JSON.parse(content) as T;
  } catch {
    return null;
  }
}

/** 安全地读取 JSONL 文件（每行一个 JSON）。不存在时返回 [] */
function readJsonlFile<T>(filePath: string): T[] {
  if (!existsSync(filePath)) return [];
  try {
    const content = readFileSync(filePath, "utf8");
    return content
      .split("\n")
      .filter((line) => line.trim().length > 0)
      .map((line) => JSON.parse(line) as T);
  } catch {
    return [];
  }
}

// ============================================================
// 迁移处理
// ============================================================

export interface MigrationResult {
  sessions: number;
  signals: number;
  workStates: number;
  skipped: boolean;
  errors: string[];
}

/**
 * 将 v2 JSON/JSONL 状态文件迁移到 v3 SQLite 数据库。
 *
 * @param projectRoot - 项目根目录路径（默认: process.cwd()）
 * @param dbPath - SQLite 数据库路径（默认: <projectRoot>/.harness/state.db）
 * @returns 迁移结果
 */
export function migrate(
  projectRoot: string = process.cwd(),
  dbPath?: string
): MigrationResult {
  const stateDir = resolve(projectRoot, ".claude", "state");
  const resolvedDbPath = dbPath ?? resolve(projectRoot, ".harness", "state.db");

  const result: MigrationResult = {
    sessions: 0,
    signals: 0,
    workStates: 0,
    skipped: false,
    errors: [],
  };

  const store = new HarnessStore(resolvedDbPath);

  try {
    // 已迁移检查: 如果 schema_meta 中存在 migration_done 则跳过
    const migrationDone = store.getMeta("migration_v1_done");
    if (migrationDone === "1") {
      result.skipped = true;
      return result;
    }

    // ------------------------------------------------
    // 1. session.json → sessions 表
    // ------------------------------------------------
    const sessionFile = resolve(stateDir, "session.json");
    const v2Session = readJsonFile<V2Session>(sessionFile);

    if (v2Session !== null) {
      const sessionId = v2Session.session_id ?? v2Session.id ?? "migrated-session";
      try {
        store.upsertSession({
          session_id: sessionId,
          mode: normalizeMode(v2Session.mode),
          project_root: v2Session.project_root ?? projectRoot,
          started_at: toIsoString(v2Session.started_at),
        });
        if (v2Session.ended_at !== null && v2Session.ended_at !== undefined) {
          store.endSession(sessionId);
        }
        result.sessions++;
      } catch (err) {
        result.errors.push(`session migration failed: ${err}`);
      }
    }

    // ------------------------------------------------
    // 2. session.events.jsonl → signals 表
    // ------------------------------------------------
    const eventsFile = resolve(stateDir, "session.events.jsonl");
    const v2Events = readJsonlFile<V2Event>(eventsFile);

    for (const event of v2Events) {
      const type = normalizeSignalType(event.type ?? event.event);
      const fromSessionId = event.from_session_id ?? event.session_id ?? "unknown";
      const payload = event.payload ?? event.data ?? {};

      try {
        const signal: Parameters<HarnessStore["sendSignal"]>[0] = {
          type,
          from_session_id: fromSessionId,
          payload,
        };
        if (event.to_session_id) {
          signal.to_session_id = event.to_session_id;
        }
        store.sendSignal(signal);
        result.signals++;
      } catch (err) {
        result.errors.push(`signal migration failed (type=${type}): ${err}`);
      }
    }

    // ------------------------------------------------
    // 3. work-active.json → work_states 表
    // ------------------------------------------------
    const workActiveFile = resolve(projectRoot, ".claude", "work-active.json");
    const v2WorkActive = readJsonFile<V2WorkActive>(workActiveFile);

    if (v2WorkActive !== null) {
      const sessionId = v2WorkActive.session_id ?? "migrated-work-session";
      try {
        // 为满足 FK 约束，先在 sessions 中临时注册
        store.upsertSession({
          session_id: sessionId,
          mode: normalizeMode(v2WorkActive.mode ?? "work"),
          project_root: projectRoot,
          started_at: new Date().toISOString(),
        });
        store.setWorkState(sessionId, {
          codexMode: v2WorkActive.codex_mode ?? false,
          bypassRmRf: v2WorkActive.bypass_rm_rf ?? false,
          bypassGitPush: v2WorkActive.bypass_git_push ?? false,
        });
        result.workStates++;
      } catch (err) {
        result.errors.push(`work_state migration failed: ${err}`);
      }
    }

    // ------------------------------------------------
    // 4. 记录迁移完成标记
    // ------------------------------------------------
    store.setMeta("migration_v1_done", "1");

    // ------------------------------------------------
    // 5. 备份原文件（不删除）
    // ------------------------------------------------
    if (v2Session !== null && existsSync(sessionFile)) {
      try {
        renameSync(sessionFile, `${sessionFile}.v2.bak`);
      } catch {
        // 忽略备份失败（迁移本身已完成）
      }
    }

  } finally {
    store.close();
  }

  return result;
}

// ============================================================
// CLI 入口点（使用 node 直接执行时）
// ============================================================

// 在 ESM 中可以用 import.meta.url 判断"直接执行"
// 编译到 dist/ 后通过 `node dist/state/migration.js` 调用
const isMain = process.argv[1]?.endsWith("migration.js");

if (isMain) {
  const projectRoot = process.argv[2] ?? process.cwd();
  const dbPath = process.argv[3];

  const result = migrate(projectRoot, dbPath);

  if (result.skipped) {
    console.log("Migration already completed. Skipped.");
    process.exit(0);
  }

  if (result.errors.length > 0) {
    console.error("Migration completed with errors:");
    for (const err of result.errors) {
      console.error(`  - ${err}`);
    }
  }

  console.log(
    `Migration done: ${result.sessions} sessions, ${result.signals} signals, ${result.workStates} work_states`
  );
  process.exit(result.errors.length > 0 ? 1 : 0);
}
