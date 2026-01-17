import type {
  PTYSession,
  PTYSessionStatus,
  PTYSessionPhase,
  AppSettings,
} from '@shared/types';

// Default settings
const defaultSettings: AppSettings = {
  claude: {
    path: 'claude',
    args: [],
  },
  terminal: {
    cols: 120,
    rows: 30,
    env: {},
  },
  project: {
    mainPath: process.cwd(),
    worktreePaths: [],
    waitingPatterns: [
      'Do you want to proceed',
      'Waiting for',
      '\\[y/N\\]',
      '\\[Y/n\\]',
      'Press Enter',
    ],
    idleTimeout: 30000,
  },
  commands: {
    corePath: '',
  },
};

type MessageCallback = (sessionId: string, data: string) => void;
type UpdateCallback = (session: PTYSession) => void;

interface TerminalInstance {
  write: (data: string) => void;
  resize: (cols: number, rows: number) => void;
  close: () => void;
}

interface SessionData {
  session: PTYSession;
  terminal: TerminalInstance | null;
  proc: ReturnType<typeof Bun.spawn> | null;
  buffer: string[];
}

export class PTYManager {
  private sessions: Map<string, SessionData> = new Map();
  private settings: AppSettings = defaultSettings;
  private onMessage: MessageCallback | null = null;
  private onUpdate: UpdateCallback | null = null;
  private idleCheckInterval: ReturnType<typeof setInterval> | null = null;

  constructor() {
    this.startIdleChecker();
  }

  setSettings(settings: Partial<AppSettings>): void {
    this.settings = { ...this.settings, ...settings };
  }

  getSettings(): AppSettings {
    return this.settings;
  }

  setMessageCallback(callback: MessageCallback): void {
    this.onMessage = callback;
  }

  setUpdateCallback(callback: UpdateCallback): void {
    this.onUpdate = callback;
  }

  private generateId(): string {
    return `pty_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  }

  private notifyUpdate(session: PTYSession): void {
    if (this.onUpdate) {
      this.onUpdate(session);
    }
  }

  private notifyMessage(sessionId: string, data: string): void {
    if (this.onMessage) {
      this.onMessage(sessionId, data);
    }
  }

  private detectStatus(data: string): PTYSessionStatus | null {
    const patterns = this.settings.project.waitingPatterns;
    for (const pattern of patterns) {
      if (new RegExp(pattern, 'i').test(data)) {
        return 'WAITING';
      }
    }
    return null;
  }

  private detectPhase(input: string): PTYSessionPhase | null {
    const lower = input.toLowerCase();
    if (lower.includes('/plan') || lower.includes('plan-with-agent')) {
      return 'PLAN';
    }
    if (lower.includes('/work')) {
      return 'WORK';
    }
    if (lower.includes('/review') || lower.includes('harness-review')) {
      return 'REVIEW';
    }
    return null;
  }

  private startIdleChecker(): void {
    this.idleCheckInterval = setInterval(() => {
      const now = Date.now();
      for (const [, data] of this.sessions) {
        const { session } = data;
        if (
          session.status === 'RUNNING' &&
          now - session.lastActivity > this.settings.project.idleTimeout
        ) {
          session.status = 'WAITING';
          this.notifyUpdate(session);
        }
      }
    }, 5000);
  }

  async createSession(projectId: string, worktreePath?: string): Promise<PTYSession> {
    const id = this.generateId();
    const { cols, rows, env } = this.settings.terminal;
    const { path: claudePath, args } = this.settings.claude;
    const cwd = worktreePath || this.settings.project.mainPath;

    const session: PTYSession = {
      id,
      pid: null,
      status: 'IDLE',
      phase: 'IDLE',
      projectId,
      worktreePath: cwd,
      logs: [],
      lastActivity: Date.now(),
      createdAt: Date.now(),
    };

    const sessionData: SessionData = {
      session,
      terminal: null,
      proc: null,
      buffer: [],
    };

    this.sessions.set(id, sessionData);

    try {
      const proc = Bun.spawn([claudePath, ...args], {
        cwd,
        env: { ...process.env, ...env },
        terminal: {
          cols,
          rows,
          data: (terminal: TerminalInstance, data: Uint8Array) => {
            const text = new TextDecoder().decode(data);
            this.handleOutput(id, text);
          },
        },
      });

      sessionData.proc = proc;
      sessionData.terminal = (proc as unknown as { terminal: TerminalInstance }).terminal;
      session.pid = proc.pid;
      session.status = 'RUNNING';

      proc.exited.then(() => {
        const data = this.sessions.get(id);
        if (data) {
          data.session.status = 'IDLE';
          data.session.pid = null;
          this.notifyUpdate(data.session);
        }
      });

      this.notifyUpdate(session);
    } catch (error) {
      console.error(`Failed to create PTY session: ${error}`);
      session.status = 'IDLE';
    }

    return session;
  }

  private handleOutput(sessionId: string, data: string): void {
    const sessionData = this.sessions.get(sessionId);
    if (!sessionData) return;

    const { session, buffer } = sessionData;

    // Update activity timestamp
    session.lastActivity = Date.now();

    // Add to buffer and logs
    buffer.push(data);
    session.logs.push(data);

    // Keep logs manageable
    if (session.logs.length > 1000) {
      session.logs = session.logs.slice(-500);
    }

    // Detect status changes
    const newStatus = this.detectStatus(data);
    if (newStatus && session.status !== newStatus) {
      session.status = newStatus;
      this.notifyUpdate(session);
    } else if (session.status === 'WAITING') {
      // Resume to RUNNING on new output that isn't a waiting pattern
      session.status = 'RUNNING';
      this.notifyUpdate(session);
    }

    // Notify message
    this.notifyMessage(sessionId, data);
  }

  sendInput(sessionId: string, data: string): boolean {
    const sessionData = this.sessions.get(sessionId);
    if (!sessionData?.terminal) return false;

    // Detect phase from input
    const newPhase = this.detectPhase(data);
    if (newPhase) {
      sessionData.session.phase = newPhase;
      this.notifyUpdate(sessionData.session);
    }

    sessionData.session.lastActivity = Date.now();
    sessionData.terminal.write(data);
    return true;
  }

  resizeTerminal(sessionId: string, cols: number, rows: number): boolean {
    const sessionData = this.sessions.get(sessionId);
    if (!sessionData?.terminal) return false;

    sessionData.terminal.resize(cols, rows);
    return true;
  }

  destroySession(sessionId: string): boolean {
    const sessionData = this.sessions.get(sessionId);
    if (!sessionData) return false;

    if (sessionData.terminal) {
      sessionData.terminal.close();
    }
    if (sessionData.proc) {
      sessionData.proc.kill();
    }

    this.sessions.delete(sessionId);
    return true;
  }

  getSession(sessionId: string): PTYSession | undefined {
    return this.sessions.get(sessionId)?.session;
  }

  getAllSessions(): PTYSession[] {
    return Array.from(this.sessions.values()).map((d) => d.session);
  }

  getSessionsByProject(projectId: string): PTYSession[] {
    return Array.from(this.sessions.values())
      .filter((d) => d.session.projectId === projectId)
      .map((d) => d.session);
  }

  destroy(): void {
    if (this.idleCheckInterval) {
      clearInterval(this.idleCheckInterval);
    }
    for (const [id] of this.sessions) {
      this.destroySession(id);
    }
  }
}

export const ptyManager = new PTYManager();
