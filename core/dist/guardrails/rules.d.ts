/**
 * core/src/guardrails/rules.ts
 * Harness v3 宣言的ガードルールテーブル
 *
 * pretooluse-guard.sh の全ルールを TypeScript 型安全な宣言的テーブルとして移植。
 * 各 GuardRule は条件 (toolPattern + evaluate) とアクション (HookResult) のペア。
 */
import type { GuardRule, HookResult, RuleContext } from "../types.js";
export declare const GUARD_RULES: readonly GuardRule[];
/**
 * 全ルールを順番に評価し、最初にマッチしたルールの HookResult を返す。
 * どのルールもマッチしない場合は approve を返す。
 */
export declare function evaluateRules(ctx: RuleContext): HookResult;
//# sourceMappingURL=rules.d.ts.map