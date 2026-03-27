/**
 * core/src/guardrails/permission.ts
 * PermissionRequest 钩子评估函数
 *
 * permission-request.sh 的全部逻辑移植到 TypeScript。
 * 自动批准安全的命令（只读 git、测试命令等）。
 *
 * 引用源: scripts/permission-request.sh
 */

import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { type HookInput, type HookResult } from "../types.js";

// ============================================================
// PermissionRequest 专有的输出形式
// ============================================================

/** PermissionRequest 钩子的决定响应 */
interface PermissionResponse {
  hookSpecificOutput: {
    hookEventName: "PermissionRequest";
    decision: {
      behavior: "allow" | "deny";
    };
  };
}

function makeAllow(): PermissionResponse {
  return {
    hookSpecificOutput: {
      hookEventName: "PermissionRequest",
      decision: { behavior: "allow" },
    },
  };
}

// ============================================================
// 包管理器自动批准许可列表
// ============================================================

/**
 * .claude/config/allowed-pkg-managers.json 存在且 allowed: true 时
 * 自动批准 npm/pnpm/yarn 的 test/build/lint 等命令。
 */
function isPkgManagerAllowed(cwd: string): boolean {
  const allowlistPath = join(cwd, ".claude", "config", "allowed-pkg-managers.json");
  if (!existsSync(allowlistPath)) return false;

  try {
    const raw = readFileSync(allowlistPath, "utf-8");
    const data = JSON.parse(raw) as unknown;
    if (typeof data === "object" && data !== null && "allowed" in data) {
      return (data as Record<string, unknown>)["allowed"] === true;
    }
  } catch {
    // JSON 解析错误视为不批准
  }

  return false;
}

// ============================================================
// 安全的命令判定
// ============================================================

/**
 * 判断命令字符串是否可以自动批准。
 *
 * security hardening:
 * - 包含管道、重定向、变量展开、命令替换时不批准（保守）
 * - 仅自动批准简单的命令
 */
function isSafeCommand(command: string, cwd: string): boolean {
  // 多行命令不批准
  if (command.includes("\n") || command.includes("\r")) return false;

  // 包含 shell 特殊字符（管道、重定向、变量展开、命令替换）时不批准
  if (/[;&|<>`$]/.test(command)) return false;

  // 只读 git 命令始终安全
  if (/^git\s+(status|diff|log|branch|rev-parse|show|ls-files)(\s|$)/i.test(command)) {
    return true;
  }

  // JS/TS 测试/验证命令检查包管理器许可列表
  if (
    /^(npm|pnpm|yarn)\s+(test|run\s+(test|lint|typecheck|build|validate)|lint|typecheck|build)(\s|$)/i.test(
      command
    )
  ) {
    return isPkgManagerAllowed(cwd);
  }

  // Python 测试（无 package.json 风险）
  if (/^(pytest|python\s+-m\s+pytest)(\s|$)/i.test(command)) return true;

  // Go / Rust 测试
  if (/^(go\s+test|cargo\s+test)(\s|$)/i.test(command)) return true;

  return false;
}

// ============================================================
// evaluatePermission: 主导出
// ============================================================

/**
 * PermissionRequest 钩子的评估函数。
 *
 * Edit/Write 以 bypassPermissions 等效方式自动批准。
 * Bash 仅自动批准安全的命令模式。
 * 其他不返回任何内容（默认行为 = 询问用户）。
 */
export function evaluatePermission(input: HookInput): HookResult {
  const toolName = input.tool_name;
  const cwd = input.cwd ?? process.cwd();

  // Edit / Write 自动批准（bypassPermissions 模式补充）
  if (toolName === "Edit" || toolName === "Write" || toolName === "MultiEdit") {
    return _permissionResponseToHookResult(makeAllow());
  }

  // Bash 以外为默认行为（透传）
  if (toolName !== "Bash") {
    return { decision: "approve" };
  }

  // Bash: 获取命令并检查安全性
  const command = input.tool_input["command"];
  if (typeof command !== "string" || command.trim() === "") {
    return { decision: "approve" };
  }

  if (isSafeCommand(command, cwd)) {
    return _permissionResponseToHookResult(makeAllow());
  }

  // 不安全的命令采用默认行为（委托给用户确认）
  return { decision: "approve" };
}

/**
 * 将 PermissionResponse 转换为 HookResult。
 *
 * PermissionRequest 钩子与通常的 HookResult 有不同的输出形式，
 * 但在内部类型系统中作为 HookResult 处理，
 * index.ts 的 route() 在 stdout 输出时使用 formatPermissionOutput()
 * 转换为正确形式（Phase 17.1.7 替换 hooks.json 后计划支持）。
 */
function _permissionResponseToHookResult(response: PermissionResponse): HookResult {
  return {
    decision: "approve",
    systemMessage: JSON.stringify(response),
  };
}

/**
 * 生成 PermissionRequest 钩子用的 stdout 输出。
 * 从 index.ts 的 route() 在 "permission" 钩子类型时调用。
 */
export function formatPermissionOutput(result: HookResult): string {
  // systemMessage 中包含 PermissionResponse 的 JSON 时优先使用
  if (result.systemMessage !== undefined) {
    try {
      const parsed = JSON.parse(result.systemMessage) as unknown;
      if (
        typeof parsed === "object" &&
        parsed !== null &&
        "hookSpecificOutput" in parsed
      ) {
        return JSON.stringify(parsed);
      }
    } catch {
      // 解析失败时作为通常的 HookResult 输出
    }
  }

  return JSON.stringify(result);
}
