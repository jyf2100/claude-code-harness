/**
 * core/src/index.ts
 * Harness v3 コアエンジン エントリポイント
 *
 * stdin から JSON を読み込み、フックタイプに応じてルーティングし、
 * stdout に JSON レスポンスを返す基本パイプライン。
 *
 * 使用方法:
 *   echo '{"tool_name":"Bash","tool_input":{...}}' | node dist/index.js pre-tool
 *   echo '{"tool_name":"Write","tool_input":{...}}' | node dist/index.js post-tool
 */
/**
 * stdin を全読みして文字列を返す
 */
async function readStdin() {
    const chunks = [];
    for await (const chunk of process.stdin) {
        chunks.push(chunk);
    }
    return Buffer.concat(chunks).toString("utf-8");
}
/**
 * stdin JSON をパースして HookInput を取得する
 */
function parseInput(raw) {
    const parsed = JSON.parse(raw);
    if (typeof parsed !== "object" ||
        parsed === null ||
        !("tool_name" in parsed) ||
        typeof parsed["tool_name"] !== "string") {
        throw new Error("Invalid hook input: missing required field 'tool_name'");
    }
    const obj = parsed;
    const result = {
        tool_name: obj["tool_name"],
        tool_input: typeof obj["tool_input"] === "object" && obj["tool_input"] !== null
            ? obj["tool_input"]
            : {},
    };
    if (typeof obj["session_id"] === "string") {
        result.session_id = obj["session_id"];
    }
    if (typeof obj["cwd"] === "string") {
        result.cwd = obj["cwd"];
    }
    if (typeof obj["plugin_root"] === "string") {
        result.plugin_root = obj["plugin_root"];
    }
    return result;
}
/**
 * フックタイプに応じてハンドラへルーティングする
 * 各 Phase で実装が追加される拡張ポイント
 */
async function route(hookType, input) {
    switch (hookType) {
        case "pre-tool": {
            // Phase 17.1 で core/guardrails/pre-tool.ts に実装予定
            const { evaluatePreTool } = await import("./guardrails/pre-tool.js");
            return evaluatePreTool(input);
        }
        case "post-tool": {
            // Phase 17.1 で core/guardrails/post-tool.ts に実装予定
            const { evaluatePostTool } = await import("./guardrails/post-tool.js");
            return evaluatePostTool(input);
        }
        case "permission": {
            const { evaluatePermission, formatPermissionOutput } = await import("./guardrails/permission.js");
            const permResult = evaluatePermission(input);
            // PermissionRequest は hookSpecificOutput 形式で出力する必要があるため
            // formatPermissionOutput で変換し、main() の JSON.stringify をバイパスするために
            // systemMessage に最終 JSON を格納して返す
            const permJson = formatPermissionOutput(permResult);
            return { decision: permResult.decision, systemMessage: permJson };
        }
        default: {
            // 未知のフックタイプは安全側（approve）で返す
            return {
                decision: "approve",
                reason: `Unknown hook type: ${String(hookType)}`,
            };
        }
    }
}
/**
 * エラーを HookResult 形式に変換する
 */
function errorToResult(err) {
    const message = err instanceof Error ? err.message : String(err);
    return {
        decision: "approve",
        reason: `Core engine error (safe fallback): ${message}`,
    };
}
/**
 * メイン関数: stdin → parse → route → stdout
 */
async function main() {
    const hookType = (process.argv[2] ?? "pre-tool");
    let result;
    try {
        const raw = await readStdin();
        if (!raw.trim()) {
            // 空入力は安全に approve
            result = { decision: "approve", reason: "Empty input" };
        }
        else {
            const input = parseInput(raw);
            result = await route(hookType, input);
        }
    }
    catch (err) {
        result = errorToResult(err);
    }
    // permission フック時は systemMessage に最終 JSON が格納されている
    if (hookType === "permission" && result.systemMessage !== undefined) {
        process.stdout.write(result.systemMessage + "\n");
    }
    else {
        process.stdout.write(JSON.stringify(result) + "\n");
    }
}
main().catch((err) => {
    const message = err instanceof Error ? err.message : String(err);
    process.stderr.write(`Fatal: ${message}\n`);
    process.exit(1);
});
export {};
//# sourceMappingURL=index.js.map