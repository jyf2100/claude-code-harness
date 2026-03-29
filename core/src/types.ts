/**
 * core/src/types.ts
 * Harness v3 通用类型定义
 *
 * 定义 Claude Code Hooks 的 stdin/stdout JSON 架构
 * 以及护栏引擎的内部类型。
 */

// ============================================================
// Hook I/O 类型（遵循 Claude Code Hooks 协议）
// ============================================================

/** PreToolUse / PostToolUse 钩子的输入 */
export interface HookInput {
  /** 即将执行的工具名称（例: "Bash", "Write"） */
  tool_name: string;
  /** 工具的输入参数 */
  tool_input: Record<string, unknown>;
  /** 会话 ID（由 Claude Code 设置） */
  session_id?: string;
  /** 当前工作目录 */
  cwd?: string;
  /** 插件根目录 */
  plugin_root?: string;
}

/** 钩子返回的动作 */
export type HookDecision = "approve" | "deny" | "ask";

/** 钩子的输出（Claude Code Hooks 协议） */
export interface HookResult {
  /** 是否允许或拒绝执行 */
  decision: HookDecision;
  /** 给用户的说明消息 */
  reason?: string;
  /** 给 Claude 的附加上下文（systemMessage） */
  systemMessage?: string;
}

// ============================================================
// 护栏类型
// ============================================================

/** 护栏规则的评估上下文 */
export interface RuleContext {
  input: HookInput;
  projectRoot: string;
  workMode: boolean;
  codexMode: boolean;
  breezingRole: string | null;
}

/** 单个护栏规则的定义 */
export interface GuardRule {
  /** 规则标识符（用于日志和调试） */
  id: string;
  /** 此规则适用的工具名称模式（正则表达式） */
  toolPattern: RegExp;
  /** 评估规则的函数。如果不匹配则返回 null */
  evaluate: (ctx: RuleContext) => HookResult | null;
}

// ============================================================
// 信号类型（代理间通信）
// ============================================================

/** 代理间交换的信号种类 */
export type SignalType =
  | "task_completed"
  | "task_failed"
  | "teammate_idle"
  | "session_start"
  | "session_end"
  | "stop_failure"
  | "request_review";

/** 代理间信号 */
export interface Signal {
  type: SignalType;
  /** 发送方会话 ID */
  from_session_id: string;
  /** 接收方会话 ID（省略时为广播） */
  to_session_id?: string;
  /** 信号的载荷 */
  payload: Record<string, unknown>;
  /** 发送时刻（ISO 8601） */
  timestamp: string;
}

// ============================================================
// 任务失败类型
// ============================================================

/** 任务失败的严重程度 */
export type FailureSeverity = "warning" | "error" | "critical";

/** 任务失败事件 */
export interface TaskFailure {
  /** 失败任务的标识符 */
  task_id: string;
  /** 失败的严重程度 */
  severity: FailureSeverity;
  /** 失败的说明 */
  message: string;
  /** 堆栈跟踪或详细信息 */
  detail?: string;
  /** 失败时刻（ISO 8601） */
  timestamp: string;
  /** 尝试次数 */
  attempt: number;
}

// ============================================================
// 会话状态类型
// ============================================================

/** 会话的执行模式 */
export type SessionMode = "normal" | "work" | "codex" | "breezing";

/** 会话状态 */
export interface SessionState {
  session_id: string;
  mode: SessionMode;
  project_root: string;
  started_at: string;
  /** work/breezing 模式下的上下文信息 */
  context?: Record<string, unknown>;
}

// ============================================================
// 进化引擎类型
// ============================================================

/** 技能调用方式 */
export type SkillInvocationType = "skill" | "command" | "agent" | "derived";

/** 技能使用指标记录 */
export interface SkillUsageMetric {
  id?: number;
  session_id: string;
  skill_name: string;
  skill_version?: string;
  invocation_type: SkillInvocationType;
  tool_name?: string;
  success: boolean;
  error_message?: string;
  duration_ms?: number;
  tokens_used?: number;
  recorded_at?: string;
  context?: Record<string, unknown>;
}

/** 技能进化状态 */
export type SkillEvolutionStatus = "active" | "deprecated" | "derived" | "captured";
export type EvolutionType = "fix" | "derived" | "captured";
export type EvolutionPending = "none" | "fix" | "review" | "deprecate" | "derived" | "captured";

/** 技能进化记录 */
export interface SkillEvolution {
  skill_name: string;
  version: string;
  status: SkillEvolutionStatus;
  parent_skill?: string;
  evolution_type?: EvolutionType;
  health_score: number;
  usage_count: number;
  success_rate: number;
  last_used_at?: string;
  last_evolved_at?: string;
  evolution_pending: EvolutionPending;
  evolution_reason?: string;
}

/** 进化提案状态 */
export type ProposalStatus = "pending" | "approved" | "rejected" | "applied";
export type ProposalType = "fix" | "derived" | "captured" | "deprecate";

/** 进化提案详情 */
export interface EvolutionProposalDetail {
  /** 提案原因 */
  reason: string;
  /** 建议的变更内容 */
  suggested_changes?: string;
  /** 失败模式分析（FIX 类型） */
  failure_patterns?: string[];
  /** 新增能力描述（DERIVED 类型） */
  new_capabilities?: string[];
  /** 源会话 ID（CAPTURED 类型） */
  source_session_id?: string;
  /** 优先级 1-5（5 最高） */
  priority?: number;
}

/** 进化提案 */
export interface SkillEvolutionProposal {
  id?: number;
  skill_name: string;
  proposal_type: ProposalType;
  proposal: EvolutionProposalDetail;
  created_at: string;
  status: ProposalStatus;
  reviewed_at?: string;
  reviewed_by?: string;
  applied_at?: string;
}

/** 进化引擎配置 */
export interface EvolutionConfig {
  /** 健康分数阈值（低于此值触发 FIX 提案） */
  healthThreshold: number;
  /** 使用次数阈值（高于此值触发 DERIVED 提案） */
  usageThresholdForDerived: number;
  /** 成功率阈值（高于此值触发 CAPTURED 提案） */
  successRateThresholdForCaptured: number;
  /** 每小时最大进化提案数 */
  maxProposalsPerHour: number;
  /** 每日最大进化提案数 */
  maxProposalsPerDay: number;
  /** 快照保留天数 */
  snapshotRetentionDays: number;
}
