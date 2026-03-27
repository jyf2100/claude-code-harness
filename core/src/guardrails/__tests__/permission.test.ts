/**
 * core/src/guardrails/__tests__/permission.test.ts
 * permission.ts 单元测试
 *
 * 验证 permission-request.sh 的所有逻辑都已正确移植。
 */

import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { existsSync, readFileSync } from "node:fs";
import { evaluatePermission, formatPermissionOutput } from "../permission.js";
import type { HookInput } from "../../types.js";

// 模拟 fs 模块
vi.mock("node:fs");

const mockedExistsSync = vi.mocked(existsSync);
const mockedReadFileSync = vi.mocked(readFileSync);

function makeInput(
  toolName: string,
  toolInput: Record<string, unknown> = {},
  cwd = "/project"
): HookInput {
  const input: HookInput = { tool_name: toolName, tool_input: toolInput };
  input.cwd = cwd;
  return input;
}

beforeEach(() => {
  vi.clearAllMocks();
  // 默认: 许可列表文件不存在
  mockedExistsSync.mockReturnValue(false);
});

afterEach(() => {
  vi.restoreAllMocks();
});

// ============================================================
// Edit / Write 自动批准
// ============================================================
describe("Edit / Write 自动批准", () => {
  it("自动批准 Edit 工具", () => {
    const result = evaluatePermission(
      makeInput("Edit", { file_path: "/project/src/foo.ts" })
    );
    // 返回 approve，systemMessage 包含 PermissionRequest JSON
    expect(result.decision).toBe("approve");
    expect(result.systemMessage).toBeDefined();
    const parsed = JSON.parse(result.systemMessage!);
    expect(parsed.hookSpecificOutput.decision.behavior).toBe("allow");
  });

  it("自动批准 Write 工具", () => {
    const result = evaluatePermission(
      makeInput("Write", { file_path: "/project/src/bar.ts", content: "" })
    );
    expect(result.decision).toBe("approve");
    expect(result.systemMessage).toBeDefined();
    const parsed = JSON.parse(result.systemMessage!);
    expect(parsed.hookSpecificOutput.decision.behavior).toBe("allow");
  });

  it("自动批准 MultiEdit 工具", () => {
    const result = evaluatePermission(makeInput("MultiEdit"));
    expect(result.decision).toBe("approve");
    expect(result.systemMessage).toBeDefined();
  });
});

// ============================================================
// Bash: read-only git 命令自动批准
// ============================================================
describe("Bash: read-only git 命令自动批准", () => {
  const readOnlyGitCmds = [
    "git status",
    "git diff",
    "git log --oneline -5",
    "git branch -a",
    "git rev-parse HEAD",
    "git show HEAD",
    "git ls-files",
  ];

  for (const cmd of readOnlyGitCmds) {
    it(`自动批准 ${cmd}`, () => {
      const result = evaluatePermission(
        makeInput("Bash", { command: cmd })
      );
      expect(result.decision).toBe("approve");
      expect(result.systemMessage).toBeDefined();
      const parsed = JSON.parse(result.systemMessage!);
      expect(parsed.hookSpecificOutput.decision.behavior).toBe("allow");
    });
  }
});

// ============================================================
// Bash: npm/pnpm/yarn — 无许可列表不批准（仅 approve）
// ============================================================
describe("Bash: npm/pnpm/yarn — 无许可列表不批准", () => {
  it("没有许可列表时 npm test 执行默认行为（approve）", () => {
    mockedExistsSync.mockReturnValue(false);
    const result = evaluatePermission(
      makeInput("Bash", { command: "npm test" })
    );
    // 因为不安全所以只有 approve 没有 systemMessage
    expect(result.decision).toBe("approve");
    expect(result.systemMessage).toBeUndefined();
  });
});

// ============================================================
// Bash: npm/pnpm/yarn — 有许可列表自动批准
// ============================================================
describe("Bash: npm/pnpm/yarn — 有许可列表自动批准", () => {
  beforeEach(() => {
    mockedExistsSync.mockReturnValue(true);
    mockedReadFileSync.mockReturnValue(
      JSON.stringify({ allowed: true }) as unknown as Buffer
    );
  });

  const pkgCmds = [
    "npm test",
    "npm run test",
    "npm run lint",
    "npm run typecheck",
    "npm run build",
    "npm run validate",
    "pnpm test",
    "yarn test",
    "yarn lint",
  ];

  for (const cmd of pkgCmds) {
    it(`自动批准 ${cmd}（有许可列表）`, () => {
      const result = evaluatePermission(
        makeInput("Bash", { command: cmd })
      );
      expect(result.decision).toBe("approve");
      expect(result.systemMessage).toBeDefined();
      const parsed = JSON.parse(result.systemMessage!);
      expect(parsed.hookSpecificOutput.decision.behavior).toBe("allow");
    });
  }
});

// ============================================================
// Bash: Python / Go / Rust 测试自动批准
// ============================================================
describe("Bash: Python / Go / Rust 测试自动批准", () => {
  const safeCmds = [
    "pytest",
    "pytest -v",
    "python -m pytest",
    "go test ./...",
    "cargo test",
  ];

  for (const cmd of safeCmds) {
    it(`自动批准 ${cmd}`, () => {
      const result = evaluatePermission(
        makeInput("Bash", { command: cmd })
      );
      expect(result.decision).toBe("approve");
      expect(result.systemMessage).toBeDefined();
    });
  }
});

// ============================================================
// Bash: 包含 shell 特殊字符的命令不批准
// ============================================================
describe("Bash: 包含 shell 特殊字符的命令不批准", () => {
  const dangerousCmds = [
    "git status | grep modified",
    "npm test && git push",
    "npm test; echo done",
    "echo $HOME",
    "cat file > output",
    "cmd `dangerous`",
  ];

  for (const cmd of dangerousCmds) {
    it(`"${cmd}" 执行默认行为（仅 approve）`, () => {
      const result = evaluatePermission(
        makeInput("Bash", { command: cmd })
      );
      // 保守: 返回 approve 但没有 systemMessage（自动批准）
      expect(result.decision).toBe("approve");
      expect(result.systemMessage).toBeUndefined();
    });
  }
});

// ============================================================
// Bash: 其他工具直接通过
// ============================================================
describe("其他工具执行默认行为", () => {
  const otherTools = ["Read", "Glob", "Grep", "Task", "Skill"];

  for (const tool of otherTools) {
    it(`${tool} 执行默认行为（approve）`, () => {
      const result = evaluatePermission(makeInput(tool));
      expect(result.decision).toBe("approve");
      expect(result.systemMessage).toBeUndefined();
    });
  }
});

// ============================================================
// formatPermissionOutput
// ============================================================
describe("formatPermissionOutput", () => {
  it("正确输出包含 PermissionResponse JSON 的 systemMessage", () => {
    const result = evaluatePermission(
      makeInput("Edit", { file_path: "/project/src/foo.ts" })
    );
    const output = formatPermissionOutput(result);
    const parsed = JSON.parse(output);
    expect(parsed.hookSpecificOutput.hookEventName).toBe("PermissionRequest");
    expect(parsed.hookSpecificOutput.decision.behavior).toBe("allow");
  });

  it("没有 systemMessage 时输出普通 HookResult", () => {
    const result = evaluatePermission(makeInput("Bash", { command: "rm -rf /" }));
    const output = formatPermissionOutput(result);
    const parsed = JSON.parse(output);
    expect(parsed.decision).toBe("approve");
  });
});
