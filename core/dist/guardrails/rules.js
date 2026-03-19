/**
 * core/src/guardrails/rules.ts
 * Harness v3 宣言的ガードルールテーブル
 *
 * pretooluse-guard.sh の全ルールを TypeScript 型安全な宣言的テーブルとして移植。
 * 各 GuardRule は条件 (toolPattern + evaluate) とアクション (HookResult) のペア。
 */
// ============================================================
// ヘルパー関数
// ============================================================
/** ファイルパスが保護されたパスに該当するか判定 */
function isProtectedPath(filePath) {
    const protected_patterns = [
        /^\.git\//,
        /\/\.git\//,
        /^\.env$/,
        /\/\.env$/,
        /\.env\./,
        /id_rsa/,
        /id_ed25519/,
        /id_ecdsa/,
        /id_dsa/,
        /\.pem$/,
        /\.key$/,
        /\.p12$/,
        /\.pfx$/,
        /authorized_keys/,
        /known_hosts/,
    ];
    return protected_patterns.some((p) => p.test(filePath));
}
/** ファイルパスがプロジェクトルート配下にあるか判定 */
function isUnderProjectRoot(filePath, projectRoot) {
    const root = projectRoot.endsWith("/") ? projectRoot : `${projectRoot}/`;
    return filePath.startsWith(root) || filePath === projectRoot;
}
/** Bash コマンド文字列から危険な rm -rf パターンを検出 */
function hasDangerousRmRf(command) {
    // -rf または -fr フラグを含む rm コマンドを検出
    // 注意: rm -f（-r なし）は対象外
    if (/\brm\s+(?:[^\s]*\s+)*-(?=[^-]*r)[rf]+\b/.test(command))
        return true;
    if (/\brm\s+--recursive\b/.test(command))
        return true;
    return false;
}
/** git push --force パターンを検出 */
function hasForcePush(command) {
    return /\bgit\s+push\b.*--force(?:-with-lease)?\b/.test(command) ||
        /\bgit\s+push\b.*-f\b/.test(command);
}
/** sudo の使用を検出 */
function hasSudo(command) {
    return /(?:^|\s)sudo\s/.test(command);
}
// ============================================================
// ガードルールテーブル
// ============================================================
export const GUARD_RULES = [
    // ------------------------------------------------------------------
    // R01: sudo ブロック（Bash）
    // ------------------------------------------------------------------
    {
        id: "R01:no-sudo",
        toolPattern: /^Bash$/,
        evaluate(ctx) {
            const command = ctx.input.tool_input["command"];
            if (typeof command !== "string")
                return null;
            if (!hasSudo(command))
                return null;
            return {
                decision: "deny",
                reason: "sudo の使用は禁止されています。必要な場合はユーザーに手動実行を依頼してください。",
            };
        },
    },
    // ------------------------------------------------------------------
    // R02: 保護パスへの書き込みブロック（Write / Edit / Bash）
    // ------------------------------------------------------------------
    {
        id: "R02:no-write-protected-paths",
        toolPattern: /^(?:Write|Edit|MultiEdit)$/,
        evaluate(ctx) {
            const filePath = ctx.input.tool_input["file_path"];
            if (typeof filePath !== "string")
                return null;
            if (!isProtectedPath(filePath))
                return null;
            return {
                decision: "deny",
                reason: `保護されたパスへの書き込みは禁止されています: ${filePath}`,
            };
        },
    },
    // ------------------------------------------------------------------
    // R03: Bash での保護パスへの書き込みブロック（echo redirect / tee 等）
    // ------------------------------------------------------------------
    {
        id: "R03:no-bash-write-protected-paths",
        toolPattern: /^Bash$/,
        evaluate(ctx) {
            const command = ctx.input.tool_input["command"];
            if (typeof command !== "string")
                return null;
            // echo > .env, tee .git/config 等を検出
            // '>>' / '>' の後にスペースを挟んで保護パスが続くパターンも検出
            const writePatterns = [
                /(?:>>?|tee)\s+\S*\.env\b/,
                /(?:>>?|tee)\s+\S*\.env\./,
                /(?:>>?|tee)\s+\S*\.git\//,
                /(?:>>?|tee)\s+\S*id_rsa\b/,
                /(?:>>?|tee)\s+\S*id_ed25519\b/,
                /(?:>>?|tee)\s+\S*\.pem\b/,
                /(?:>>?|tee)\s+\S*\.key\b/,
            ];
            if (!writePatterns.some((p) => p.test(command)))
                return null;
            return {
                decision: "deny",
                reason: "保護されたファイルへのシェル書き込みは禁止されています。",
            };
        },
    },
    // ------------------------------------------------------------------
    // R04: プロジェクト外への書き込み確認（work モード時はスキップ）
    // ------------------------------------------------------------------
    {
        id: "R04:confirm-write-outside-project",
        toolPattern: /^(?:Write|Edit|MultiEdit)$/,
        evaluate(ctx) {
            const filePath = ctx.input.tool_input["file_path"];
            if (typeof filePath !== "string")
                return null;
            // 相対パスはプロジェクト内とみなす
            if (!filePath.startsWith("/"))
                return null;
            if (isUnderProjectRoot(filePath, ctx.projectRoot))
                return null;
            // work モード時は確認をスキップ
            if (ctx.workMode)
                return null;
            return {
                decision: "ask",
                reason: `プロジェクトルート外への書き込みです: ${filePath}\n許可しますか？`,
            };
        },
    },
    // ------------------------------------------------------------------
    // R05: rm -rf 確認（work モードでバイパス可）
    // ------------------------------------------------------------------
    {
        id: "R05:confirm-rm-rf",
        toolPattern: /^Bash$/,
        evaluate(ctx) {
            const command = ctx.input.tool_input["command"];
            if (typeof command !== "string")
                return null;
            if (!hasDangerousRmRf(command))
                return null;
            // work モードでバイパスが許可されている場合はスキップ
            if (ctx.workMode)
                return null;
            return {
                decision: "ask",
                reason: `危険な削除コマンドを検出しました:\n${command}\n実行しますか？`,
            };
        },
    },
    // ------------------------------------------------------------------
    // R06: git push --force ブロック（work モード時も例外なし）
    // ------------------------------------------------------------------
    {
        id: "R06:no-force-push",
        toolPattern: /^Bash$/,
        evaluate(ctx) {
            const command = ctx.input.tool_input["command"];
            if (typeof command !== "string")
                return null;
            if (!hasForcePush(command))
                return null;
            return {
                decision: "deny",
                reason: "git push --force は禁止されています。履歴を破壊する操作は許可されません。",
            };
        },
    },
    // ------------------------------------------------------------------
    // R07: Codex モード時の Write/Edit ブロック
    // Claude は PM 役 — 実装は Codex Worker に委譲
    // ------------------------------------------------------------------
    {
        id: "R07:codex-mode-no-write",
        toolPattern: /^(?:Write|Edit|MultiEdit)$/,
        evaluate(ctx) {
            // Write / Edit / MultiEdit のみ対象（Bash は除外）
            if (!["Write", "Edit", "MultiEdit"].includes(ctx.input.tool_name)) {
                return null;
            }
            if (!ctx.codexMode)
                return null;
            return {
                decision: "deny",
                reason: "Codex モード中は Claude が直接ファイルを書き込めません。実装は Codex Worker (codex exec) に委譲してください。",
            };
        },
    },
    // ------------------------------------------------------------------
    // R08: Breezing ロールガード — reviewer は Write/Edit 不可
    // ------------------------------------------------------------------
    {
        id: "R08:breezing-reviewer-no-write",
        toolPattern: /^(?:Write|Edit|MultiEdit|Bash)$/,
        evaluate(ctx) {
            if (ctx.breezingRole !== "reviewer")
                return null;
            // Bash は読み取り専用コマンドのみ許可（ブロックはスクリプト側で判断）
            if (ctx.input.tool_name === "Bash") {
                const command = ctx.input.tool_input["command"];
                if (typeof command !== "string")
                    return null;
                // git commit / git push / rm / mv 等を禁止
                const prohibited = [
                    /\bgit\s+(?:commit|push|reset|checkout|merge|rebase)\b/,
                    /\brm\s+/,
                    /\bmv\s+/,
                    /\bcp\s+.*-r\b/,
                ];
                if (!prohibited.some((p) => p.test(command)))
                    return null;
            }
            return {
                decision: "deny",
                reason: `Breezing reviewer ロールはファイル書き込みおよびデータ変更コマンドを実行できません。`,
            };
        },
    },
    // ------------------------------------------------------------------
    // R09: 機密情報を含むファイルへのアクセス制限（Read のみ警告）
    // ------------------------------------------------------------------
    {
        id: "R09:warn-secret-file-read",
        toolPattern: /^Read$/,
        evaluate(ctx) {
            const filePath = ctx.input.tool_input["file_path"];
            if (typeof filePath !== "string")
                return null;
            const secretPatterns = [/\.env$/, /id_rsa$/, /\.pem$/, /\.key$/, /secrets?\//];
            if (!secretPatterns.some((p) => p.test(filePath)))
                return null;
            return {
                decision: "approve",
                systemMessage: `警告: 機密情報が含まれる可能性のあるファイルを読み取っています: ${filePath}`,
            };
        },
    },
];
/**
 * 全ルールを順番に評価し、最初にマッチしたルールの HookResult を返す。
 * どのルールもマッチしない場合は approve を返す。
 */
export function evaluateRules(ctx) {
    const toolName = ctx.input.tool_name;
    for (const rule of GUARD_RULES) {
        if (!rule.toolPattern.test(toolName))
            continue;
        const result = rule.evaluate(ctx);
        if (result !== null)
            return result;
    }
    return { decision: "approve" };
}
//# sourceMappingURL=rules.js.map