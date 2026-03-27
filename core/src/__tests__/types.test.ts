/**
 * core/src/__tests__/types.test.ts
 * 类型定义的基本一致性检查
 */

import { describe, it, expect } from "vitest";
import type {
  HookInput,
  HookResult,
  GuardRule,
  Signal,
  TaskFailure,
  SessionState,
} from "../types.js";

describe("HookInput", () => {
  it("可以用最小字段构建", () => {
    const input: HookInput = {
      tool_name: "Bash",
      tool_input: { command: "ls" },
    };
    expect(input.tool_name).toBe("Bash");
    expect(input.tool_input).toEqual({ command: "ls" });
  });

  it("可以包含可选字段构建", () => {
    const input: HookInput = {
      tool_name: "Write",
      tool_input: { file_path: "/tmp/test.ts", content: "" },
      session_id: "sess-123",
      cwd: "/project",
      plugin_root: "/plugin",
    };
    expect(input.session_id).toBe("sess-123");
    expect(input.cwd).toBe("/project");
    expect(input.plugin_root).toBe("/plugin");
  });
});

describe("HookResult", () => {
  it("可以表示 approve 决定", () => {
    const result: HookResult = { decision: "approve" };
    expect(result.decision).toBe("approve");
  });

  it("可以表示 deny 决定和理由", () => {
    const result: HookResult = {
      decision: "deny",
      reason: "Protected path",
      systemMessage: "Cannot write to .git/",
    };
    expect(result.decision).toBe("deny");
    expect(result.reason).toBe("Protected path");
    expect(result.systemMessage).toBe("Cannot write to .git/");
  });

  it("可以表示 ask 决定", () => {
    const result: HookResult = {
      decision: "ask",
      reason: "Confirm git push?",
    };
    expect(result.decision).toBe("ask");
  });
});

describe("GuardRule", () => {
  it("可以正确构建规则结构", () => {
    const rule: GuardRule = {
      id: "block-git-dir",
      toolPattern: /^(Write|Edit)$/,
      evaluate: (ctx) => {
        const path = ctx.input.tool_input["file_path"];
        if (typeof path === "string" && path.includes(".git/")) {
          return { decision: "deny", reason: "Protected .git/ directory" };
        }
        return null;
      },
    };

    expect(rule.id).toBe("block-git-dir");
    expect(rule.toolPattern.test("Write")).toBe(true);
    expect(rule.toolPattern.test("Bash")).toBe(false);

    const mockCtx = {
      input: {
        tool_name: "Write",
        tool_input: { file_path: "/project/.git/config" },
      },
      projectRoot: "/project",
      workMode: false,
      codexMode: false,
      breezingRole: null,
    };

    const result = rule.evaluate(mockCtx);
    expect(result).not.toBeNull();
    expect(result?.decision).toBe("deny");
  });

  it("不匹配时返回 null", () => {
    const rule: GuardRule = {
      id: "test-rule",
      toolPattern: /^Bash$/,
      evaluate: () => null,
    };
    expect(rule.evaluate({
      input: { tool_name: "Bash", tool_input: {} },
      projectRoot: "/project",
      workMode: false,
      codexMode: false,
      breezingRole: null,
    })).toBeNull();
  });
});

describe("Signal", () => {
  it("可以构建信号", () => {
    const signal: Signal = {
      type: "task_completed",
      from_session_id: "sess-abc",
      payload: { task_id: "task-1", status: "success" },
      timestamp: new Date().toISOString(),
    };
    expect(signal.type).toBe("task_completed");
    expect(signal.from_session_id).toBe("sess-abc");
    expect(signal.to_session_id).toBeUndefined();
  });
});

describe("TaskFailure", () => {
  it("可以构建任务失败事件", () => {
    const failure: TaskFailure = {
      task_id: "task-1",
      severity: "error",
      message: "Build failed",
      timestamp: new Date().toISOString(),
      attempt: 1,
    };
    expect(failure.severity).toBe("error");
    expect(failure.attempt).toBe(1);
  });
});

describe("SessionState", () => {
  it("可以构建会话状态", () => {
    const state: SessionState = {
      session_id: "sess-xyz",
      mode: "work",
      project_root: "/project",
      started_at: new Date().toISOString(),
    };
    expect(state.mode).toBe("work");
  });
});
