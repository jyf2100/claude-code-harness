/**
 * core/src/guardrails/post-tool.ts
 * PostToolUse フック統合評価関数
 *
 * 以下の PostToolUse スクリプト群を Promise.allSettled で並列実行し、
 * 結果を集約して HookResult として返す:
 *
 * 1. tampering-detector: テスト改ざん検出（警告のみ）
 * 2. security-review: セキュリティパターン検出（警告のみ）
 *
 * その他（log-toolname, commit-cleanup 等）は副作用のみで HookResult に影響しないため
 * hooks.json の別エントリとして独立して実行する設計を維持する。
 */
import type { HookInput, HookResult } from "../types.js";
/**
 * PostToolUse フックのエントリポイント。
 * 複数の検出器を並列実行し、警告を統合して返す。
 */
export declare function evaluatePostTool(input: HookInput): Promise<HookResult>;
//# sourceMappingURL=post-tool.d.ts.map