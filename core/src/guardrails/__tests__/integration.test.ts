/**
 * core/src/guardrails/__tests__/integration.test.ts
 * Harness v3 护栏 E2E 集成测试
 *
 * 通过实际的钩子调用流程（evaluatePreTool → evaluatePostTool）
 * 验证 9 个护栏规则能够正确协作运行。
 *
 * 与单元测试的区别:
 *   - rules.test.ts: 单个规则函数的单元测试
 *   - integration.test.ts: PreToolUse → PostToolUse 的完整流程测试
 */

import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { evaluatePreTool } from "../pre-tool.js";
import { evaluatePostTool } from "../post-tool.js";
import type { HookInput } from "../../types.js";

// ============================================================
// 测试辅助函数
// ============================================================

function buildInput(
  toolName: string,
  toolInput: Record<string, unknown>,
  overrides?: Partial<HookInput>
): HookInput {
  return {
    tool_name: toolName,
    tool_input: toolInput,
    session_id: "test-session",
    cwd: "/test/project",
    plugin_root: "/test/plugin",
    ...overrides,
  };
}

// ============================================================
// PreToolUse → 判定结果的集成测试
// ============================================================

describe("E2E: PreToolUse 流程", () => {
  // 每个测试中重置环境变量
  beforeEach(() => {
    delete process.env["HARNESS_WORK_MODE"];
    delete process.env["HARNESS_CODEX_MODE"];
    delete process.env["HARNESS_BREEZING_ROLE"];
    delete process.env["HARNESS_PROJECT_ROOT"];
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  // ------------------------------------------------------------------
  // 正常情况: 没有问题的操作会被 approve
  // ------------------------------------------------------------------

  describe("approve 情况", () => {
    it("普通 Bash 命令会被 approve", async () => {
      const result = await evaluatePreTool(
        buildInput("Bash", { command: "npm test" })
      );
      expect(result.decision).toBe("approve");
    });

    it("普通文件写入会被 approve", async () => {
      const result = await evaluatePreTool(
        buildInput("Write", { file_path: "/test/project/src/index.ts" })
      );
      expect(result.decision).toBe("approve");
    });

    it("不带 rm -r 标志的删除会被 approve", async () => {
      const result = await evaluatePreTool(
        buildInput("Bash", { command: "rm /tmp/test.log" })
      );
      expect(result.decision).toBe("approve");
    });

    it("git push（不带 force）会被 approve", async () => {
      const result = await evaluatePreTool(
        buildInput("Bash", { command: "git push origin feature/login" })
      );
      expect(result.decision).toBe("approve");
    });

    it("普通 Read 会被 approve", async () => {
      const result = await evaluatePreTool(
        buildInput("Read", { file_path: "/test/project/src/app.ts" })
      );
      expect(result.decision).toBe("approve");
    });
  });

  // ------------------------------------------------------------------
  // deny 情况: 危险操作会被阻止
  // ------------------------------------------------------------------

  describe("deny 情况", () => {
    it("sudo 会被 deny", async () => {
      const result = await evaluatePreTool(
        buildInput("Bash", { command: "sudo apt-get update" })
      );
      expect(result.decision).toBe("deny");
      expect(result.reason).toContain("sudo");
    });

    it("git push --force 会被 deny", async () => {
      const result = await evaluatePreTool(
        buildInput("Bash", { command: "git push --force origin main" })
      );
      expect(result.decision).toBe("deny");
      expect(result.reason).toContain("force");
    });

    it("git push -f 也会被 deny", async () => {
      const result = await evaluatePreTool(
        buildInput("Bash", { command: "git push -f origin main" })
      );
      expect(result.decision).toBe("deny");
    });

    it("--no-verify 会被 deny", async () => {
      const result = await evaluatePreTool(
        buildInput("Bash", { command: "git commit --no-verify -m 'test'" })
      );
      expect(result.decision).toBe("deny");
      expect(result.reason).toContain("--no-verify");
    });

    it("--no-gpg-sign 会被 deny", async () => {
      const result = await evaluatePreTool(
        buildInput("Bash", { command: "git commit --no-gpg-sign -m 'test'" })
      );
      expect(result.decision).toBe("deny");
      expect(result.reason).toContain("--no-gpg-sign");
    });

    it("git reset --hard main 会被 deny", async () => {
      const result = await evaluatePreTool(
        buildInput("Bash", { command: "git reset --hard main" })
      );
      expect(result.decision).toBe("deny");
      expect(result.reason).toContain("reset --hard");
    });

    it("写入 .env 文件会被 deny", async () => {
      const result = await evaluatePreTool(
        buildInput("Write", { file_path: "/test/project/.env" })
      );
      expect(result.decision).toBe("deny");
      expect(result.reason).toContain(".env");
    });

    it("编辑 .git/ 目录会被 deny", async () => {
      const result = await evaluatePreTool(
        buildInput("Edit", { file_path: "/test/project/.git/config" })
      );
      expect(result.decision).toBe("deny");
    });

    it("通过 Bash 写入 .env 会被 deny", async () => {
      const result = await evaluatePreTool(
        buildInput("Bash", { command: "echo 'SECRET=123' > .env" })
      );
      expect(result.decision).toBe("deny");
    });

    it("通过 Bash 写入 .env 变体也会被 deny", async () => {
      const result = await evaluatePreTool(
        buildInput("Bash", { command: "echo 'KEY=val' >> .env.local" })
      );
      expect(result.decision).toBe("deny");
    });

    it("写入私钥文件会被 deny", async () => {
      const result = await evaluatePreTool(
        buildInput("Write", { file_path: "/root/.ssh/id_rsa" })
      );
      expect(result.decision).toBe("deny");
    });

    it("codex 模式下的 Write 会被 deny", async () => {
      process.env["HARNESS_CODEX_MODE"] = "1";
      const result = await evaluatePreTool(
        buildInput("Write", { file_path: "/test/project/src/app.ts" })
      );
      expect(result.decision).toBe("deny");
      expect(result.reason).toContain("Codex");
    });

    it("breezing reviewer 的 git commit 会被 deny", async () => {
      process.env["HARNESS_BREEZING_ROLE"] = "reviewer";
      const result = await evaluatePreTool(
        buildInput("Bash", { command: "git commit -m 'feat: add feature'" })
      );
      expect(result.decision).toBe("deny");
    });

    it("breezing reviewer 的 Write 会被 deny", async () => {
      process.env["HARNESS_BREEZING_ROLE"] = "reviewer";
      const result = await evaluatePreTool(
        buildInput("Write", { file_path: "/test/project/src/app.ts" })
      );
      expect(result.decision).toBe("deny");
    });
  });

  // ------------------------------------------------------------------
  // ask 情况: 需要确认的操作
  // ------------------------------------------------------------------

  describe("ask 情况（work 模式以外）", () => {
    it("rm -rf 会被 ask", async () => {
      const result = await evaluatePreTool(
        buildInput("Bash", { command: "rm -rf /tmp/test-dir" })
      );
      expect(result.decision).toBe("ask");
      expect(result.reason).toContain("rm");
    });

    it("rm -fr 也会被 ask", async () => {
      const result = await evaluatePreTool(
        buildInput("Bash", { command: "rm -fr dist/" })
      );
      expect(result.decision).toBe("ask");
    });

    it("写入项目外的绝对路径会被 ask", async () => {
      process.env["HARNESS_PROJECT_ROOT"] = "/test/project";
      const result = await evaluatePreTool(
        buildInput("Write", { file_path: "/etc/hosts" })
      );
      expect(result.decision).toBe("ask");
    });
  });

  // ------------------------------------------------------------------
  // work 模式: 可以绕过的操作
  // ------------------------------------------------------------------

  describe("work 模式绕过情况", () => {
    it("work 模式下 rm -rf 不会被 ask", async () => {
      process.env["HARNESS_WORK_MODE"] = "1";
      const result = await evaluatePreTool(
        buildInput("Bash", { command: "rm -rf dist/" })
      );
      // work 模式下跳过 ask 直接 approve
      expect(result.decision).toBe("approve");
    });

    it("work 模式下写入项目外也不会被 ask", async () => {
      process.env["HARNESS_WORK_MODE"] = "1";
      process.env["HARNESS_PROJECT_ROOT"] = "/test/project";
      const result = await evaluatePreTool(
        buildInput("Write", { file_path: "/tmp/output.txt" })
      );
      expect(result.decision).toBe("approve");
    });

    it("work 模式下 sudo 仍会被 deny（无例外）", async () => {
      process.env["HARNESS_WORK_MODE"] = "1";
      const result = await evaluatePreTool(
        buildInput("Bash", { command: "sudo make install" })
      );
      expect(result.decision).toBe("deny");
    });

    it("work 模式下 git push --force 仍会被 deny（无例外）", async () => {
      process.env["HARNESS_WORK_MODE"] = "1";
      const result = await evaluatePreTool(
        buildInput("Bash", { command: "git push --force origin main" })
      );
      expect(result.decision).toBe("deny");
    });
  });

  // ------------------------------------------------------------------
  // approve + systemMessage 情况: 带警告的批准
  // ------------------------------------------------------------------

  describe("approve + 警告 情况", () => {
    it(".env 文件的 Read 会被 approve 但会有警告", async () => {
      const result = await evaluatePreTool(
        buildInput("Read", { file_path: "/test/project/.env" })
      );
      expect(result.decision).toBe("approve");
      expect(result.systemMessage).toContain("警告");
      expect(result.systemMessage).toContain(".env");
    });

    it("git push origin main 返回 approve + systemMessage", async () => {
      const result = await evaluatePreTool(
        buildInput("Bash", { command: "git push origin main" })
      );
      expect(result.decision).toBe("approve");
      expect(result.systemMessage).toBeTruthy();
      expect(result.systemMessage).toContain("main");
    });

    it("写入 package.json 返回 approve + systemMessage", async () => {
      const result = await evaluatePreTool(
        buildInput("Write", { file_path: "/test/project/package.json" })
      );
      expect(result.decision).toBe("approve");
      expect(result.systemMessage).toBeTruthy();
      expect(result.systemMessage).toContain("package.json");
    });
  });
});

// ============================================================
// PostToolUse 流程
// ============================================================

describe("E2E: PostToolUse 流程", () => {
  beforeEach(() => {
    delete process.env["HARNESS_WORK_MODE"];
  });

  it("普通 Write 结果会被 approve", async () => {
    const result = await evaluatePostTool(
      buildInput("Write", {
        file_path: "/test/project/src/app.ts",
        content: "export const app = {};",
      })
    );
    expect(result.decision).toBe("approve");
  });

  it("检测到测试篡改时返回 approve + 警告", async () => {
    const result = await evaluatePostTool(
      buildInput("Write", {
        file_path: "/test/project/src/__tests__/app.test.ts",
        content: "it.skip('should work', () => { expect(true).toBe(true); });",
      })
    );
    expect(result.decision).toBe("approve");
    expect(result.systemMessage).toBeTruthy();
    expect(result.systemMessage).toContain("it.skip");
  });

  it("检测到 ESLint disable 注释时会有警告", async () => {
    const result = await evaluatePostTool(
      buildInput("Write", {
        file_path: "/test/project/.eslintrc.js",
        content: "/* eslint-disable */\nmodule.exports = {};",
      })
    );
    expect(result.decision).toBe("approve");
    expect(result.systemMessage).toBeTruthy();
  });

  it("检测到 CI 的 continue-on-error 添加时会有警告", async () => {
    const result = await evaluatePostTool(
      buildInput("Write", {
        file_path: "/test/project/.github/workflows/ci.yml",
        content: "continue-on-error: true",
      })
    );
    expect(result.decision).toBe("approve");
    expect(result.systemMessage).toBeTruthy();
  });

  it("普通 Bash 执行结果会被 approve", async () => {
    const result = await evaluatePostTool(
      buildInput("Bash", {
        command: "npm test",
        output: "Tests passed: 42",
      })
    );
    expect(result.decision).toBe("approve");
  });
});

// ============================================================
// Pre → Post 连续流程
// ============================================================

describe("E2E: PreToolUse → PostToolUse 连续流程", () => {
  it("正常 Write 操作在两个钩子中都会被 approve", async () => {
    const input = buildInput("Write", {
      file_path: "/test/project/src/feature.ts",
      content: "export const feature = () => 'hello';",
    });

    const preResult = await evaluatePreTool(input);
    expect(preResult.decision).toBe("approve");

    const postResult = await evaluatePostTool(input);
    expect(postResult.decision).toBe("approve");
  });

  it("sudo 会在 PreToolUse 被阻止（PostToolUse 不需要）", async () => {
    const input = buildInput("Bash", { command: "sudo apt-get install curl" });

    const preResult = await evaluatePreTool(input);
    expect(preResult.decision).toBe("deny");
    // 被 deny 时 PostToolUse 不会执行（这里只是模拟）
    expect(preResult.reason).toContain("sudo");
  });
});
