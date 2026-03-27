/**
 * lifecycle.ts — 会话生命周期管理
 *
 * 吸收旧会话系技能（session / session-init / session-control /
 * session-state / session-memory）的逻辑。
 * 统一管理会话开始、结束和状态转换。
 */

import type { SessionState, SessionMode, Signal } from "../types.js";

// ============================================================
// 会话执行状态（内部 enum 相当）
// ============================================================

/** 会话的执行阶段 */
export type SessionPhase = "active" | "paused" | "completed" | "failed";

/** 会话上下文 */
export interface SessionContext {
  sessionId: string;
  startedAt: Date;
  phase: SessionPhase;
  state: SessionState;
  /** 最近的 agent-trace 条目 */
  recentFiles: string[];
}

// ============================================================
// 会话开始（相当于 session-init）
// ============================================================

/**
 * 会话开始处理。
 * 执行环境检查、任务状况把握和交接确认。
 */
export function initSession(opts: {
  sessionId: string;
  projectRoot: string;
  mode?: SessionMode;
}): SessionContext {
  const initialState: SessionState = {
    session_id: opts.sessionId,
    mode: opts.mode ?? "normal",
    project_root: opts.projectRoot,
    started_at: new Date().toISOString(),
  };

  return {
    sessionId: opts.sessionId,
    startedAt: new Date(),
    phase: "active",
    state: initialState,
    recentFiles: [],
  };
}

// ============================================================
// 会话状态转换（相当于 session-state / session-control）
// ============================================================

/** 允许的状态转换映射 */
const VALID_TRANSITIONS: Record<SessionPhase, SessionPhase[]> = {
  active: ["paused", "completed", "failed"],
  paused: ["active", "completed", "failed"],
  completed: [],
  failed: [],
};

/**
 * 转换会话阶段。
 * 非法转换时抛出 Error。
 */
export function transitionSession(
  ctx: SessionContext,
  next: SessionPhase,
): SessionContext {
  const allowed = VALID_TRANSITIONS[ctx.phase];
  if (!allowed.includes(next)) {
    throw new Error(
      `Invalid session transition: ${ctx.phase} → ${next}`,
    );
  }
  return { ...ctx, phase: next };
}

// ============================================================
// 会话结束处理（相当于 session-memory）
// ============================================================

/** 会话结束时的摘要 */
export interface SessionSummary {
  sessionId: string;
  duration: number; // 毫秒
  finalPhase: SessionPhase;
  signals: Signal[];
}

/**
 * 会话结束处理。
 * 完成或失败时都要调用。
 */
export function finalizeSession(
  ctx: SessionContext,
  signals: Signal[] = [],
): SessionSummary {
  const duration = Date.now() - ctx.startedAt.getTime();
  return {
    sessionId: ctx.sessionId,
    duration,
    finalPhase: ctx.phase,
    signals,
  };
}

// ============================================================
// 会话分支（相当于 session-control 的 --fork）
// ============================================================

/**
 * 分支当前会话上下文。
 * 返回分配了新会话 ID 的独立副本。
 */
export function forkSession(
  parent: SessionContext,
  newSessionId: string,
): SessionContext {
  const forkedState: SessionState = {
    ...parent.state,
    session_id: newSessionId,
    started_at: new Date().toISOString(),
  };

  return {
    ...parent,
    sessionId: newSessionId,
    startedAt: new Date(),
    phase: "active",
    state: forkedState,
  };
}

// ============================================================
// 会话恢复（相当于 session-control 的 --resume）
// ============================================================

/** 会话恢复用的最小信息 */
export interface ResumeInfo {
  sessionId: string;
  projectRoot: string;
  mode: SessionMode;
  lastPhase: SessionPhase;
}

/**
 * 恢复过去的会话。
 * 如果 lastPhase 是 completed / failed，则作为新会话处理。
 */
export function resumeSession(info: ResumeInfo): SessionContext {
  const isResumable =
    info.lastPhase === "active" || info.lastPhase === "paused";

  const newId = isResumable
    ? info.sessionId
    : `${info.sessionId}-resumed`;

  const state: SessionState = {
    session_id: newId,
    mode: info.mode,
    project_root: info.projectRoot,
    started_at: new Date().toISOString(),
  };

  return {
    sessionId: newId,
    startedAt: new Date(),
    phase: "active",
    state,
    recentFiles: [],
  };
}
