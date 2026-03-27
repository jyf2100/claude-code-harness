/**
 * core/src/guardrails/pre-tool.ts
 * PreToolUse 钩子评估函数
 *
 * 接收 HookInput，评估 rules.ts 中的声明式护栏规则表，
 * 返回 approve / deny / ask 的 HookResult。
 */

import { existsSync } from "node:fs";
import { resolve } from "node:path";
import { type HookInput, type HookResult, type RuleContext } from "../types.js";
import { evaluateRules } from "./rules.js";
import { HarnessStore } from "../state/store.js";

/** 判断环境变量是否为真值（"1", "true", "yes"） */
function isTruthy(value: string | undefined): boolean {
  return value === "1" || value === "true" || value === "yes";
}

/**
 * 从项目根目录解析 SQLite DB 路径。
 * .harness/state.db 不存在时返回 null。
 */
function resolveDbPath(projectRoot: string): string | null {
  const dbPath = resolve(projectRoot, ".harness", "state.db");
  return existsSync(dbPath) ? dbPath : null;
}

/**
 * 从执行环境组装 RuleContext。
 * 优先级: SQLite work_states > 环境变量
 */
function buildContext(input: HookInput): RuleContext {
  // cwd 为项目根目录。plugin_root 是插件自身的路径，因此排除
  const projectRoot =
    input.cwd ??
    process.env["HARNESS_PROJECT_ROOT"] ??
    process.env["PROJECT_ROOT"] ??
    process.cwd();

  // 基于环境变量的初始值
  let workMode =
    isTruthy(process.env["HARNESS_WORK_MODE"]) ||
    isTruthy(process.env["ULTRAWORK_MODE"]);
  let codexMode = isTruthy(process.env["HARNESS_CODEX_MODE"]);

  // breezing 角色: 从环境变量获取
  const breezingRole = process.env["HARNESS_BREEZING_ROLE"] ?? null;

  // 从 SQLite work_states 补充（session_id 可用时）
  const sessionId = input.session_id;
  if (sessionId) {
    const dbPath = resolveDbPath(projectRoot);
    if (dbPath !== null) {
      try {
        const store = new HarnessStore(dbPath);
        try {
          const state = store.getWorkState(sessionId);
          if (state !== null) {
            // 使用 DB 的值覆盖环境变量（可靠性更高）
            workMode = workMode || state.bypassRmRf || state.bypassGitPush;
            codexMode = codexMode || state.codexMode;
          }
        } finally {
          store.close();
        }
      } catch {
        // DB 访问失败时忽略（使用环境变量回退）
      }
    }
  }

  return {
    input,
    projectRoot,
    workMode,
    codexMode,
    breezingRole,
  };
}

/**
 * PreToolUse 钩子的入口点。
 * 接收 HookInput，评估护栏规则并返回 HookResult。
 */
export function evaluatePreTool(input: HookInput): HookResult {
  const ctx = buildContext(input);
  return evaluateRules(ctx);
}
