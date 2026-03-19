/**
 * core/src/guardrails/pre-tool.ts
 * PreToolUse フック評価関数
 *
 * HookInput を受け取り、rules.ts の宣言的ガードルールテーブルを評価して
 * approve / deny / ask の HookResult を返す。
 */
import { type HookInput, type HookResult } from "../types.js";
/**
 * PreToolUse フックのエントリポイント。
 * HookInput を受け取り、ガードルールを評価して HookResult を返す。
 */
export declare function evaluatePreTool(input: HookInput): HookResult;
//# sourceMappingURL=pre-tool.d.ts.map