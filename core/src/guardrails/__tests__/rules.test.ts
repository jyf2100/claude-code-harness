/**
 * core/src/guardrails/__tests__/rules.test.ts
 * GUARD_RULES 声明式护栏规则表的单元测试
 *
 * 验证 pretooluse-guard.sh 的各规则已正确移植到 TypeScript。
 * 覆盖率目标: 90%+
 */

import { describe, it, expect } from "vitest";
import { GUARD_RULES, evaluateRules } from "../rules.js";
import type { RuleContext, HookInput } from "../../types.js";

// ============================================================
// 测试辅助函数
// ============================================================

function makeCtx(
  toolName: string,
  toolInput: Record<string, unknown> = {},
  overrides: Partial<Omit<RuleContext, "input">> = {}
): RuleContext {
  const input: HookInput = { tool_name: toolName, tool_input: toolInput };
  return {
    input,
    projectRoot: "/project",
    workMode: false,
    codexMode: false,
    breezingRole: null,
    ...overrides,
  };
}

// ============================================================
// R01: sudo 阻止
// ============================================================
describe("R01: sudo 阻止", () => {
  it("阻止 sudo rm -rf /", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "sudo rm -rf /" })
    );
    expect(result.decision).toBe("deny");
  });

  it("阻止 sudo apt-get install", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "sudo apt-get install vim" })
    );
    expect(result.decision).toBe("deny");
  });

  it("不阻止非 sudo-prefix 的普通命令", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "nosudo echo test" })
    );
    expect(result.decision).toBe("approve");
  });

  it("不阻止不包含 sudo 的 Bash", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "ls -la" })
    );
    expect(result.decision).toBe("approve");
  });

  it("不适用于 Write 工具", () => {
    // R01 仅针对 Bash
    const rule = GUARD_RULES.find((r) => r.id === "R01:no-sudo")!;
    const result = rule.evaluate(
      makeCtx("Write", { file_path: "/project/sudo.ts" })
    );
    expect(result).toBeNull();
  });
});

// ============================================================
// R02: 保护路径写入阻止
// ============================================================
describe("R02: 保护路径写入阻止", () => {
  const protectedPaths = [
    ".git/config",
    "/project/.git/HEAD",
    ".env",
    "/project/.env",
    "/home/user/.env.local",
    "credentials.pem",
    "private.key",
    "id_rsa",
    "id_ed25519",
    "/home/user/.ssh/id_ecdsa",
  ];

  for (const path of protectedPaths) {
    it(`阻止写入 ${path}`, () => {
      const result = evaluateRules(
        makeCtx("Write", { file_path: path })
      );
      expect(result.decision).toBe("deny");
    });

    it(`阻止编辑 ${path}`, () => {
      const result = evaluateRules(
        makeCtx("Edit", { file_path: path })
      );
      expect(result.decision).toBe("deny");
    });
  }

  it("不阻止写入普通源文件", () => {
    const result = evaluateRules(
      makeCtx("Write", { file_path: "/project/src/index.ts" })
    );
    expect(result.decision).toBe("approve");
  });

  it("R02 不适用于 Bash 工具", () => {
    const rule = GUARD_RULES.find((r) => r.id === "R02:no-write-protected-paths")!;
    const result = rule.evaluate(
      makeCtx("Bash", { command: "echo hello > .env" })
    );
    expect(result).toBeNull();
  });
});

// ============================================================
// R03: Bash 中保护路径的 shell 写入阻止
// ============================================================
describe("R03: Bash 中保护路径的 shell 写入阻止", () => {
  const dangerousBashCmds = [
    'echo "SECRET=foo" > .env',
    'echo "key" > .env.local',
    "cat token.txt > .git/config",
    "tee .git/hooks/pre-commit",
    "cat private.key > backup.key",
  ];

  for (const cmd of dangerousBashCmds) {
    it(`阻止 ${cmd}`, () => {
      const result = evaluateRules(makeCtx("Bash", { command: cmd }));
      expect(result.decision).toBe("deny");
    });
  }

  it("不阻止安全的 Bash 命令", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "echo hello" })
    );
    expect(result.decision).toBe("approve");
  });
});

// ============================================================
// R04: 项目外写入确认
// ============================================================
describe("R04: 项目外写入确认", () => {
  it("写入项目外的绝对路径返回 ask", () => {
    const result = evaluateRules(
      makeCtx("Write", { file_path: "/tmp/output.txt" }, { projectRoot: "/project" })
    );
    expect(result.decision).toBe("ask");
  });

  it("编辑项目外的绝对路径返回 ask", () => {
    const result = evaluateRules(
      makeCtx("Edit", { file_path: "/home/user/outside.ts" }, { projectRoot: "/project" })
    );
    expect(result.decision).toBe("ask");
  });

  it("项目内的绝对路径不返回 ask", () => {
    const result = evaluateRules(
      makeCtx(
        "Write",
        { file_path: "/project/src/foo.ts" },
        { projectRoot: "/project" }
      )
    );
    expect(result.decision).toBe("approve");
  });

  it("相对路径视为项目内", () => {
    const result = evaluateRules(
      makeCtx("Write", { file_path: "src/foo.ts" })
    );
    expect(result.decision).toBe("approve");
  });

  it("work 模式下不确认项目外写入", () => {
    const result = evaluateRules(
      makeCtx(
        "Write",
        { file_path: "/tmp/output.txt" },
        { workMode: true, projectRoot: "/project" }
      )
    );
    // R04 在 workMode 时跳过 → 后续规则 approve
    expect(result.decision).toBe("approve");
  });
});

// ============================================================
// R05: rm -rf 确认
// ============================================================
describe("R05: rm -rf 确认", () => {
  const rmRfCmds = [
    "rm -rf /tmp/work",
    "rm -fr /tmp/work",
    "rm --recursive /tmp/work",
    "rm -rf ~/Downloads/old",
  ];

  for (const cmd of rmRfCmds) {
    it(`${cmd} 返回 ask`, () => {
      const result = evaluateRules(makeCtx("Bash", { command: cmd }));
      expect(result.decision).toBe("ask");
    });
  }

  it("work 模式下不确认 rm -rf", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "rm -rf /tmp/work" }, { workMode: true })
    );
    // R05 在 workMode 跳过 → 到 R06（无匹配所以 approve）
    expect(result.decision).toBe("approve");
  });

  it("不阻止普通 rm -f", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "rm -f /tmp/test.log" })
    );
    expect(result.decision).toBe("approve");
  });
});

// ============================================================
// R06: git push --force 阻止
// ============================================================
describe("R06: git push --force 阻止", () => {
  const forcePushCmds = [
    "git push --force",
    "git push --force-with-lease",
    "git push origin main --force",
    "git push -f",
    "git push origin main -f",
  ];

  for (const cmd of forcePushCmds) {
    it(`阻止 ${cmd}`, () => {
      const result = evaluateRules(makeCtx("Bash", { command: cmd }));
      expect(result.decision).toBe("deny");
    });
  }

  it("不阻止普通 git push", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "git push origin feature/login" })
    );
    expect(result.decision).toBe("approve");
  });

  it("work 模式下也阻止 force push（无例外）", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "git push --force" }, { workMode: true })
    );
    expect(result.decision).toBe("deny");
  });
});

// ============================================================
// R10: Git bypass 标志阻止
// ============================================================
describe("R10: Git bypass 标志阻止", () => {
  it("阻止 --no-verify", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "git commit --no-verify -m 'test'" })
    );
    expect(result.decision).toBe("deny");
  });

  it("阻止 --no-gpg-sign", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "git commit --no-gpg-sign -m 'test'" })
    );
    expect(result.decision).toBe("deny");
  });
});

// ============================================================
// R11: protected branch 的 git reset --hard 阻止
// ============================================================
describe("R11: protected branch 的 git reset --hard 阻止", () => {
  const dangerousResetCmds = [
    "git reset --hard main",
    "git reset --hard master",
    "git reset --hard origin/main",
  ];

  for (const cmd of dangerousResetCmds) {
    it(`阻止 ${cmd}`, () => {
      const result = evaluateRules(makeCtx("Bash", { command: cmd }));
      expect(result.decision).toBe("deny");
    });
  }
});

// ============================================================
// R12: protected branch 的 direct push 警告
// ============================================================
describe("R12: protected branch 的 direct push 警告", () => {
  it("git push origin main 返回 approve + systemMessage", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "git push origin main" })
    );
    expect(result.decision).toBe("approve");
    expect(result.systemMessage).toBeTruthy();
    expect(result.systemMessage).toContain("main");
  });

  it("git push upstream master 返回 approve + systemMessage", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "git push upstream master" })
    );
    expect(result.decision).toBe("approve");
    expect(result.systemMessage).toBeTruthy();
    expect(result.systemMessage).toContain("master");
  });
});

// ============================================================
// R13: 重要文件变更警告
// ============================================================
describe("R13: 重要文件变更警告", () => {
  const protectedPaths = [
    "package.json",
    "Dockerfile",
    "docker-compose.yml",
    ".github/workflows/ci.yml",
    "schema.prisma",
    "wrangler.toml",
    "index.html",
  ];

  for (const path of protectedPaths) {
    it(`${path} 的 Write 返回 approve + systemMessage`, () => {
      const result = evaluateRules(
        makeCtx("Write", { file_path: path })
      );
      expect(result.decision).toBe("approve");
      expect(result.systemMessage).toBeTruthy();
      expect(result.systemMessage).toContain(path);
    });
  }

  it("不警告普通源文件变更", () => {
    const result = evaluateRules(
      makeCtx("Write", { file_path: "src/index.ts" })
    );
    expect(result.decision).toBe("approve");
    expect(result.systemMessage).toBeUndefined();
  });
});

// ============================================================
// R07: Codex 模式下的 Write/Edit 阻止
// ============================================================
describe("R07: Codex 模式下的 Write/Edit 阻止", () => {
  it("阻止 Codex 模式下的 Write", () => {
    const result = evaluateRules(
      makeCtx("Write", { file_path: "/project/src/foo.ts" }, { codexMode: true })
    );
    expect(result.decision).toBe("deny");
  });

  it("阻止 Codex 模式下的 Edit", () => {
    const result = evaluateRules(
      makeCtx("Edit", { file_path: "/project/src/foo.ts" }, { codexMode: true })
    );
    expect(result.decision).toBe("deny");
  });

  it("普通模式下不阻止 Write", () => {
    const result = evaluateRules(
      makeCtx("Write", { file_path: "/project/src/foo.ts" }, { codexMode: false })
    );
    expect(result.decision).toBe("approve");
  });

  it("不阻止 Codex 模式下的 Bash（R07 的 toolPattern 只有 Write/Edit）", () => {
    // R07 的 toolPattern 只有 /^(?:Write|Edit|MultiEdit)$/
    // evaluateRules 检查 toolPattern 所以 Bash 不匹配 R07
    const result = evaluateRules(
      makeCtx("Bash", { command: "ls" }, { codexMode: true })
    );
    expect(result.decision).toBe("approve");
  });
});

// ============================================================
// R08: Breezing reviewer 角色守护
// ============================================================
describe("R08: Breezing reviewer 角色守护", () => {
  it("阻止 reviewer 角色的 Write", () => {
    const result = evaluateRules(
      makeCtx("Write", { file_path: "/project/src/foo.ts" }, { breezingRole: "reviewer" })
    );
    expect(result.decision).toBe("deny");
  });

  it("阻止 reviewer 角色的 Edit", () => {
    const result = evaluateRules(
      makeCtx("Edit", { file_path: "/project/src/foo.ts" }, { breezingRole: "reviewer" })
    );
    expect(result.decision).toBe("deny");
  });

  it("阻止 reviewer 角色的 git commit", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "git commit -m 'test'" }, { breezingRole: "reviewer" })
    );
    expect(result.decision).toBe("deny");
  });

  it("阻止 reviewer 角色的 git push", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "git push origin main" }, { breezingRole: "reviewer" })
    );
    expect(result.decision).toBe("deny");
  });

  it("不阻止 reviewer 角色的 ls（read-only 命令）", () => {
    const rule = GUARD_RULES.find((r) => r.id === "R08:breezing-reviewer-no-write")!;
    const result = rule.evaluate(
      makeCtx("Bash", { command: "ls -la" }, { breezingRole: "reviewer" })
    );
    // 不匹配 prohibited 模式所以返回 null
    expect(result).toBeNull();
  });

  it("非 reviewer 角色时不阻止", () => {
    const result = evaluateRules(
      makeCtx("Write", { file_path: "/project/src/foo.ts" }, { breezingRole: "implementer" })
    );
    expect(result.decision).toBe("approve");
  });

  it("无角色时不阻止", () => {
    const result = evaluateRules(
      makeCtx("Write", { file_path: "/project/src/foo.ts" }, { breezingRole: null })
    );
    expect(result.decision).toBe("approve");
  });
});

// ============================================================
// R09: 敏感文件 Read 警告（approve + systemMessage）
// ============================================================
describe("R09: 敏感文件 Read 警告", () => {
  const secretPaths = [
    ".env",
    "id_rsa",
    "private.pem",
    "server.key",
    "secrets/api.json",
  ];

  for (const path of secretPaths) {
    it(`${path} 的 Read 返回 approve + systemMessage`, () => {
      const result = evaluateRules(
        makeCtx("Read", { file_path: path })
      );
      expect(result.decision).toBe("approve");
      expect(result.systemMessage).toBeDefined();
      expect(result.systemMessage).toContain(path);
    });
  }

  it("普通源文件的 Read 无警告", () => {
    const result = evaluateRules(
      makeCtx("Read", { file_path: "src/index.ts" })
    );
    expect(result.decision).toBe("approve");
    expect(result.systemMessage).toBeUndefined();
  });
});

// ============================================================
// evaluateRules: 集成测试
// ============================================================
describe("evaluateRules: 集成测试", () => {
  it("tool_input.command 不是字符串时跳过规则", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: 12345 })
    );
    expect(result.decision).toBe("approve");
  });

  it("不匹配任何规则时返回 approve", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "echo hello" })
    );
    expect(result.decision).toBe("approve");
  });

  it("Codex MCP 工具不应用 Bash 规则", () => {
    // mcp__codex__* 不在 GUARD_RULES 中（rules.ts 不处理）
    // 在 index.ts 中单独阻止
    const result = evaluateRules(
      makeCtx("mcp__codex__exec", { input: "ls" })
    );
    expect(result.decision).toBe("approve");
  });

  it("R01 和 R05 同时匹配时优先 R01（sudo）", () => {
    // sudo + rm -rf 的命令 → R01 先匹配
    const result = evaluateRules(
      makeCtx("Bash", { command: "sudo rm -rf /" })
    );
    expect(result.decision).toBe("deny");
    // deny 时包含 R01 的说明
    expect(result.reason).toContain("sudo");
  });
});
