/**
 * core/src/guardrails/tampering.ts
 * 测试篡改检测引擎
 *
 * 将 posttooluse-tampering-detector.sh 的全部模式移植到 TypeScript。
 * 在 Write / Edit / MultiEdit 工具修改测试文件或 CI 配置后，
 * 检测篡改模式并返回警告（不阻止）。
 */

import type { HookInput, HookResult } from "../types.js";

// ============================================================
// 文件类型判定
// ============================================================

const TEST_FILE_PATTERNS = [
  /\.test\.[jt]sx?$/,
  /\.spec\.[jt]sx?$/,
  /\.test\.py$/,
  /test_[^/]+\.py$/,
  /[^/]+_test\.py$/,
  /\.test\.go$/,
  /[^/]+_test\.go$/,
  /\/__tests__\//,
  /\/tests\//,
] as const;

const CONFIG_FILE_PATTERNS = [
  /(?:^|\/)\.eslintrc(?:\.[^/]+)?$/,
  /(?:^|\/)eslint\.config\.[^/]+$/,
  /(?:^|\/)\.prettierrc(?:\.[^/]+)?$/,
  /(?:^|\/)prettier\.config\.[^/]+$/,
  /(?:^|\/)tsconfig(?:\.[^/]+)?\.json$/,
  /(?:^|\/)biome\.json$/,
  /(?:^|\/)\.stylelintrc(?:\.[^/]+)?$/,
  /(?:^|\/)(?:jest|vitest)\.config\.[^/]+$/,
  /\.github\/workflows\/[^/]+\.ya?ml$/,
  /(?:^|\/)\.gitlab-ci\.ya?ml$/,
  /(?:^|\/)Jenkinsfile$/,
] as const;

function isTestFile(filePath: string): boolean {
  return TEST_FILE_PATTERNS.some((p) => p.test(filePath));
}

function isConfigFile(filePath: string): boolean {
  return CONFIG_FILE_PATTERNS.some((p) => p.test(filePath));
}

// ============================================================
// 篡改模式定义
// ============================================================

interface TamperingPattern {
  id: string;
  description: string;
  /** 要匹配的文本范围的模式 */
  pattern: RegExp;
  /** 仅应用于测试文件（false = 也应用于配置文件） */
  testFileOnly: boolean;
}

const TAMPERING_PATTERNS: readonly TamperingPattern[] = [
  // --- 测试跳过 ---
  {
    id: "T01:it-skip",
    description: "通过 it.skip / describe.skip 跳过测试",
    pattern: /(?:it|test|describe|context)\.skip\s*\(/,
    testFileOnly: true,
  },
  {
    id: "T02:xit-xdescribe",
    description: "通过 xit / xdescribe 禁用测试",
    pattern: /\b(?:xit|xtest|xdescribe)\s*\(/,
    testFileOnly: true,
  },
  {
    id: "T03:pytest-skip",
    description: "通过 pytest.mark.skip 跳过测试",
    pattern: /@pytest\.mark\.(?:skip|xfail)\b/,
    testFileOnly: true,
  },
  {
    id: "T04:go-skip",
    description: "通过 t.Skip() 跳过测试",
    pattern: /\bt\.Skip(?:f|Now)?\s*\(/,
    testFileOnly: true,
  },

  // --- 断言删除/篡改 ---
  {
    id: "T05:expect-removed",
    description: "expect / assert 可能被删除（被注释掉）",
    pattern: /\/\/\s*expect\s*\(/,
    testFileOnly: true,
  },
  {
    id: "T06:assert-commented",
    description: "assert 调用被注释掉",
    pattern: /\/\/\s*assert(?:Equal|NotEqual|True|False|Nil|Error)?\s*\(/,
    testFileOnly: true,
  },
  {
    id: "T07:todo-assert",
    description: "断言被 TODO 注释替换",
    pattern: /\/\/\s*TODO.*assert|\/\/\s*TODO.*expect/i,
    testFileOnly: true,
  },

  // --- ESLint 禁用（测试/CI 配置） ---
  {
    id: "T08:eslint-disable",
    description: "通过 eslint-disable 禁用 lint 规则",
    // 对应 // eslint-disable 和 /* eslint-disable */ 两种形式
    pattern: /(?:\/\/\s*eslint-disable(?:-next-line|-line)?(?:\s+[^\n]+)?$|\/\*\s*eslint-disable\b[^*]*\*\/)/m,
    testFileOnly: false,
  },

  // --- CI 工作流篡改 ---
  {
    id: "T09:ci-continue-on-error",
    description: "通过 continue-on-error: true 忽略 CI 失败",
    pattern: /continue-on-error\s*:\s*true/,
    testFileOnly: false,
  },
  {
    id: "T10:ci-if-always",
    description: "通过 if: always() 强制执行 CI 步骤",
    pattern: /if\s*:\s*always\s*\(\s*\)/,
    testFileOnly: false,
  },

  // --- 硬编码期望值 ---
  {
    id: "T11:hardcoded-answer",
    description: "测试期望值的硬编码（返回字典）",
    pattern: /answers?_for_tests?\s*=\s*\{/,
    testFileOnly: true,
  },
  {
    id: "T12:return-hardcoded",
    description: "直接 return 测试用例值的模式",
    pattern:
      /return\s+(?:"[^"]*"|'[^']*'|\d+)\s*;\s*\/\/.*(?:test|spec|expect)/i,
    testFileOnly: true,
  },
];

// ============================================================
// 检测函数
// ============================================================

interface TamperingWarning {
  patternId: string;
  description: string;
  matchedText: string;
}

/**
 * 对文本（new_string 或 content）搜索篡改模式。
 */
function detectTampering(
  text: string,
  isTest: boolean
): TamperingWarning[] {
  const warnings: TamperingWarning[] = [];

  for (const p of TAMPERING_PATTERNS) {
    if (p.testFileOnly && !isTest) continue;

    const match = p.pattern.exec(text);
    if (match !== null) {
      warnings.push({
        patternId: p.id,
        description: p.description,
        matchedText: match[0].slice(0, 120),
      });
    }
  }

  return warnings;
}

/**
 * 从 HookInput 提取文件路径和变更文本。
 */
function extractTargets(
  input: HookInput
): { filePath: string; changedText: string } | null {
  const toolInput = input.tool_input;
  const filePath = toolInput["file_path"];
  if (typeof filePath !== "string" || filePath.length === 0) return null;

  // Write: content 字段
  // Edit: new_string 字段
  const changedText =
    typeof toolInput["content"] === "string"
      ? toolInput["content"]
      : typeof toolInput["new_string"] === "string"
        ? toolInput["new_string"]
        : null;

  if (changedText === null) return null;

  return { filePath, changedText };
}

// ============================================================
// 导出: PostToolUse 入口点
// ============================================================

/**
 * PostToolUse 钩子中检测测试篡改并返回警告。
 * 即使检测到篡改，decision 仍为 "approve"（不阻止）。
 * 警告作为 systemMessage 传递给 Claude。
 */
export function detectTestTampering(input: HookInput): HookResult {
  // 仅针对 Write / Edit / MultiEdit
  if (!["Write", "Edit", "MultiEdit"].includes(input.tool_name)) {
    return { decision: "approve" };
  }

  const targets = extractTargets(input);
  if (targets === null) return { decision: "approve" };

  const { filePath, changedText } = targets;
  const isTest = isTestFile(filePath);
  const isConfig = isConfigFile(filePath);

  if (!isTest && !isConfig) return { decision: "approve" };

  const warnings = detectTampering(changedText, isTest);

  if (warnings.length === 0) return { decision: "approve" };

  const fileType = isTest ? "测试文件" : "CI/配置文件";
  const warningLines = warnings
    .map((w) => `- [${w.patternId}] ${w.description}\n  检测位置: ${w.matchedText}`)
    .join("\n");

  const systemMessage =
    `[Harness v3] 测试篡改检测警告\n\n` +
    `在 ${fileType} \`${filePath}\` 中检测到可疑模式:\n\n` +
    warningLines +
    `\n\n【请确认】\n` +
    `请确认此更改并非故意禁用测试或降低实现质量。\n` +
    `如果判定为篡改，请撤销更改。`;

  return {
    decision: "approve",
    systemMessage,
  };
}
