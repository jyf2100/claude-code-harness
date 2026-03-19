/**
 * core/src/guardrails/tampering.ts
 * テスト改ざん検出エンジン
 *
 * posttooluse-tampering-detector.sh の全パターンを TypeScript に移植。
 * Write / Edit / MultiEdit ツールでテストファイルや CI 設定が変更された後、
 * 改ざんパターンを検出して警告を返す（ブロックはしない）。
 */
import type { HookInput, HookResult } from "../types.js";
/**
 * PostToolUse フックでテスト改ざんを検出し、警告を返す。
 * 改ざんを検出した場合でも decision は "approve"（ブロックしない）。
 * 警告は systemMessage として Claude に渡される。
 */
export declare function detectTestTampering(input: HookInput): HookResult;
//# sourceMappingURL=tampering.d.ts.map