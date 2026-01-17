import { useRef, useCallback, useState, useEffect } from 'react';
import type { PlansData, PTYSession } from '@shared/types';
import { Terminal, TerminalHandle } from './Terminal';

interface WorkPageProps {
  plans: PlansData;
  sessions: PTYSession[];
  worktreePaths?: string[];
  focusedTerminal: string | null;
  onTerminalFocus: (sessionId: string | null) => void;
  onSendInput: (sessionId: string, data: string) => void;
  onCreateSession: (worktreePath?: string) => void;
  onDestroySession: (sessionId: string) => void;
  onResize: (sessionId: string, cols: number, rows: number) => void;
}

export function WorkPage({
  plans,
  sessions,
  worktreePaths = [],
  focusedTerminal,
  onTerminalFocus,
  onSendInput,
  onCreateSession,
  onDestroySession,
  onResize,
}: WorkPageProps) {
  const terminalRefs = useRef<Map<string, TerminalHandle | null>>(new Map());
  const logCursorRef = useRef<Map<string, number>>(new Map());
  const [selectedWorktrees, setSelectedWorktrees] = useState<Record<number, string>>({});

  const hydrateSessionLogs = useCallback(
    (session: PTYSession, handle: TerminalHandle | null, reset = false) => {
      if (!handle || !session.logs || session.logs.length === 0) return;
      if (reset) {
        handle.reset();
        logCursorRef.current.set(session.id, 0);
      }
      const prevIndex = logCursorRef.current.get(session.id) ?? 0;
      if (session.logs.length <= prevIndex) return;
      const chunk = session.logs.slice(prevIndex).join('');
      if (chunk) {
        handle.write(chunk);
        logCursorRef.current.set(session.id, session.logs.length);
      }
    },
    []
  );

  useEffect(() => {
    sessions.forEach((session) => {
      const handle = terminalRefs.current.get(session.id);
      if (handle) {
        hydrateSessionLogs(session, handle);
      }
    });
  }, [sessions, hydrateSessionLogs]);

  useEffect(() => {
    if (!focusedTerminal) return;
    const handle = terminalRefs.current.get(focusedTerminal);
    if (handle) {
      handle.focus();
    }
  }, [focusedTerminal, sessions]);

  useEffect(() => {
    const handleVisibility = () => {
      if (document.visibilityState !== 'visible') return;
      sessions.forEach((session) => {
        const handle = terminalRefs.current.get(session.id);
        if (handle) {
          handle.fit();
          hydrateSessionLogs(session, handle, true);
        }
      });
    };
    document.addEventListener('visibilitychange', handleVisibility);
    return () => {
      document.removeEventListener('visibilitychange', handleVisibility);
    };
  }, [sessions, hydrateSessionLogs]);

  // Ensure we have 4 slots
  const slots = Array.from({ length: 4 }, (_, i) => {
    return sessions[i] || null;
  });

  return (
    <div className="work-page">
      <div className="work-sidebar">
        <h3>Progress</h3>
        <div className="mini-stats">
          <div className="mini-stat">
            <span className="label">Total</span>
            <span className="value">{plans.summary.total}</span>
          </div>
          <div className="mini-stat">
            <span className="label">Completed</span>
            <span className="value" style={{ color: 'var(--status-running)' }}>
              {plans.summary.completed}
            </span>
          </div>
          <div className="mini-stat">
            <span className="label">In Progress</span>
            <span className="value" style={{ color: 'var(--status-waiting)' }}>
              {plans.summary.inProgress}
            </span>
          </div>
          <div className="mini-stat">
            <span className="label">Progress</span>
            <span className="value">{plans.summary.progressPercent}%</span>
          </div>
        </div>
      </div>

      <div className="terminals-grid">
        {slots.map((session, idx) => (
          <div
            key={session?.id || `empty-${idx}`}
            className={`terminal-pane ${focusedTerminal === session?.id ? 'focused' : ''}`}
            onClick={() => session && onTerminalFocus(session.id)}
          >
            {session ? (
              <>
                <div className="header">
                  <div className={`status-dot ${session.status.toLowerCase()}`} />
                  <span className="title">Terminal #{session.id.slice(-6)}</span>
                  <span className={`phase ${session.phase.toLowerCase()}`}>{session.phase}</span>
                  <button
                    className="btn"
                    style={{ padding: '2px 8px', fontSize: '11px' }}
                    onClick={(e) => {
                      e.stopPropagation();
                      onDestroySession(session.id);
                    }}
                  >
                    X
                  </button>
                </div>
                <div className="body">
                  <Terminal
                    ref={(handle) => {
                      terminalRefs.current.set(session.id, handle);
                      if (handle) {
                        hydrateSessionLogs(session, handle);
                        if (focusedTerminal === session.id) {
                          handle.focus();
                        }
                      }
                    }}
                    sessionId={session.id}
                    onInput={(data) => onSendInput(session.id, data)}
                    onResize={(cols, rows) => onResize(session.id, cols, rows)}
                  />
                </div>
              </>
            ) : (
              <div className="empty">
                {worktreePaths.length > 0 && (
                  <select
                    className="worktree-select"
                    value={selectedWorktrees[idx] || ''}
                    onChange={(e) => setSelectedWorktrees(prev => ({ ...prev, [idx]: e.target.value }))}
                    style={{ marginBottom: '8px', padding: '4px 8px' }}
                  >
                    <option value="">Default (main)</option>
                    {worktreePaths.map((path, i) => (
                      <option key={i} value={path}>
                        {path.split('/').pop() || path}
                      </option>
                    ))}
                  </select>
                )}
                <button
                  className="btn"
                  onClick={() => onCreateSession(selectedWorktrees[idx] || undefined)}
                >
                  + Start Terminal
                </button>
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
