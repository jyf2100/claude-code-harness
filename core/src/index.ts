/**
 * core/src/index.ts
 * Harness v3 核心引擎入口点
 *
 * 从 stdin 读取 JSON，根据钩子类型进行路由，
 * 向 stdout 返回 JSON 响应的基本管道。
 *
 * 使用方法:
 *   echo '{"tool_name":"Bash","tool_input":{...}}' | node dist/index.js pre-tool
 *   echo '{"tool_name":"Write","tool_input":{...}}' | node dist/index.js post-tool
 */

import { type HookInput, type HookResult } from "./types.js";

/** 支持的钩子类型 */
type HookType = "pre-tool" | "post-tool" | "permission";

/**
 * 读取 stdin 全部内容并返回字符串
 */
async function readStdin(): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk as Buffer);
  }
  return Buffer.concat(chunks).toString("utf-8");
}

/**
 * 解析 stdin JSON 并获取 HookInput
 */
function parseInput(raw: string): HookInput {
  const parsed: unknown = JSON.parse(raw);

  if (
    typeof parsed !== "object" ||
    parsed === null ||
    !("tool_name" in parsed) ||
    typeof (parsed as Record<string, unknown>)["tool_name"] !== "string"
  ) {
    throw new Error("Invalid hook input: missing required field 'tool_name'");
  }

  const obj = parsed as Record<string, unknown>;

  const result: HookInput = {
    tool_name: obj["tool_name"] as string,
    tool_input:
      typeof obj["tool_input"] === "object" && obj["tool_input"] !== null
        ? (obj["tool_input"] as Record<string, unknown>)
        : {},
  };

  if (typeof obj["session_id"] === "string") {
    result.session_id = obj["session_id"];
  }
  if (typeof obj["cwd"] === "string") {
    result.cwd = obj["cwd"];
  }
  if (typeof obj["plugin_root"] === "string") {
    result.plugin_root = obj["plugin_root"];
  }

  return result;
}

/**
 * 根据钩子类型路由到处理器
 * 各 Phase 中实现会被添加的扩展点
 */
async function route(
  hookType: HookType,
  input: HookInput
): Promise<HookResult> {
  switch (hookType) {
    case "pre-tool": {
      // Phase 17.1 计划在 core/guardrails/pre-tool.ts 中实现
      const { evaluatePreTool } = await import("./guardrails/pre-tool.js");
      return evaluatePreTool(input);
    }
    case "post-tool": {
      // Phase 17.1 计划在 core/guardrails/post-tool.ts 中实现
      const { evaluatePostTool } = await import("./guardrails/post-tool.js");
      return evaluatePostTool(input);
    }
    case "permission": {
      const { evaluatePermission, formatPermissionOutput } = await import(
        "./guardrails/permission.js"
      );
      const permResult = evaluatePermission(input);
      // PermissionRequest 需要以 hookSpecificOutput 形式输出
      // 因此通过 formatPermissionOutput 进行转换，为了绕过 main() 的 JSON.stringify
      // 将最终 JSON 存入 systemMessage 中返回
      const permJson = formatPermissionOutput(permResult);
      return { decision: permResult.decision, systemMessage: permJson };
    }
    default: {
      // 未知的钩子类型以安全侧（approve）返回
      return {
        decision: "approve",
        reason: `Unknown hook type: ${String(hookType)}`,
      };
    }
  }
}

/**
 * 将错误转换为 HookResult 格式
 */
function errorToResult(err: unknown): HookResult {
  const message = err instanceof Error ? err.message : String(err);
  return {
    decision: "approve",
    reason: `Core engine error (safe fallback): ${message}`,
  };
}

/**
 * 主函数: stdin → parse → route → stdout
 */
async function main(): Promise<void> {
  const hookType = (process.argv[2] ?? "pre-tool") as HookType;

  let result: HookResult;

  try {
    const raw = await readStdin();

    if (!raw.trim()) {
      // 空输入安全地 approve
      result = { decision: "approve", reason: "Empty input" };
    } else {
      const input = parseInput(raw);
      result = await route(hookType, input);
    }
  } catch (err) {
    result = errorToResult(err);
  }

  // permission 钩子时最终 JSON 存储在 systemMessage 中
  if (hookType === "permission" && result.systemMessage !== undefined) {
    process.stdout.write(result.systemMessage + "\n");
  } else {
    process.stdout.write(JSON.stringify(result) + "\n");
  }
}

main().catch((err: unknown) => {
  const message = err instanceof Error ? err.message : String(err);
  process.stderr.write(`Fatal: ${message}\n`);
  process.exit(1);
});
