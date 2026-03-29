/**
 * core/src/guardrails/rules.ts
 * Harness v3 声明式护栏规则表
 *
 * 将 pretooluse-guard.sh 的全部规则移植为 TypeScript 类型安全的声明式表。
 * 每个 GuardRule 是条件 (toolPattern + evaluate) 和动作 (HookResult) 的配对。
 */

import type { GuardRule, HookResult, RuleContext } from "../types.js";
import { EVOLUTION_GUARD_RULES } from "./evolution-rules.js";

// ============================================================
// 辅助函数
// ============================================================

/** 判断文件路径是否匹配受保护路径 */
function isProtectedPath(filePath: string): boolean {
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

/** 判断文件路径是否在项目根目录下 */
function isUnderProjectRoot(filePath: string, projectRoot: string): boolean {
  const root = projectRoot.endsWith("/") ? projectRoot : `${projectRoot}/`;
  return filePath.startsWith(root) || filePath === projectRoot;
}

/** 从 Bash 命令字符串检测危险的 rm -rf 模式 */
function hasDangerousRmRf(command: string): boolean {
  // 检测包含 -rf 或 -fr 标志的 rm 命令
  // 注意: rm -f（不含 -r）不在检测范围内
  if (/\brm\s+(?:[^\s]*\s+)*-(?=[^-]*r)[rf]+\b/.test(command)) return true;
  if (/\brm\s+--recursive\b/.test(command)) return true;
  return false;
}

/** 检测 git push --force 模式 */
function hasForcePush(command: string): boolean {
  return /\bgit\s+push\b.*--force(?:-with-lease)?\b/.test(command) ||
    /\bgit\s+push\b.*-f\b/.test(command);
}

/** 检测 sudo 的使用 */
function hasSudo(command: string): boolean {
  return /(?:^|\s)sudo\s/.test(command);
}

/** 除去 Bash token 前后的引号 */
function normalizeGitToken(token: string): string {
  return token.replace(/^['"]|['"]$/g, "");
}

/** 检测 `--no-verify` / `--no-gpg-sign` 的使用 */
function hasDangerousGitBypassFlag(command: string): boolean {
  return /(?:^|\s)--no-verify(?:\s|$)/.test(command) ||
    /(?:^|\s)--no-gpg-sign(?:\s|$)/.test(command);
}

/** 检测对 protected branch 的 `git reset --hard` */
function hasProtectedBranchResetHard(command: string): boolean {
  const tokens = command.trim().split(/\s+/).map(normalizeGitToken);
  const resetIndex = tokens.indexOf("reset");
  if (resetIndex === -1) return false;
  if (!tokens.includes("--hard")) return false;

  const isProtectedBranchRef = (ref: string): boolean =>
    /^(?:origin\/|upstream\/)?(?:refs\/heads\/)?(?:main|master)(?:[~^]\d+)?$/.test(normalizeGitToken(ref));

  return tokens.slice(resetIndex + 1).some((token) => !token.startsWith("-") && isProtectedBranchRef(token));
}

/** 检测对 protected branch 的 direct push */
function hasDirectPushToProtectedBranch(command: string): boolean {
  if (!/\bgit\s+push\b/.test(command)) return false;

  const tokens = command.trim().split(/\s+/);
  const pushIndex = tokens.indexOf("push");
  if (pushIndex === -1) return false;

  const args = tokens.slice(pushIndex + 1).filter((token) => !token.startsWith("-"));
  if (args.length === 0) return false;

  const isProtectedBranchRef = (ref: string): boolean =>
    /^(?:origin\/|upstream\/)?(?:refs\/heads\/)?(?:main|master)(?:[~^]\d+)?$/.test(normalizeGitToken(ref));

  for (const arg of args) {
    if (isProtectedBranchRef(arg)) return true;

    const refspecParts = arg.split(":");
    if (refspecParts.length === 2 && typeof refspecParts[1] === "string" && isProtectedBranchRef(refspecParts[1])) {
      return true;
    }
  }

  return false;
}

/** 检测对重要文件的写入作为警告对象 */
function isProtectedReviewPath(filePath: string): boolean {
  const protected_patterns = [
    /(?:^|\/)package\.json$/,
    /(?:^|\/)Dockerfile$/,
    /(?:^|\/)docker-compose\.yml$/,
    /(?:^|\/)\.github\/workflows\/[^/]+$/,
    /(?:^|\/)schema\.prisma$/,
    /(?:^|\/)wrangler\.toml$/,
    /(?:^|\/)index\.html$/,
  ];
  return protected_patterns.some((p) => p.test(filePath));
}

// ============================================================
// 护栏规则表
// ============================================================

export const GUARD_RULES: readonly GuardRule[] = [
  // ------------------------------------------------------------------
  // R14-R18: 进化引擎安全规则
  // ------------------------------------------------------------------
  ...EVOLUTION_GUARD_RULES,

  // ------------------------------------------------------------------
  // R01: sudo 阻止（Bash）
  // ------------------------------------------------------------------
  {
    id: "R01:no-sudo",
    toolPattern: /^Bash$/,
    evaluate(ctx: RuleContext): HookResult | null {
      const command = ctx.input.tool_input["command"];
      if (typeof command !== "string") return null;
      if (!hasSudo(command)) return null;
      return {
        decision: "deny",
        reason: "禁止使用 sudo。如有需要，请请求用户手动执行。",
      };
    },
  },

  // ------------------------------------------------------------------
  // R02: 阻止写入受保护路径（Write / Edit / Bash）
  // ------------------------------------------------------------------
  {
    id: "R02:no-write-protected-paths",
    toolPattern: /^(?:Write|Edit|MultiEdit)$/,
    evaluate(ctx: RuleContext): HookResult | null {
      const filePath = ctx.input.tool_input["file_path"];
      if (typeof filePath !== "string") return null;
      if (!isProtectedPath(filePath)) return null;
      return {
        decision: "deny",
        reason: `禁止写入受保护的路径: ${filePath}`,
      };
    },
  },

  // ------------------------------------------------------------------
  // R03: 阻止通过 Bash 写入受保护路径（echo redirect / tee 等）
  // ------------------------------------------------------------------
  {
    id: "R03:no-bash-write-protected-paths",
    toolPattern: /^Bash$/,
    evaluate(ctx: RuleContext): HookResult | null {
      const command = ctx.input.tool_input["command"];
      if (typeof command !== "string") return null;
      // 检测 echo > .env、tee .git/config 等
      // 也检测 '>>' / '>' 后跟空格再接受保护路径的模式
      const writePatterns = [
        /(?:>>?|tee)\s+\S*\.env\b/,
        /(?:>>?|tee)\s+\S*\.env\./,
        /(?:>>?|tee)\s+\S*\.git\//,
        /(?:>>?|tee)\s+\S*id_rsa\b/,
        /(?:>>?|tee)\s+\S*id_ed25519\b/,
        /(?:>>?|tee)\s+\S*\.pem\b/,
        /(?:>>?|tee)\s+\S*\.key\b/,
      ];
      if (!writePatterns.some((p) => p.test(command))) return null;
      return {
        decision: "deny",
        reason: "禁止通过 shell 写入受保护的文件。",
      };
    },
  },

  // ------------------------------------------------------------------
  // R04: 确认写入项目外部（work 模式时跳过）
  // ------------------------------------------------------------------
  {
    id: "R04:confirm-write-outside-project",
    toolPattern: /^(?:Write|Edit|MultiEdit)$/,
    evaluate(ctx: RuleContext): HookResult | null {
      const filePath = ctx.input.tool_input["file_path"];
      if (typeof filePath !== "string") return null;
      // 相对路径视为项目内
      if (!filePath.startsWith("/")) return null;
      if (isUnderProjectRoot(filePath, ctx.projectRoot)) return null;
      // work 模式时跳过确认
      if (ctx.workMode) return null;
      return {
        decision: "ask",
        reason: `写入项目根目录外部: ${filePath}\n是否允许？`,
      };
    },
  },

  // ------------------------------------------------------------------
  // R05: rm -rf 确认（work 模式可绕过）
  // ------------------------------------------------------------------
  {
    id: "R05:confirm-rm-rf",
    toolPattern: /^Bash$/,
    evaluate(ctx: RuleContext): HookResult | null {
      const command = ctx.input.tool_input["command"];
      if (typeof command !== "string") return null;
      if (!hasDangerousRmRf(command)) return null;
      // work 模式且允许绕过时跳过
      if (ctx.workMode) return null;
      return {
        decision: "ask",
        reason: `检测到危险的删除命令:\n${command}\n是否执行？`,
      };
    },
  },

  // ------------------------------------------------------------------
  // R06: 阻止 git push --force（work 模式也无例外）
  // ------------------------------------------------------------------
  {
    id: "R06:no-force-push",
    toolPattern: /^Bash$/,
    evaluate(ctx: RuleContext): HookResult | null {
      const command = ctx.input.tool_input["command"];
      if (typeof command !== "string") return null;
      if (!hasForcePush(command)) return null;
      return {
        decision: "deny",
        reason: "禁止 git push --force。不允许破坏历史的操作。",
      };
    },
  },

  // ------------------------------------------------------------------
  // R07: Codex 模式时阻止 Write/Edit
  // Claude 担任 PM 角色 — 实现委托给 Codex Worker
  // ------------------------------------------------------------------
  {
    id: "R07:codex-mode-no-write",
    toolPattern: /^(?:Write|Edit|MultiEdit)$/,
    evaluate(ctx: RuleContext): HookResult | null {
      // 仅针对 Write / Edit / MultiEdit（排除 Bash）
      if (!["Write", "Edit", "MultiEdit"].includes(ctx.input.tool_name)) {
        return null;
      }
      if (!ctx.codexMode) return null;
      return {
        decision: "deny",
        reason: "Codex 模式中 Claude 不能直接写入文件。请将实现委托给 Codex Worker (codex exec)。",
      };
    },
  },

  // ------------------------------------------------------------------
  // R08: Breezing 角色护栏 — reviewer 不能执行 Write/Edit
  // ------------------------------------------------------------------
  {
    id: "R08:breezing-reviewer-no-write",
    toolPattern: /^(?:Write|Edit|MultiEdit|Bash)$/,
    evaluate(ctx: RuleContext): HookResult | null {
      if (ctx.breezingRole !== "reviewer") return null;
      // Bash 仅允许只读命令（由脚本端判断阻止）
      if (ctx.input.tool_name === "Bash") {
        const command = ctx.input.tool_input["command"];
        if (typeof command !== "string") return null;
        // 禁止 git commit / git push / rm / mv 等
        const prohibited = [
          /\bgit\s+(?:commit|push|reset|checkout|merge|rebase)\b/,
          /\brm\s+/,
          /\bmv\s+/,
          /\bcp\s+.*-r\b/,
        ];
        if (!prohibited.some((p) => p.test(command))) return null;
      }
      return {
        decision: "deny",
        reason: `Breezing reviewer 角色不能执行文件写入和数据变更命令。`,
      };
    },
  },

  // ------------------------------------------------------------------
  // R09: 限制访问包含敏感信息的文件（仅对 Read 发出警告）
  // ------------------------------------------------------------------
  {
    id: "R09:warn-secret-file-read",
    toolPattern: /^Read$/,
    evaluate(ctx: RuleContext): HookResult | null {
      const filePath = ctx.input.tool_input["file_path"];
      if (typeof filePath !== "string") return null;
      const secretPatterns = [/\.env$/, /id_rsa$/, /\.pem$/, /\.key$/, /secrets?\//];
      if (!secretPatterns.some((p) => p.test(filePath))) return null;
      return {
        decision: "approve",
        systemMessage: `警告: 正在读取可能包含敏感信息的文件: ${filePath}`,
      };
    },
  },

  // ------------------------------------------------------------------
  // R10: 阻止 Bash 中的 `--no-verify` / `--no-gpg-sign`
  // ------------------------------------------------------------------
  {
    id: "R10:no-git-bypass-flags",
    toolPattern: /^Bash$/,
    evaluate(ctx: RuleContext): HookResult | null {
      const command = ctx.input.tool_input["command"];
      if (typeof command !== "string") return null;
      if (!hasDangerousGitBypassFlag(command)) return null;
      return {
        decision: "deny",
        reason: "禁止使用 --no-verify / --no-gpg-sign。请不要绕过钩子和签名验证。",
      };
    },
  },

  // ------------------------------------------------------------------
  // R11: 阻止对 protected branch 的 `git reset --hard`
  // ------------------------------------------------------------------
  {
    id: "R11:no-reset-hard-protected-branch",
    toolPattern: /^Bash$/,
    evaluate(ctx: RuleContext): HookResult | null {
      const command = ctx.input.tool_input["command"];
      if (typeof command !== "string") return null;
      if (!hasProtectedBranchResetHard(command)) return null;
      return {
        decision: "deny",
        reason: "禁止对 protected branch 执行 git reset --hard。请使用不会破坏历史的方式。",
      };
    },
  },

  // ------------------------------------------------------------------
  // R12: 警告对 protected branch 的 direct push
  // ------------------------------------------------------------------
  {
    id: "R12:warn-direct-push-protected-branch",
    toolPattern: /^Bash$/,
    evaluate(ctx: RuleContext): HookResult | null {
      const command = ctx.input.tool_input["command"];
      if (typeof command !== "string") return null;
      if (!hasDirectPushToProtectedBranch(command)) return null;
      return {
        decision: "approve",
        systemMessage: "警告: 检测到直接 push 到 main/master。建议通过 feature branch 进行操作。",
      };
    },
  },

  // ------------------------------------------------------------------
  // R13: 重要文件变更警告（Write / Edit / MultiEdit）
  // ------------------------------------------------------------------
  {
    id: "R13:warn-protected-review-paths",
    toolPattern: /^(?:Write|Edit|MultiEdit)$/,
    evaluate(ctx: RuleContext): HookResult | null {
      const filePath = ctx.input.tool_input["file_path"];
      if (typeof filePath !== "string") return null;
      if (!isProtectedReviewPath(filePath)) return null;
      return {
        decision: "approve",
        systemMessage: `警告: 检测到对重要文件的变更: ${filePath}`,
      };
    },
  },
];

/**
 * 按顺序评估所有规则，返回第一个匹配规则的 HookResult。
 * 如果没有规则匹配，返回 approve。
 */
export function evaluateRules(ctx: RuleContext): HookResult {
  const toolName = ctx.input.tool_name;

  for (const rule of GUARD_RULES) {
    if (!rule.toolPattern.test(toolName)) continue;
    const result = rule.evaluate(ctx);
    if (result !== null) return result;
  }

  return { decision: "approve" };
}
