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
import { detectTestTampering } from "./tampering.js";
// ============================================================
// セキュリティパターン検出（posttooluse-security-review.sh 移植）
// ============================================================
/**
 * 書き込まれたコード内のセキュリティリスクパターンを検出する。
 * 検出した場合は警告を systemMessage として追加（ブロックしない）。
 */
function detectSecurityRisks(input) {
    const toolInput = input.tool_input;
    const content = typeof toolInput["content"] === "string"
        ? toolInput["content"]
        : typeof toolInput["new_string"] === "string"
            ? toolInput["new_string"]
            : null;
    if (content === null)
        return [];
    const warnings = [];
    const securityPatterns = [
        {
            pattern: /process\.env\.[A-Z_]+.*(?:password|secret|key|token)/i,
            message: "機密情報を環境変数から直接文字列に埋め込んでいる可能性があります",
        },
        {
            pattern: /eval\s*\(\s*(?:request|req|input|param|query)/i,
            message: "ユーザー入力を eval() に渡すコードを検出しました（RCE リスク）",
        },
        {
            pattern: /exec\s*\(\s*`[^`]*\$\{/,
            message: "テンプレートリテラルを exec() に渡すコードを検出しました（コマンドインジェクションリスク）",
        },
        {
            pattern: /innerHTML\s*=\s*(?:.*\+.*|`[^`]*\$\{)/,
            message: "ユーザー入力を innerHTML に設定しているコードを検出しました（XSS リスク）",
        },
        {
            pattern: /(?:password|passwd|secret|api_key|apikey)\s*=\s*["'][^"']{8,}["']/i,
            message: "ハードコードされた機密情報（パスワード/APIキー）を検出しました",
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
// PostToolUse 統合エントリポイント
// ============================================================
/**
 * PostToolUse フックのエントリポイント。
 * 複数の検出器を並列実行し、警告を統合して返す。
 */
export async function evaluatePostTool(input) {
    // Write / Edit / MultiEdit のみ詳細チェック
    const isWriteOp = ["Write", "Edit", "MultiEdit"].includes(input.tool_name);
    if (!isWriteOp) {
        return { decision: "approve" };
    }
    // 並列実行（Promise.allSettled で一方の失敗が全体に影響しないように）
    const [tamperingResult, securityWarnings] = await Promise.allSettled([
        Promise.resolve(detectTestTampering(input)),
        Promise.resolve(detectSecurityRisks(input)),
    ]);
    const systemMessages = [];
    // 改ざん検出の警告を収集
    if (tamperingResult.status === "fulfilled" &&
        tamperingResult.value.systemMessage) {
        systemMessages.push(tamperingResult.value.systemMessage);
    }
    // セキュリティ警告を収集
    if (securityWarnings.status === "fulfilled" &&
        securityWarnings.value.length > 0) {
        const secLines = securityWarnings.value
            .map((w) => `- ${w}`)
            .join("\n");
        systemMessages.push(`[Harness v3] セキュリティリスク検出:\n${secLines}`);
    }
    if (systemMessages.length === 0) {
        return { decision: "approve" };
    }
    return {
        decision: "approve",
        systemMessage: systemMessages.join("\n\n---\n\n"),
    };
}
//# sourceMappingURL=post-tool.js.map