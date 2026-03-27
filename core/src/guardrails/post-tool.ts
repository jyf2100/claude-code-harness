/**
 * core/src/guardrails/post-tool.ts
 * PostToolUse 钩子集成评估函数
 *
 * 以下 PostToolUse 脚本群使用 Promise.allSettled 并行执行，
 * 聚合结果并返回 HookResult：
 *
 * 1. tampering-detector: 测试篡改检测（仅警告）
 * 2. security-review: 安全模式检测（仅警告）
 *
 * 其他（log-toolname、commit-cleanup 等）仅产生副作用，不影响 HookResult，
 * 因此在 hooks.json 中作为独立条目单独执行的设计保持不变。
 */

import type { HookInput, HookResult } from "../types.js";
import { detectTestTampering } from "./tampering.js";

// ============================================================
// 安全模式检测（posttooluse-security-review.sh 移植）
// ============================================================

/**
 * 检测写入代码中的安全风险模式。
 * 检测到时将警告作为 systemMessage 添加（不阻止）。
 */
function detectSecurityRisks(input: HookInput): string[] {
  const toolInput = input.tool_input;
  const content =
    typeof toolInput["content"] === "string"
      ? toolInput["content"]
      : typeof toolInput["new_string"] === "string"
        ? toolInput["new_string"]
        : null;

  if (content === null) return [];

  const warnings: string[] = [];

  const securityPatterns: Array<{ pattern: RegExp; message: string }> = [
    {
      pattern: /process\.env\.[A-Z_]+.*(?:password|secret|key|token)/i,
      message: "可能将敏感信息从环境变量直接嵌入字符串中",
    },
    {
      pattern: /eval\s*\(\s*(?:request|req|input|param|query)/i,
      message: "检测到将用户输入传递给 eval() 的代码（RCE 风险）",
    },
    {
      pattern: /exec\s*\(\s*`[^`]*\$\{/,
      message: "检测到将模板字面量传递给 exec() 的代码（命令注入风险）",
    },
    {
      pattern: /innerHTML\s*=\s*(?:.*\+.*|`[^`]*\$\{)/,
      message: "检测到将用户输入设置为 innerHTML 的代码（XSS 风险）",
    },
    {
      pattern: /(?:password|passwd|secret|api_key|apikey)\s*=\s*["'][^"']{8,}["']/i,
      message: "检测到硬编码的敏感信息（密码/API密钥）",
    },
  ];

  for (const { pattern, message } of securityPatterns) {
    if (pattern.test(content)) {
      warnings.push(message);
    }
  }

  return warnings;
}

// ============================================================
// PostToolUse 集成入口点
// ============================================================

/**
 * PostToolUse 钩子的入口点。
 * 并行执行多个检测器，整合警告并返回。
 */
export async function evaluatePostTool(input: HookInput): Promise<HookResult> {
  // 仅对 Write / Edit / MultiEdit 进行详细检查
  const isWriteOp = ["Write", "Edit", "MultiEdit"].includes(input.tool_name);

  if (!isWriteOp) {
    return { decision: "approve" };
  }

  // 并行执行（使用 Promise.allSettled 防止单个失败影响整体）
  const [tamperingResult, securityWarnings] = await Promise.allSettled([
    Promise.resolve(detectTestTampering(input)),
    Promise.resolve(detectSecurityRisks(input)),
  ]);

  const systemMessages: string[] = [];

  // 收集篡改检测的警告
  if (
    tamperingResult.status === "fulfilled" &&
    tamperingResult.value.systemMessage
  ) {
    systemMessages.push(tamperingResult.value.systemMessage);
  }

  // 收集安全警告
  if (
    securityWarnings.status === "fulfilled" &&
    securityWarnings.value.length > 0
  ) {
    const secLines = securityWarnings.value
      .map((w) => `- ${w}`)
      .join("\n");
    systemMessages.push(
      `[Harness v3] 检测到安全风险:\n${secLines}`
    );
  }

  if (systemMessages.length === 0) {
    return { decision: "approve" };
  }

  return {
    decision: "approve",
    systemMessage: systemMessages.join("\n\n---\n\n"),
  };
}
