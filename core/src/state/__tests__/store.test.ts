/**
 * core/src/state/__tests__/store.test.ts
 * HarnessStore 单元测试
 *
 * 使用 better-sqlite3 的实际 SQLite DB（内存中）验证各方法。
 */

import { createRequire } from "node:module";
import { beforeEach, afterEach, describe, it, expect } from "vitest";
import { HarnessStore } from "../store.js";

const require = createRequire(import.meta.url);
const Database = require("better-sqlite3") as typeof import("better-sqlite3").default;

// 为测试创建 HarnessStore 的子类，使用内存 DB
// HarnessStore 的构造函数接受文件路径，
// 但传入 ":memory:" 让 better-sqlite3 使用内存内 DB
function createStore(): HarnessStore {
  return new HarnessStore(":memory:");
}

describe("HarnessStore", () => {
  let store: HarnessStore;

  beforeEach(() => {
    store = createStore();
  });

  afterEach(() => {
    store.close();
  });

  // ------------------------------------------------------------------
  // 会话管理
  // ------------------------------------------------------------------

  describe("upsertSession / getSession", () => {
    it("可以注册并获取会话", () => {
      store.upsertSession({
        session_id: "sess-001",
        mode: "work",
        project_root: "/tmp/project",
        started_at: "2026-01-01T00:00:00Z",
      });

      const session = store.getSession("sess-001");
      expect(session).not.toBeNull();
      expect(session?.session_id).toBe("sess-001");
      expect(session?.mode).toBe("work");
      expect(session?.project_root).toBe("/tmp/project");
    });

    it("不存在的会话返回 null", () => {
      const session = store.getSession("nonexistent");
      expect(session).toBeNull();
    });

    it("可以用 upsert 更新现有会话", () => {
      store.upsertSession({
        session_id: "sess-002",
        mode: "normal",
        project_root: "/tmp/project",
        started_at: "2026-01-01T00:00:00Z",
      });

      store.upsertSession({
        session_id: "sess-002",
        mode: "codex",
        project_root: "/tmp/project-v2",
        started_at: "2026-01-01T00:00:00Z",
      });

      const session = store.getSession("sess-002");
      expect(session?.mode).toBe("codex");
      expect(session?.project_root).toBe("/tmp/project-v2");
    });

    it("可以用 endSession 结束会话", () => {
      store.upsertSession({
        session_id: "sess-003",
        mode: "breezing",
        project_root: "/tmp",
        started_at: "2026-01-01T00:00:00Z",
      });

      store.endSession("sess-003");

      const session = store.getSession("sess-003");
      expect(session).not.toBeNull();
      // ended_at 在 getSession 中不映射，
      // 但会话本身可以获取
    });
  });

  // ------------------------------------------------------------------
  // 信号管理
  // ------------------------------------------------------------------

  describe("sendSignal / receiveSignals", () => {
    it("可以发送和接收信号", () => {
      store.upsertSession({
        session_id: "sender",
        mode: "normal",
        project_root: "/tmp",
        started_at: new Date().toISOString(),
      });
      store.upsertSession({
        session_id: "receiver",
        mode: "normal",
        project_root: "/tmp",
        started_at: new Date().toISOString(),
      });

      store.sendSignal({
        type: "task_completed",
        from_session_id: "sender",
        to_session_id: "receiver",
        payload: { task_id: "task-01", result: "success" },
      });

      const signals = store.receiveSignals("receiver");
      expect(signals).toHaveLength(1);
      expect(signals[0]?.type).toBe("task_completed");
      expect(signals[0]?.from_session_id).toBe("sender");
      expect(signals[0]?.payload).toEqual({ task_id: "task-01", result: "success" });
    });

    it("广播信号所有会话都能接收", () => {
      store.upsertSession({
        session_id: "broadcaster",
        mode: "normal",
        project_root: "/tmp",
        started_at: new Date().toISOString(),
      });

      store.sendSignal({
        type: "teammate_idle",
        from_session_id: "broadcaster",
        payload: {},
      });

      const signals = store.receiveSignals("any-session");
      expect(signals).toHaveLength(1);
      expect(signals[0]?.type).toBe("teammate_idle");
    });

    it("已接收信号不会再次接收", () => {
      store.upsertSession({
        session_id: "s1",
        mode: "normal",
        project_root: "/tmp",
        started_at: new Date().toISOString(),
      });

      store.sendSignal({
        type: "session_start",
        from_session_id: "s1",
        to_session_id: "s2",
        payload: {},
      });

      const first = store.receiveSignals("s2");
      expect(first).toHaveLength(1);

      const second = store.receiveSignals("s2");
      expect(second).toHaveLength(0);
    });

    it("自己发送的信号自己不会接收", () => {
      store.sendSignal({
        type: "request_review",
        from_session_id: "s1",
        payload: {},
      });

      const signals = store.receiveSignals("s1");
      expect(signals).toHaveLength(0);
    });
  });

  // ------------------------------------------------------------------
  // 任务失败管理
  // ------------------------------------------------------------------

  describe("recordFailure / getFailures", () => {
    it("可以记录并获取任务失败", () => {
      const id = store.recordFailure(
        {
          task_id: "task-01",
          severity: "error",
          message: "TypeScript compilation failed",
          attempt: 1,
        },
        "sess-001"
      );

      expect(id).toBeGreaterThan(0);

      const failures = store.getFailures("task-01");
      expect(failures).toHaveLength(1);
      expect(failures[0]?.severity).toBe("error");
      expect(failures[0]?.message).toBe("TypeScript compilation failed");
      expect(failures[0]?.attempt).toBe(1);
    });

    it("detail 字段是可选的（可以省略）", () => {
      store.recordFailure(
        {
          task_id: "task-02",
          severity: "warning",
          message: "Minor issue",
          attempt: 1,
        },
        "sess-001"
      );

      const failures = store.getFailures("task-02");
      expect(failures[0]?.detail).toBeUndefined();
    });

    it("有 detail 字段时可以获取", () => {
      store.recordFailure(
        {
          task_id: "task-03",
          severity: "critical",
          message: "Fatal error",
          detail: "Stack trace here",
          attempt: 2,
        },
        "sess-001"
      );

      const failures = store.getFailures("task-03");
      expect(failures[0]?.detail).toBe("Stack trace here");
    });

    it("不存在的任务返回空数组", () => {
      const failures = store.getFailures("nonexistent-task");
      expect(failures).toHaveLength(0);
    });
  });

  // ------------------------------------------------------------------
  // work_states 管理
  // ------------------------------------------------------------------

  describe("setWorkState / getWorkState / cleanExpiredWorkStates", () => {
    it("可以设置并获取 work state", () => {
      // 为满足 FK 约束预先注册会话
      store.upsertSession({
        session_id: "sess-001",
        mode: "work",
        project_root: "/tmp",
        started_at: new Date().toISOString(),
      });
      store.setWorkState("sess-001", {
        codexMode: true,
        bypassRmRf: false,
        bypassGitPush: false,
      });

      const state = store.getWorkState("sess-001");
      expect(state).not.toBeNull();
      expect(state?.codexMode).toBe(true);
      expect(state?.bypassRmRf).toBe(false);
      expect(state?.bypassGitPush).toBe(false);
    });

    it("默认值都是 false", () => {
      // 为满足 FK 约束预先注册会话
      store.upsertSession({
        session_id: "sess-002",
        mode: "normal",
        project_root: "/tmp",
        started_at: new Date().toISOString(),
      });
      store.setWorkState("sess-002");

      const state = store.getWorkState("sess-002");
      expect(state?.codexMode).toBe(false);
      expect(state?.bypassRmRf).toBe(false);
      expect(state?.bypassGitPush).toBe(false);
    });

    it("不存在的 session 的 work state 为 null", () => {
      const state = store.getWorkState("nonexistent");
      expect(state).toBeNull();
    });

    it("可以用 cleanExpiredWorkStates 删除过期记录", () => {
      // 为满足 FK 约束预先注册会话
      store.upsertSession({
        session_id: "expired-sess",
        mode: "normal",
        project_root: "/tmp",
        started_at: new Date().toISOString(),
      });
      // 直接向 DB 插入过期记录
      const db = (store as unknown as { db: InstanceType<typeof Database> }).db;
      const expiredAt = Math.floor(Date.now() / 1000) - 1; // 1秒前 = 过期
      db.prepare(
        `INSERT INTO work_states(session_id, codex_mode, bypass_rm_rf, bypass_git_push, expires_at)
         VALUES ('expired-sess', 0, 0, 0, ?)`
      ).run(expiredAt);

      const deleted = store.cleanExpiredWorkStates();
      expect(deleted).toBe(1);

      const state = store.getWorkState("expired-sess");
      expect(state).toBeNull();
    });
  });
});
