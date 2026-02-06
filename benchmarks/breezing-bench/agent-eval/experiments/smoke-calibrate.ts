import type { ExperimentConfig } from "@vercel/agent-eval";

// Calibration smoke test: 1 run per task to check difficulty level
export default {
  agent: "claude-code",
  model: "claude-haiku-4-5-20251001",
  runs: 1,
  earlyExit: true,
  timeout: 300,
  scripts: ["test"],
  sandbox: "docker",
  evals: [
    "task-02",
    "task-03",
    "task-04",
    "task-05",
    "task-06",
    "task-08",
    "task-09",
    "task-10",
  ],
  setup: async (sandbox) => {
    await sandbox.writeFiles({
      "CLAUDE.md": [
        "You are a developer. Complete the task described in PROMPT.md.",
        "Write clean TypeScript with proper error handling.",
        "Read the existing source files in src/ - they contain scaffolding with TODO comments.",
        "Fill in the TODO sections to complete the implementation.",
        "Make sure all existing tests pass.",
        "Run `npm test` to verify your implementation.",
        "Run `npx tsc --noEmit` to verify type safety.",
      ].join("\n"),
    });
  },
} satisfies ExperimentConfig;
