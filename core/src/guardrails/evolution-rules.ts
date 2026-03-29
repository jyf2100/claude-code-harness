/**
 * core/src/guardrails/evolution-rules.ts
 * 进化引擎安全规则 R14-R18
 *
 * 防止进化过程中的安全风险:
 * - 目录访问限制
 * - 内容安全扫描
 * - 进化速率限制
 * - 自动备份
 * - 反提示注入
 */

import type { GuardRule, HookResult, RuleContext } from "../types.js";

// ============================================================
// R14: 进化模式目录限制
// ============================================================

/** 进化过程中禁止读取的目录 */
const EVOLUTION_DENIED_PATHS = [
  /^\/etc\//,
  /^\/var\/(log|run|tmp)\//,
  /^\/Users\/[^/]+\/\.ssh\//,
  /^\/Users\/[^/]+\/\.aws\//,
  /^\/Users\/[^/]+\/\.gnupg\//,
  /^\/Users\/[^/]+\/\.config\/(gh|git-credentials)\//,
  /^\/home\/[^/]+\/\.ssh\//,
  /^\/home\/[^/]+\/\.aws\//,
  /\.ssh\//,
  /\.aws\/credentials/,
  /\.gnupg\//,
  /\/private\/(etc|tmp|var)\//,
];

function isEvolutionDeniedPath(filePath: string): boolean {
  return EVOLUTION_DENIED_PATHS.some((p) => p.test(filePath));
}

// ============================================================
// R15: SKILL.md 内容安全扫描
// ============================================================

interface ContentScanResult {
  safe: boolean;
  severity: "deny" | "ask" | "warn";
  matchedPattern: string;
}

/** 恶意内容模式 */
const MALICIOUS_CONTENT_PATTERNS: Array<{
  pattern: RegExp;
  severity: "deny" | "ask" | "warn";
  label: string;
}> = [
  // 代码执行注入
  { pattern: /eval\s*\(/, severity: "deny", label: "eval() 调用" },
  { pattern: /Function\s*\(/, severity: "deny", label: "Function 构造器" },
  { pattern: /child_process/, severity: "ask", label: "child_process 引用" },
  // 文件系统危险操作
  { pattern: /rm\s+-rf\s+\//, severity: "deny", label: "危险 rm -rf" },
  { pattern: /fs\.unlinkSync/, severity: "ask", label: "同步文件删除" },
  { pattern: /fs\.rmdirSync/, severity: "ask", label: "同步目录删除" },
  // 网络访问
  { pattern: /require\s*\(\s*['"]net['"]\s*\)/, severity: "ask", label: "net 模块加载" },
  { pattern: /require\s*\(\s*['"]http['"]\s*\)/, severity: "warn", label: "http 模块加载" },
  // 凭据相关
  { pattern: /password\s*=\s*['"]/, severity: "deny", label: "硬编码密码" },
  { pattern: /api[_-]?key\s*=\s*['"]/, severity: "deny", label: "硬编码 API key" },
  { pattern: /secret\s*=\s*['"]/, severity: "deny", label: "硬编码密钥" },
  // 环境操作
  { pattern: /process\.env\[/, severity: "warn", label: "动态环境变量访问" },
];

/**
 * 扫描内容是否包含恶意模式。
 * 仅用于进化引擎写入的 SKILL.md 内容。
 */
export function scanSkillContent(content: string): ContentScanResult | null {
  for (const { pattern, severity, label } of MALICIOUS_CONTENT_PATTERNS) {
    if (pattern.test(content)) {
      return { safe: false, severity, matchedPattern: label };
    }
  }
  return null;
}

// ============================================================
// R16: 进化速率限制
// ============================================================

/** 速率限制器（内存中） */
class EvolutionLimiter {
  private hourlyAttempts: number[] = [];
  private dailyAttempts: number[] = [];
  private lastAttemptTime: number = 0;

  constructor(
    private readonly maxPerHour: number = 10,
    private readonly maxPerDay: number = 50,
    private readonly minIntervalMs: number = 60_000,
  ) {}

  /** 检查是否允许进化操作 */
  canProceed(): { allowed: boolean; reason?: string } {
    const now = Date.now();

    // 最小间隔检查
    if (now - this.lastAttemptTime < this.minIntervalMs) {
      return {
        allowed: false,
        reason: `进化操作间隔过短（最小 ${this.minIntervalMs / 1000} 秒）`,
      };
    }

    // 清理过期记录
    const oneHourAgo = now - 3600_000;
    const oneDayAgo = now - 86400_000;
    this.hourlyAttempts = this.hourlyAttempts.filter((t) => t > oneHourAgo);
    this.dailyAttempts = this.dailyAttempts.filter((t) => t > oneDayAgo);

    // 小时限制
    if (this.hourlyAttempts.length >= this.maxPerHour) {
      return {
        allowed: false,
        reason: `每小时进化操作次数已达上限（${this.maxPerHour} 次）`,
      };
    }

    // 日限制
    if (this.dailyAttempts.length >= this.maxPerDay) {
      return {
        allowed: false,
        reason: `每日进化操作次数已达上限（${this.maxPerDay} 次）`,
      };
    }

    return { allowed: true };
  }

  /** 记录一次进化操作 */
  record(): void {
    const now = Date.now();
    this.lastAttemptTime = now;
    this.hourlyAttempts.push(now);
    this.dailyAttempts.push(now);
  }
}

/** 全局速率限制器实例 */
export const evolutionLimiter = new EvolutionLimiter();

// ============================================================
// R18: 反提示注入
// ============================================================

/** 提示注入检测模式 */
const PROMPT_INJECTION_PATTERNS: Array<{
  pattern: RegExp;
  label: string;
}> = [
  // 角色切换
  { pattern: /ignore\s+(all\s+)?previous\s+(instructions|rules|guidelines)/i, label: "指令忽略模式" },
  { pattern: /you\s+are\s+now\s+/i, label: "角色切换模式" },
  { pattern: /pretend\s+(to\s+be|you('re| are))/i, label: "伪装模式" },
  // 系统指令注入
  { pattern: /system\s*:\s*/i, label: "系统指令伪装" },
  { pattern: /\[system\]/i, label: "系统标签伪装" },
  { pattern: /\<\|im_start\|\>/i, label: "ChatML 分隔符注入" },
  // 指令覆盖
  { pattern: / OVERRIDE /i, label: "指令覆盖" },
  { pattern: /BYPASS\s+(ALL\s+)?SAFETY/i, label: "安全绕过" },
  { pattern: /DO\s+NOT\s+(FOLLOW|OBEY|COMPLY)/i, label: "指令不遵守" },
  // 分隔符注入
  { pattern: /={10,}/, label: "分隔符注入" },
  { pattern: /-{10,}/, label: "分隔符注入" },
];

/**
 * 检测内容中的提示注入模式。
 * 用于扫描进化生成的 SKILL.md 内容。
 */
export function detectPromptInjection(content: string): string[] {
  const detected: string[] = [];
  for (const { pattern, label } of PROMPT_INJECTION_PATTERNS) {
    if (pattern.test(content)) {
      detected.push(label);
    }
  }
  return detected;
}

// ============================================================
// 护栏规则 R14-R18
// ============================================================

export const EVOLUTION_GUARD_RULES: readonly GuardRule[] = [
  // ------------------------------------------------------------------
  // R14: 进化模式目录限制 — 阻止读取敏感路径
  // ------------------------------------------------------------------
  {
    id: "R14:evolution-dir-restriction",
    toolPattern: /^Read$/,
    evaluate(ctx: RuleContext): HookResult | null {
      const filePath = ctx.input.tool_input["file_path"];
      if (typeof filePath !== "string") return null;
      if (!isEvolutionDeniedPath(filePath)) return null;
      return {
        decision: "deny",
        reason: `进化模式禁止读取敏感路径: ${filePath}`,
      };
    },
  },

  // ------------------------------------------------------------------
  // R15: SKILL.md 内容安全 — Write/Edit 时扫描
  // 仅当目标是 skills/ 目录下的文件时触发
  // ------------------------------------------------------------------
  {
    id: "R15:evolution-content-safety",
    toolPattern: /^(?:Write|Edit)$/,
    evaluate(ctx: RuleContext): HookResult | null {
      const filePath = ctx.input.tool_input["file_path"] as string | undefined;
      if (typeof filePath !== "string") return null;

      // 仅扫描 skills/ 目录下的文件
      if (!/skills\/.*\/SKILL\.md$/.test(filePath)) return null;

      const content = ctx.input.tool_input["content"] as string | undefined
        ?? ctx.input.tool_input["new_string"] as string | undefined;
      if (typeof content !== "string") return null;

      const scanResult = scanSkillContent(content);
      if (scanResult === null) return null;

      if (scanResult.severity === "deny") {
        return {
          decision: "deny",
          reason: `进化内容安全扫描发现禁止内容: ${scanResult.matchedPattern}`,
        };
      }

      if (scanResult.severity === "ask") {
        return {
          decision: "ask",
          reason: `进化内容安全扫描发现可疑内容: ${scanResult.matchedPattern}`,
        };
      }

      // warn: 允许但附加警告
      return {
        decision: "approve",
        systemMessage: `进化内容安全扫描警告: ${scanResult.matchedPattern}`,
      };
    },
  },

  // ------------------------------------------------------------------
  // R18: 反提示注入 — Write 时扫描 skills/ 目录
  // ------------------------------------------------------------------
  {
    id: "R18:evolution-anti-injection",
    toolPattern: /^Write$/,
    evaluate(ctx: RuleContext): HookResult | null {
      const filePath = ctx.input.tool_input["file_path"];
      if (typeof filePath !== "string") return null;
      if (!/skills\/.*\/SKILL\.md$/.test(filePath)) return null;

      const content = ctx.input.tool_input["content"];
      if (typeof content !== "string") return null;

      const detected = detectPromptInjection(content);
      if (detected.length === 0) return null;

      return {
        decision: "deny",
        reason: `检测到提示注入模式: ${detected.join(", ")}`,
      };
    },
  },
];
