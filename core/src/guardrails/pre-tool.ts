/**
 * core/src/guardrails/pre-tool.ts
 * PreToolUse フック評価関数
 *
 * HookInput を受け取り、rules.ts の宣言的ガードルールテーブルを評価して
 * approve / deny / ask の HookResult を返す。
 */

import { existsSync } from "node:fs";
import { resolve } from "node:path";
import { type HookInput, type HookResult, type RuleContext } from "../types.js";
import { evaluateRules } from "./rules.js";
import { HarnessStore } from "../state/store.js";

/** 環境変数が truthy 値（"1", "true", "yes"）かどうか判定 */
function isTruthy(value: string | undefined): boolean {
  return value === "1" || value === "true" || value === "yes";
}

/**
 * プロジェクトルートから SQLite DB パスを解決する。
 * .harness/state.db が存在しない場合は null を返す。
 */
function resolveDbPath(projectRoot: string): string | null {
  const dbPath = resolve(projectRoot, ".harness", "state.db");
  return existsSync(dbPath) ? dbPath : null;
}

/**
 * 実行環境から RuleContext を組み立てる。
 * 優先順位: SQLite work_states > 環境変数
 */
function buildContext(input: HookInput): RuleContext {
  // cwd がプロジェクトルート。plugin_root はプラグイン自身のパスなので除外
  const projectRoot =
    input.cwd ??
    process.env["HARNESS_PROJECT_ROOT"] ??
    process.env["PROJECT_ROOT"] ??
    process.cwd();

  // 環境変数ベースの初期値
  let workMode =
    isTruthy(process.env["HARNESS_WORK_MODE"]) ||
    isTruthy(process.env["ULTRAWORK_MODE"]);
  let codexMode = isTruthy(process.env["HARNESS_CODEX_MODE"]);

  // breezing ロール: 環境変数から取得
  const breezingRole = process.env["HARNESS_BREEZING_ROLE"] ?? null;

  // SQLite work_states から補完（session_id が利用可能な場合）
  const sessionId = input.session_id;
  if (sessionId) {
    const dbPath = resolveDbPath(projectRoot);
    if (dbPath !== null) {
      try {
        const store = new HarnessStore(dbPath);
        try {
          const state = store.getWorkState(sessionId);
          if (state !== null) {
            // DB の値で環境変数を上書き（より信頼性が高い）
            workMode = workMode || state.bypassRmRf || state.bypassGitPush;
            codexMode = codexMode || state.codexMode;
          }
        } finally {
          store.close();
        }
      } catch {
        // DB アクセス失敗は無視（環境変数フォールバックを使用）
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
 * PreToolUse フックのエントリポイント。
 * HookInput を受け取り、ガードルールを評価して HookResult を返す。
 */
export function evaluatePreTool(input: HookInput): HookResult {
  const ctx = buildContext(input);
  return evaluateRules(ctx);
}
