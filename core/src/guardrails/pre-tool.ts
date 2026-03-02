/**
 * core/src/guardrails/pre-tool.ts
 * PreToolUse フック評価関数
 *
 * HookInput を受け取り、rules.ts の宣言的ガードルールテーブルを評価して
 * approve / deny / ask の HookResult を返す。
 */

import { type HookInput, type HookResult, type RuleContext } from "../types.js";
import { evaluateRules } from "./rules.js";

/**
 * 実行環境から RuleContext を組み立てる。
 * work-active.json / session-state の読み取りは Phase 17.2 で SQLite に移行予定。
 * 現時点では環境変数・HookInput の cwd / plugin_root からコンテキストを取得する。
 */
function buildContext(input: HookInput): RuleContext {
  const projectRoot =
    input.plugin_root ??
    input.cwd ??
    process.env["PROJECT_ROOT"] ??
    process.cwd();

  // work モード: 環境変数または work-active.json を参照（簡易実装）
  const workMode =
    process.env["HARNESS_WORK_MODE"] === "true" ||
    process.env["ULTRAWORK_MODE"] === "true";

  // codex モード: 環境変数から取得
  const codexMode = process.env["HARNESS_CODEX_MODE"] === "true";

  // breezing ロール: 環境変数から取得
  const breezingRole = process.env["HARNESS_BREEZING_ROLE"] ?? null;

  return {
    input,
    projectRoot,
    workMode,
    codexMode,
    breezingRole,
  };
}

/**
 * PreToolUse フックのエントリポイント。
 * HookInput を受け取り、ガードルールを評価して HookResult を返す。
 */
export function evaluatePreTool(input: HookInput): HookResult {
  const ctx = buildContext(input);
  return evaluateRules(ctx);
}
