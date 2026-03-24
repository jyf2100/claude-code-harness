/**
 * core/src/guardrails/__tests__/rules.test.ts
 * GUARD_RULES 宣言的ガードルールテーブルの単体テスト
 *
 * pretooluse-guard.sh の各ルールが正しく TypeScript に移植されていることを検証。
 * カバレッジ目標: 90%+
 */

import { describe, it, expect } from "vitest";
import { GUARD_RULES, evaluateRules } from "../rules.js";
import type { RuleContext, HookInput } from "../../types.js";

// ============================================================
// テストヘルパー
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
// R01: sudo ブロック
// ============================================================
describe("R01: sudo ブロック", () => {
  it("sudo rm -rf / をブロックする", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "sudo rm -rf /" })
    );
    expect(result.decision).toBe("deny");
  });

  it("sudo apt-get install をブロックする", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "sudo apt-get install vim" })
    );
    expect(result.decision).toBe("deny");
  });

  it("sudo-prefix でない通常コマンドはブロックしない", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "nosudo echo test" })
    );
    expect(result.decision).toBe("approve");
  });

  it("sudo を含まない Bash はブロックしない", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "ls -la" })
    );
    expect(result.decision).toBe("approve");
  });

  it("Write ツールには適用されない", () => {
    // R01 は Bash のみ対象
    const rule = GUARD_RULES.find((r) => r.id === "R01:no-sudo")!;
    const result = rule.evaluate(
      makeCtx("Write", { file_path: "/project/sudo.ts" })
    );
    expect(result).toBeNull();
  });
});

// ============================================================
// R02: 保護パスへの書き込みブロック
// ============================================================
describe("R02: 保護パスへの書き込みブロック", () => {
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
    it(`${path} への Write をブロックする`, () => {
      const result = evaluateRules(
        makeCtx("Write", { file_path: path })
      );
      expect(result.decision).toBe("deny");
    });

    it(`${path} への Edit をブロックする`, () => {
      const result = evaluateRules(
        makeCtx("Edit", { file_path: path })
      );
      expect(result.decision).toBe("deny");
    });
  }

  it("通常のソースファイルへの Write はブロックしない", () => {
    const result = evaluateRules(
      makeCtx("Write", { file_path: "/project/src/index.ts" })
    );
    expect(result.decision).toBe("approve");
  });

  it("Bash ツールには R02 は適用されない", () => {
    const rule = GUARD_RULES.find((r) => r.id === "R02:no-write-protected-paths")!;
    const result = rule.evaluate(
      makeCtx("Bash", { command: "echo hello > .env" })
    );
    expect(result).toBeNull();
  });
});

// ============================================================
// R03: Bash での保護パスへのシェル書き込みブロック
// ============================================================
describe("R03: Bash での保護パスへのシェル書き込みブロック", () => {
  const dangerousBashCmds = [
    'echo "SECRET=foo" > .env',
    'echo "key" > .env.local',
    "cat token.txt > .git/config",
    "tee .git/hooks/pre-commit",
    "cat private.key > backup.key",
  ];

  for (const cmd of dangerousBashCmds) {
    it(`${cmd} をブロックする`, () => {
      const result = evaluateRules(makeCtx("Bash", { command: cmd }));
      expect(result.decision).toBe("deny");
    });
  }

  it("安全な Bash コマンドはブロックしない", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "echo hello" })
    );
    expect(result.decision).toBe("approve");
  });
});

// ============================================================
// R04: プロジェクト外への書き込み確認
// ============================================================
describe("R04: プロジェクト外への書き込み確認", () => {
  it("プロジェクト外の絶対パスへの Write は ask を返す", () => {
    const result = evaluateRules(
      makeCtx("Write", { file_path: "/tmp/output.txt" }, { projectRoot: "/project" })
    );
    expect(result.decision).toBe("ask");
  });

  it("プロジェクト外の絶対パスへの Edit は ask を返す", () => {
    const result = evaluateRules(
      makeCtx("Edit", { file_path: "/home/user/outside.ts" }, { projectRoot: "/project" })
    );
    expect(result.decision).toBe("ask");
  });

  it("プロジェクト内の絶対パスは ask を返さない", () => {
    const result = evaluateRules(
      makeCtx(
        "Write",
        { file_path: "/project/src/foo.ts" },
        { projectRoot: "/project" }
      )
    );
    expect(result.decision).toBe("approve");
  });

  it("相対パスはプロジェクト内とみなす", () => {
    const result = evaluateRules(
      makeCtx("Write", { file_path: "src/foo.ts" })
    );
    expect(result.decision).toBe("approve");
  });

  it("work モード時はプロジェクト外への書き込みを確認しない", () => {
    const result = evaluateRules(
      makeCtx(
        "Write",
        { file_path: "/tmp/output.txt" },
        { workMode: true, projectRoot: "/project" }
      )
    );
    // R04 は workMode 時にスキップ → 後続ルールで approve
    expect(result.decision).toBe("approve");
  });
});

// ============================================================
// R05: rm -rf 確認
// ============================================================
describe("R05: rm -rf 確認", () => {
  const rmRfCmds = [
    "rm -rf /tmp/work",
    "rm -fr /tmp/work",
    "rm --recursive /tmp/work",
    "rm -rf ~/Downloads/old",
  ];

  for (const cmd of rmRfCmds) {
    it(`${cmd} は ask を返す`, () => {
      const result = evaluateRules(makeCtx("Bash", { command: cmd }));
      expect(result.decision).toBe("ask");
    });
  }

  it("work モード時は rm -rf を確認しない", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "rm -rf /tmp/work" }, { workMode: true })
    );
    // R05 は workMode でスキップ → R06 へ（該当なしなので approve）
    expect(result.decision).toBe("approve");
  });

  it("通常の rm -f はブロックしない", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "rm -f /tmp/test.log" })
    );
    expect(result.decision).toBe("approve");
  });
});

// ============================================================
// R06: git push --force ブロック
// ============================================================
describe("R06: git push --force ブロック", () => {
  const forcePushCmds = [
    "git push --force",
    "git push --force-with-lease",
    "git push origin main --force",
    "git push -f",
    "git push origin main -f",
  ];

  for (const cmd of forcePushCmds) {
    it(`${cmd} をブロックする`, () => {
      const result = evaluateRules(makeCtx("Bash", { command: cmd }));
      expect(result.decision).toBe("deny");
    });
  }

  it("通常の git push はブロックしない", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "git push origin feature/login" })
    );
    expect(result.decision).toBe("approve");
  });

  it("work モード時も force push はブロックする（例外なし）", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "git push --force" }, { workMode: true })
    );
    expect(result.decision).toBe("deny");
  });
});

// ============================================================
// R10: Git bypass flags ブロック
// ============================================================
describe("R10: Git bypass flags ブロック", () => {
  it("--no-verify をブロックする", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "git commit --no-verify -m 'test'" })
    );
    expect(result.decision).toBe("deny");
  });

  it("--no-gpg-sign をブロックする", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "git commit --no-gpg-sign -m 'test'" })
    );
    expect(result.decision).toBe("deny");
  });
});

// ============================================================
// R11: protected branch への git reset --hard ブロック
// ============================================================
describe("R11: protected branch への git reset --hard ブロック", () => {
  const dangerousResetCmds = [
    "git reset --hard main",
    "git reset --hard master",
    "git reset --hard origin/main",
  ];

  for (const cmd of dangerousResetCmds) {
    it(`${cmd} をブロックする`, () => {
      const result = evaluateRules(makeCtx("Bash", { command: cmd }));
      expect(result.decision).toBe("deny");
    });
  }
});

// ============================================================
// R12: protected branch への direct push 警告
// ============================================================
describe("R12: protected branch への direct push 警告", () => {
  it("git push origin main は approve + systemMessage を返す", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "git push origin main" })
    );
    expect(result.decision).toBe("approve");
    expect(result.systemMessage).toBeTruthy();
    expect(result.systemMessage).toContain("main");
  });

  it("git push upstream master は approve + systemMessage を返す", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "git push upstream master" })
    );
    expect(result.decision).toBe("approve");
    expect(result.systemMessage).toBeTruthy();
    expect(result.systemMessage).toContain("master");
  });
});

// ============================================================
// R13: 重要ファイル変更の警告
// ============================================================
describe("R13: 重要ファイル変更の警告", () => {
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
    it(`${path} の Write は approve + systemMessage を返す`, () => {
      const result = evaluateRules(
        makeCtx("Write", { file_path: path })
      );
      expect(result.decision).toBe("approve");
      expect(result.systemMessage).toBeTruthy();
      expect(result.systemMessage).toContain(path);
    });
  }

  it("通常のソースファイル変更は警告しない", () => {
    const result = evaluateRules(
      makeCtx("Write", { file_path: "src/index.ts" })
    );
    expect(result.decision).toBe("approve");
    expect(result.systemMessage).toBeUndefined();
  });
});

// ============================================================
// R07: Codex モード時の Write/Edit ブロック
// ============================================================
describe("R07: Codex モード時の Write/Edit ブロック", () => {
  it("Codex モード時の Write をブロックする", () => {
    const result = evaluateRules(
      makeCtx("Write", { file_path: "/project/src/foo.ts" }, { codexMode: true })
    );
    expect(result.decision).toBe("deny");
  });

  it("Codex モード時の Edit をブロックする", () => {
    const result = evaluateRules(
      makeCtx("Edit", { file_path: "/project/src/foo.ts" }, { codexMode: true })
    );
    expect(result.decision).toBe("deny");
  });

  it("通常モードでは Write をブロックしない", () => {
    const result = evaluateRules(
      makeCtx("Write", { file_path: "/project/src/foo.ts" }, { codexMode: false })
    );
    expect(result.decision).toBe("approve");
  });

  it("Codex モード時の Bash はブロックしない（R07 の toolPattern が Write/Edit のみ）", () => {
    // R07 の toolPattern は /^(?:Write|Edit|MultiEdit)$/ のみ
    // evaluateRules が toolPattern をチェックするため Bash は R07 にマッチしない
    const result = evaluateRules(
      makeCtx("Bash", { command: "ls" }, { codexMode: true })
    );
    expect(result.decision).toBe("approve");
  });
});

// ============================================================
// R08: Breezing reviewer ロールガード
// ============================================================
describe("R08: Breezing reviewer ロールガード", () => {
  it("reviewer ロール時の Write をブロックする", () => {
    const result = evaluateRules(
      makeCtx("Write", { file_path: "/project/src/foo.ts" }, { breezingRole: "reviewer" })
    );
    expect(result.decision).toBe("deny");
  });

  it("reviewer ロール時の Edit をブロックする", () => {
    const result = evaluateRules(
      makeCtx("Edit", { file_path: "/project/src/foo.ts" }, { breezingRole: "reviewer" })
    );
    expect(result.decision).toBe("deny");
  });

  it("reviewer ロール時の git commit をブロックする", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "git commit -m 'test'" }, { breezingRole: "reviewer" })
    );
    expect(result.decision).toBe("deny");
  });

  it("reviewer ロール時の git push をブロックする", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "git push origin main" }, { breezingRole: "reviewer" })
    );
    expect(result.decision).toBe("deny");
  });

  it("reviewer ロール時の ls はブロックしない（read-only コマンド）", () => {
    const rule = GUARD_RULES.find((r) => r.id === "R08:breezing-reviewer-no-write")!;
    const result = rule.evaluate(
      makeCtx("Bash", { command: "ls -la" }, { breezingRole: "reviewer" })
    );
    // prohibited パターンに該当しないため null
    expect(result).toBeNull();
  });

  it("reviewer ロールでない場合はブロックしない", () => {
    const result = evaluateRules(
      makeCtx("Write", { file_path: "/project/src/foo.ts" }, { breezingRole: "implementer" })
    );
    expect(result.decision).toBe("approve");
  });

  it("ロールなしの場合はブロックしない", () => {
    const result = evaluateRules(
      makeCtx("Write", { file_path: "/project/src/foo.ts" }, { breezingRole: null })
    );
    expect(result.decision).toBe("approve");
  });
});

// ============================================================
// R09: 機密ファイル Read 警告（approve + systemMessage）
// ============================================================
describe("R09: 機密ファイル Read 警告", () => {
  const secretPaths = [
    ".env",
    "id_rsa",
    "private.pem",
    "server.key",
    "secrets/api.json",
  ];

  for (const path of secretPaths) {
    it(`${path} の Read は approve + systemMessage を返す`, () => {
      const result = evaluateRules(
        makeCtx("Read", { file_path: path })
      );
      expect(result.decision).toBe("approve");
      expect(result.systemMessage).toBeDefined();
      expect(result.systemMessage).toContain(path);
    });
  }

  it("通常のソースファイルの Read は警告なし", () => {
    const result = evaluateRules(
      makeCtx("Read", { file_path: "src/index.ts" })
    );
    expect(result.decision).toBe("approve");
    expect(result.systemMessage).toBeUndefined();
  });
});

// ============================================================
// evaluateRules: 統合テスト
// ============================================================
describe("evaluateRules: 統合テスト", () => {
  it("tool_input.command が文字列でない場合はルールをスキップする", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: 12345 })
    );
    expect(result.decision).toBe("approve");
  });

  it("どのルールにも該当しない場合は approve を返す", () => {
    const result = evaluateRules(
      makeCtx("Bash", { command: "echo hello" })
    );
    expect(result.decision).toBe("approve");
  });

  it("Codex MCP ツールは Bash ルールが適用されない", () => {
    // mcp__codex__* は GUARD_RULES にない（rules.ts の対象外）
    // index.ts で別途ブロックされる
    const result = evaluateRules(
      makeCtx("mcp__codex__exec", { input: "ls" })
    );
    expect(result.decision).toBe("approve");
  });

  it("R01 と R05 が同時に該当する場合は R01（sudo）を優先する", () => {
    // sudo + rm -rf のコマンド → R01 が先にマッチ
    const result = evaluateRules(
      makeCtx("Bash", { command: "sudo rm -rf /" })
    );
    expect(result.decision).toBe("deny");
    // deny なら R01 の説明が含まれる
    expect(result.reason).toContain("sudo");
  });
});
