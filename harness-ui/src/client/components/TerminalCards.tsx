import { useState } from 'react';
import type { PTYSession } from '@shared/types';

interface TerminalCardsProps {
  sessions: PTYSession[];
  focusedId?: string | null;
  worktreePaths?: string[];
  onFocus: (sessionId: string) => void;
  onCreateSession: (worktreePath?: string) => void;
}

function formatElapsedTime(startTime: number): string {
  const elapsed = Date.now() - startTime;
  const seconds = Math.floor(elapsed / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);

  if (hours > 0) {
    return `${hours}h ${minutes % 60}m`;
  }
  if (minutes > 0) {
    return `${minutes}m ${seconds % 60}s`;
  }
  return `${seconds}s`;
}

function getLastLogLine(logs: string[]): string {
  if (!logs || logs.length === 0) return '(no output)';
  const lastLog = logs[logs.length - 1];
  // Strip ANSI codes and truncate
  const cleaned = lastLog.replace(/\x1b\[[0-9;]*m/g, '').trim();
  return cleaned.length > 50 ? cleaned.slice(0, 47) + '...' : cleaned || '(no output)';
}

export function TerminalCards({
  sessions,
  focusedId,
  worktreePaths = [],
  onFocus,
  onCreateSession,
}: TerminalCardsProps) {
  const maxSessions = 4;
  const canCreate = sessions.length < maxSessions;
  const [selectedWorktree, setSelectedWorktree] = useState<string>('');

  const handleCreate = () => {
    onCreateSession(selectedWorktree || undefined);
    setSelectedWorktree('');
  };

  return (
    <div className="terminals-panel">
      <h2>Terminals ({sessions.length}/{maxSessions})</h2>
      <div className="terminal-cards">
        {sessions.map((session) => (
          <div
            key={session.id}
            className={`terminal-card ${focusedId === session.id ? 'focused' : ''}`}
            onClick={() => onFocus(session.id)}
          >
            <div className={`status-dot ${session.status.toLowerCase()}`} />
            <div className="info">
              <div className="id">Terminal #{session.id.slice(-6)}</div>
              <div className="path">{session.worktreePath}</div>
              <div className="last-log">{getLastLogLine(session.logs)}</div>
            </div>
            <div className="card-meta">
              <div className={`phase ${session.phase.toLowerCase()}`}>{session.phase}</div>
              <div className="elapsed-time">{formatElapsedTime(session.createdAt)}</div>
            </div>
          </div>
        ))}

        {canCreate && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
            {worktreePaths.length > 0 && (
              <div className="worktree-selector">
                <label>Worktree:</label>
                <select
                  value={selectedWorktree}
                  onChange={(e) => setSelectedWorktree(e.target.value)}
                >
                  <option value="">Default (main project)</option>
                  {worktreePaths.map((path, idx) => (
                    <option key={idx} value={path}>
                      {path.split('/').pop() || path}
                    </option>
                  ))}
                </select>
              </div>
            )}
            <button className="add-terminal-btn" onClick={handleCreate}>
              + Add Terminal
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
