/**
 * core/src/state/__tests__/migration.test.ts
 * migration.ts 的单元测试
 *
 * 包含实际的文件系统操作，因此使用 tmp 目录。
 */

import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { mkdirSync, writeFileSync, existsSync, rmSync } from "node:fs";
import { resolve, join } from "node:path";
import { tmpdir } from "node:os";
import { migrate } from "../migration.js";
import { HarnessStore } from "../store.js";

// ============================================================
// 测试工具
// ============================================================

/** 创建并返回临时目录 */
function createTmpProject(): string {
  const dir = join(tmpdir(), `harness-migration-test-${Date.now()}-${Math.random().toString(36).slice(2)}`);
  mkdirSync(dir, { recursive: true });
  mkdirSync(join(dir, ".claude", "state"), { recursive: true });
  mkdirSync(join(dir, ".harness"), { recursive: true });
  return dir;
}

/** 测试后删除临时目录 */
function cleanupTmpProject(dir: string): void {
  if (existsSync(dir)) {
    rmSync(dir, { recursive: true, force: true });
  }
}

// ============================================================
// 测试
// ============================================================

describe("migrate()", () => {
  let projectRoot: string;
  let dbPath: string;

  beforeEach(() => {
    projectRoot = createTmpProject();
    dbPath = join(projectRoot, ".harness", "state.db");
  });

  afterEach(() => {
    cleanupTmpProject(projectRoot);
  });

  // ------------------------------------------------------------------
  // 已迁移检查
  // ------------------------------------------------------------------

  describe("已迁移跳过", () => {
    it("已迁移时返回 skipped: true", () => {
      // 第一次迁移
      const first = migrate(projectRoot, dbPath);
      expect(first.skipped).toBe(false);

      // 第二次跳过
      const second = migrate(projectRoot, dbPath);
      expect(second.skipped).toBe(true);
      expect(second.sessions).toBe(0);
      expect(second.signals).toBe(0);
    });
  });

  // ------------------------------------------------------------------
  // 无状态文件的迁移（空迁移）
  // ------------------------------------------------------------------

  describe("空迁移", () => {
    it("没有迁移目标文件时以 0 条完成", () => {
      const result = migrate(projectRoot, dbPath);
      expect(result.skipped).toBe(false);
      expect(result.sessions).toBe(0);
      expect(result.signals).toBe(0);
      expect(result.workStates).toBe(0);
      expect(result.errors).toHaveLength(0);
    });
  });

  // ------------------------------------------------------------------
  // session.json 的迁移
  // ------------------------------------------------------------------

  describe("session.json 迁移", () => {
    it("可以迁移会话", () => {
      const sessionFile = resolve(projectRoot, ".claude", "state", "session.json");
      writeFileSync(sessionFile, JSON.stringify({
        session_id: "sess-migrate-01",
        mode: "work",
        project_root: projectRoot,
        started_at: "2026-01-01T00:00:00Z",
      }));

      const result = migrate(projectRoot, dbPath);
      expect(result.sessions).toBe(1);
      expect(result.errors).toHaveLength(0);

      // 确认是否已保存到 SQLite
      const store = new HarnessStore(dbPath);
      try {
        const session = store.getSession("sess-migrate-01");
        expect(session).not.toBeNull();
        expect(session?.session_id).toBe("sess-migrate-01");
        expect(session?.mode).toBe("work");
      } finally {
        store.close();
      }
    });

    it("也可以迁移 Unix 时间戳格式的 started_at", () => {
      const sessionFile = resolve(projectRoot, ".claude", "state", "session.json");
      writeFileSync(sessionFile, JSON.stringify({
        session_id: "sess-unix-ts",
        mode: "normal",
        project_root: projectRoot,
        started_at: 1704067200, // 2024-01-01T00:00:00Z
      }));

      const result = migrate(projectRoot, dbPath);
      expect(result.sessions).toBe(1);
      expect(result.errors).toHaveLength(0);

      const store = new HarnessStore(dbPath);
      try {
        const session = store.getSession("sess-unix-ts");
        expect(session).not.toBeNull();
      } finally {
        store.close();
      }
    });

    it("session_id 未设置时也能迁移（使用默认 ID）", () => {
      const sessionFile = resolve(projectRoot, ".claude", "state", "session.json");
      writeFileSync(sessionFile, JSON.stringify({
        mode: "breezing",
        project_root: projectRoot,
        started_at: "2026-01-01T00:00:00Z",
      }));

      const result = migrate(projectRoot, dbPath);
      expect(result.sessions).toBe(1);
      expect(result.errors).toHaveLength(0);
    });

    it("无效 JSON 的 session.json 以 sessions: 0 继续", () => {
      const sessionFile = resolve(projectRoot, ".claude", "state", "session.json");
      writeFileSync(sessionFile, "{ invalid json }");

      const result = migrate(projectRoot, dbPath);
      expect(result.sessions).toBe(0);
      // 没有错误但 session 也是 0（JSON 解析失败视为 null）
    });

    it("迁移后 session.json 被重命名为 .v2.bak", () => {
      const sessionFile = resolve(projectRoot, ".claude", "state", "session.json");
      writeFileSync(sessionFile, JSON.stringify({
        session_id: "sess-backup-test",
        mode: "normal",
        project_root: projectRoot,
        started_at: "2026-01-01T00:00:00Z",
      }));

      migrate(projectRoot, dbPath);

      expect(existsSync(sessionFile)).toBe(false);
      expect(existsSync(`${sessionFile}.v2.bak`)).toBe(true);
    });
  });

  // ------------------------------------------------------------------
  // session.events.jsonl 的迁移
  // ------------------------------------------------------------------

  describe("session.events.jsonl 迁移", () => {
    it("可以迁移信号事件", () => {
      const eventsFile = resolve(projectRoot, ".claude", "state", "session.events.jsonl");
      const events = [
        { type: "task_completed", from_session_id: "sess-01", payload: { task: "impl" } },
        { type: "teammate_idle", from_session_id: "sess-02", payload: {} },
        { type: "session_start", from_session_id: "sess-03", to_session_id: "sess-04", payload: {} },
      ];
      writeFileSync(eventsFile, events.map(e => JSON.stringify(e)).join("\n"));

      const result = migrate(projectRoot, dbPath);
      expect(result.signals).toBe(3);
      expect(result.errors).toHaveLength(0);
    });

    it("空 JSONL 文件以 0 条完成", () => {
      const eventsFile = resolve(projectRoot, ".claude", "state", "session.events.jsonl");
      writeFileSync(eventsFile, "");

      const result = migrate(projectRoot, dbPath);
      expect(result.signals).toBe(0);
    });

    it("未知事件类型转换为回退信号", () => {
      const eventsFile = resolve(projectRoot, ".claude", "state", "session.events.jsonl");
      writeFileSync(eventsFile, JSON.stringify({
        type: "unknown_custom_event",
        from_session_id: "sess-01",
        payload: {},
      }));

      const result = migrate(projectRoot, dbPath);
      expect(result.signals).toBe(1);
      expect(result.errors).toHaveLength(0);
    });
  });

  // ------------------------------------------------------------------
  // work-active.json 的迁移
  // ------------------------------------------------------------------

  describe("work-active.json 迁移", () => {
    it("可以迁移 work_state", () => {
      const workActiveFile = resolve(projectRoot, ".claude", "work-active.json");
      writeFileSync(workActiveFile, JSON.stringify({
        session_id: "sess-work-01",
        mode: "work",
        codex_mode: true,
        bypass_rm_rf: false,
        bypass_git_push: false,
      }));

      const result = migrate(projectRoot, dbPath);
      expect(result.workStates).toBe(1);
      expect(result.errors).toHaveLength(0);

      const store = new HarnessStore(dbPath);
      try {
        const state = store.getWorkState("sess-work-01");
        expect(state).not.toBeNull();
        expect(state?.codexMode).toBe(true);
        expect(state?.bypassRmRf).toBe(false);
      } finally {
        store.close();
      }
    });
  });

  // ------------------------------------------------------------------
  // 复合迁移（所有文件都齐全时）
  // ------------------------------------------------------------------

  describe("复合迁移", () => {
    it("可以迁移 session + events + work-active 的全部", () => {
      // session.json
      writeFileSync(
        resolve(projectRoot, ".claude", "state", "session.json"),
        JSON.stringify({
          session_id: "sess-full",
          mode: "codex",
          project_root: projectRoot,
          started_at: "2026-01-01T00:00:00Z",
        })
      );

      // events.jsonl
      writeFileSync(
        resolve(projectRoot, ".claude", "state", "session.events.jsonl"),
        [
          JSON.stringify({ type: "task_completed", from_session_id: "sess-full", payload: {} }),
          JSON.stringify({ type: "request_review", from_session_id: "sess-full", payload: {} }),
        ].join("\n")
      );

      // work-active.json
      writeFileSync(
        resolve(projectRoot, ".claude", "work-active.json"),
        JSON.stringify({
          session_id: "sess-full",
          mode: "codex",
          codex_mode: true,
          bypass_rm_rf: false,
          bypass_git_push: false,
        })
      );

      const result = migrate(projectRoot, dbPath);
      expect(result.sessions).toBe(1);
      expect(result.signals).toBe(2);
      expect(result.workStates).toBe(1);
      expect(result.errors).toHaveLength(0);
      expect(result.skipped).toBe(false);
    });
  });
});
