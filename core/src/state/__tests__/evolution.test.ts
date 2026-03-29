/**
 * core/src/state/__tests__/evolution.test.ts
 * 进化引擎 Store 方法单元测试
 *
 * 测试 skill_usage_metrics、skill_evolution、skill_evolution_proposals 的 CRUD 操作。
 */

import { createRequire } from "node:module";
import { beforeEach, afterEach, describe, it, expect } from "vitest";
import { HarnessStore } from "../store.js";

const require = createRequire(import.meta.url);
const Database = require("better-sqlite3") as typeof import("better-sqlite3").default;

function createStore(): HarnessStore {
  return new HarnessStore(":memory:");
}

describe("HarnessStore — 进化引擎", () => {
  let store: HarnessStore;

  beforeEach(() => {
    store = createStore();
  });

  afterEach(() => {
    store.close();
  });

  // ------------------------------------------------------------------
  // 技能使用指标
  // ------------------------------------------------------------------

  describe("recordSkillUsage / getSkillUsageStats", () => {
    it("可以记录技能使用并查询统计", () => {
      const now = Math.floor(Date.now() / 1000);
      store.recordSkillUsage({
        session_id: "sess-001",
        skill_name: "harness-work",
        skill_version: "1.0.0",
        invocation_type: "skill",
        tool_name: "Skill",
        success: true,
        duration_ms: 1500,
      });

      store.recordSkillUsage({
        session_id: "sess-001",
        skill_name: "harness-work",
        skill_version: "1.0.0",
        invocation_type: "skill",
        tool_name: "Skill",
        success: true,
        duration_ms: 2000,
      });

      store.recordSkillUsage({
        session_id: "sess-001",
        skill_name: "harness-work",
        skill_version: "1.0.0",
        invocation_type: "skill",
        tool_name: "Skill",
        success: false,
        error_message: "timeout",
        duration_ms: 5000,
      });

      // 从很早的时间点查询（获取全部）
      const stats = store.getSkillUsageStats("harness-work", 0);
      expect(stats.usageCount).toBe(3);
      expect(stats.successCount).toBe(2);
      expect(stats.avgDurationMs).toBeCloseTo(2833, 0);
    });

    it("时间范围过滤生效", () => {
      store.recordSkillUsage({
        session_id: "sess-001",
        skill_name: "harness-review",
        invocation_type: "skill",
        success: true,
      });

      // 从未来时间点查询（应返回空）
      const futureTs = Math.floor(Date.now() / 1000) + 10000;
      const stats = store.getSkillUsageStats("harness-review", futureTs);
      expect(stats.usageCount).toBe(0);
    });
  });

  // ------------------------------------------------------------------
  // 技能进化状态
  // ------------------------------------------------------------------

  describe("getOrCreateSkillEvolution / updateSkillEvolution", () => {
    it("首次获取时自动创建记录", () => {
      const evo = store.getOrCreateSkillEvolution("harness-work");
      expect(evo.skill_name).toBe("harness-work");
      expect(evo.version).toBe("1.0.0");
      expect(evo.status).toBe("active");
      expect(evo.health_score).toBe(1.0);
      expect(evo.evolution_pending).toBe("none");
    });

    it("可以更新进化状态", () => {
      store.getOrCreateSkillEvolution("harness-work");

      store.updateSkillEvolution("harness-work", {
        health_score: 0.5,
        usage_count: 10,
        success_rate: 0.6,
        evolution_pending: "fix",
        evolution_reason: "成功率过低",
      });

      const evo = store.getOrCreateSkillEvolution("harness-work");
      expect(evo.health_score).toBe(0.5);
      expect(evo.usage_count).toBe(10);
      expect(evo.success_rate).toBe(0.6);
      expect(evo.evolution_pending).toBe("fix");
      expect(evo.evolution_reason).toBe("成功率过低");
    });

    it("可以更新版本和进化类型", () => {
      store.getOrCreateSkillEvolution("harness-work");

      store.updateSkillEvolution("harness-work", {
        version: "1.1.0",
        evolution_type: "fix",
      });

      const evo = store.getOrCreateSkillEvolution("harness-work");
      expect(evo.version).toBe("1.1.0");
    });
  });

  describe("getUnhealthySkills", () => {
    it("返回健康分数低于阈值的技能", () => {
      store.getOrCreateSkillEvolution("healthy-skill");
      store.getOrCreateSkillEvolution("unhealthy-skill");

      store.updateSkillEvolution("healthy-skill", { health_score: 0.9 });
      store.updateSkillEvolution("unhealthy-skill", { health_score: 0.3 });

      const unhealthy = store.getUnhealthySkills(0.7);
      expect(unhealthy).toHaveLength(1);
      expect(unhealthy[0]?.skill_name).toBe("unhealthy-skill");
    });

    it("不返回已 deprecated 的技能", () => {
      store.getOrCreateSkillEvolution("deprecated-skill");
      store.updateSkillEvolution("deprecated-skill", {
        health_score: 0.1,
        status: "deprecated",
      });

      const unhealthy = store.getUnhealthySkills(0.7);
      expect(unhealthy).toHaveLength(0);
    });
  });

  describe("recalcSkillHealth", () => {
    it("根据使用数据重新计算健康分数", () => {
      // 模拟使用数据: 8 次成功，2 次失败
      for (let i = 0; i < 8; i++) {
        store.recordSkillUsage({
          session_id: "sess-001",
          skill_name: "test-skill",
          invocation_type: "skill",
          success: true,
        });
      }
      for (let i = 0; i < 2; i++) {
        store.recordSkillUsage({
          session_id: "sess-001",
          skill_name: "test-skill",
          invocation_type: "skill",
          success: false,
          error_message: "test error",
        });
      }

      store.getOrCreateSkillEvolution("test-skill");
      const health = store.recalcSkillHealth("test-skill");

      // successRate = 8/10 = 0.8
      // usageScore = 0.4 (2-10 次)
      // health = 0.8 * 0.6 + 0.4 * 0.4 = 0.48 + 0.16 = 0.64
      expect(health).toBeCloseTo(0.64, 1);

      const evo = store.getOrCreateSkillEvolution("test-skill");
      expect(evo.usage_count).toBe(10);
      expect(evo.success_rate).toBeCloseTo(0.8, 1);
    });

    it("无使用数据时返回 1.0", () => {
      store.getOrCreateSkillEvolution("unused-skill");
      const health = store.recalcSkillHealth("unused-skill");
      expect(health).toBe(1.0);
    });
  });

  // ------------------------------------------------------------------
  // 进化提案
  // ------------------------------------------------------------------

  describe("createEvolutionProposal / getPendingProposals", () => {
    it("可以创建和查询提案", () => {
      store.getOrCreateSkillEvolution("test-skill");

      const id = store.createEvolutionProposal({
        skill_name: "test-skill",
        proposal_type: "fix",
        proposal: {
          reason: "健康分数过低",
          suggested_changes: "优化错误处理",
          priority: 3,
        },
      });

      expect(id).toBeGreaterThan(0);

      const pending = store.getPendingProposals();
      expect(pending).toHaveLength(1);
      expect(pending[0]?.skill_name).toBe("test-skill");
      expect(pending[0]?.proposal_type).toBe("fix");
      expect(pending[0]?.proposal.reason).toBe("健康分数过低");
      expect(pending[0]?.status).toBe("pending");
    });

    it("创建提案时标记技能为待进化", () => {
      store.getOrCreateSkillEvolution("test-skill");

      store.createEvolutionProposal({
        skill_name: "test-skill",
        proposal_type: "fix",
        proposal: { reason: "测试" },
      });

      const evo = store.getOrCreateSkillEvolution("test-skill");
      expect(evo.evolution_pending).toBe("fix");
      expect(evo.evolution_reason).toBe("测试");
    });
  });

  describe("reviewProposal", () => {
    it("批准提案", () => {
      store.getOrCreateSkillEvolution("test-skill");
      const id = store.createEvolutionProposal({
        skill_name: "test-skill",
        proposal_type: "fix",
        proposal: { reason: "测试" },
      });

      store.reviewProposal(id, "approved", "cli");

      const pending = store.getPendingProposals();
      expect(pending).toHaveLength(0);
    });

    it("拒绝提案时清除技能待进化标记", () => {
      store.getOrCreateSkillEvolution("test-skill");
      const id = store.createEvolutionProposal({
        skill_name: "test-skill",
        proposal_type: "fix",
        proposal: { reason: "测试拒绝" },
      });

      // 确认待进化标记存在
      let evo = store.getOrCreateSkillEvolution("test-skill");
      expect(evo.evolution_pending).toBe("fix");

      store.reviewProposal(id, "rejected", "cli");

      // 确认待进化标记已清除
      evo = store.getOrCreateSkillEvolution("test-skill");
      expect(evo.evolution_pending).toBe("none");
    });
  });

  describe("markProposalApplied", () => {
    it("标记提案为已应用", () => {
      store.getOrCreateSkillEvolution("test-skill");
      const id = store.createEvolutionProposal({
        skill_name: "test-skill",
        proposal_type: "fix",
        proposal: { reason: "测试" },
      });

      store.reviewProposal(id, "approved", "cli");
      store.markProposalApplied(id);

      // 查询数据库确认状态
      const pending = store.getPendingProposals();
      expect(pending).toHaveLength(0);
    });
  });

  // ------------------------------------------------------------------
  // 技能快照
  // ------------------------------------------------------------------

  describe("createSkillSnapshot / getSkillSnapshot", () => {
    it("可以创建和读取快照", () => {
      const content = "# Test Skill\n\nSome content here.";
      const key = store.createSkillSnapshot("test-skill", content);

      expect(key).toContain("snapshot:test-skill:");

      const retrieved = store.getSkillSnapshot(key);
      expect(retrieved).toBe(content);
    });

    it("不存在的快照返回 null", () => {
      const result = store.getSkillSnapshot("nonexistent-key");
      expect(result).toBeNull();
    });
  });
});
