// PTY Session Types
export type PTYSessionStatus = 'IDLE' | 'RUNNING' | 'WAITING';
export type PTYSessionPhase = 'IDLE' | 'PLAN' | 'WORK' | 'REVIEW';

export interface PTYSession {
  id: string;
  pid: number | null;
  status: PTYSessionStatus;
  phase: PTYSessionPhase;
  projectId: string;
  worktreePath: string;
  logs: string[];
  lastActivity: number;
  createdAt: number;
}

// Plans.md Types
export type TaskStatus = 'pending' | 'in_progress' | 'completed' | 'blocked';

export interface PlanTask {
  id: string;
  content: string;
  status: TaskStatus;
  marker?: string;
}

export interface PlanSection {
  title: string;
  tasks: PlanTask[];
}

export interface PlansData {
  projectId?: string;
  sections: PlanSection[];
  summary: {
    total: number;
    pending: number;
    inProgress: number;
    completed: number;
    blocked: number;
    progressPercent: number;
  };
}

// WebSocket Message Types
export type WSMessageType =
  | 'sessions_list'
  | 'session_update'
  | 'log_chunk'
  | 'send_input'
  | 'create_session'
  | 'destroy_session'
  | 'resize_terminal'
  | 'plans_update';

export interface WSMessage<T = unknown> {
  type: WSMessageType;
  payload: T;
}

export interface SessionsListPayload {
  sessions: PTYSession[];
}

export interface SessionUpdatePayload {
  session: PTYSession;
}

export interface LogChunkPayload {
  sessionId: string;
  data: string;
}

export interface SendInputPayload {
  sessionId: string;
  data: string;
}

export interface CreateSessionPayload {
  projectId: string;
  worktreePath?: string;
}

export interface DestroySessionPayload {
  sessionId: string;
}

export interface ResizeTerminalPayload {
  sessionId: string;
  cols: number;
  rows: number;
}

// Settings Types
export interface ClaudeSettings {
  path: string;
  args: string[];
}

export interface TerminalSettings {
  cols: number;
  rows: number;
  env: Record<string, string>;
}

export interface ProjectSettings {
  mainPath: string;
  worktreePaths: string[];
  waitingPatterns: string[];
  idleTimeout: number;
}

export interface CommandsSettings {
  corePath: string;
}

export interface AppSettings {
  claude: ClaudeSettings;
  terminal: TerminalSettings;
  project: ProjectSettings;
  commands: CommandsSettings;
}

// Core Commands
export interface CoreCommand {
  id: string;
  name: string;
  description: string;
  template: string; // e.g., "/plan-with-agent {input}"
}

// Multi-project Support
export interface Project {
  id: string;
  name: string;
  path: string;
  plansPath: string;
  worktreePaths: string[];
  isActive: boolean;
}

export interface ProjectsData {
  projects: Project[];
  activeProjectId: string | null;
}

// UI State
export type Page = 'dashboard' | 'work' | 'settings';
