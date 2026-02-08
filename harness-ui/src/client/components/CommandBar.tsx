import { useState, useEffect, useCallback } from 'react';
import type { CoreCommand, PTYSession } from '@shared/types';

interface CommandHistoryItem {
  id: string;
  command: string;
  targetSessionId: string;
  timestamp: number;
}

interface CommandBarProps {
  sessions: PTYSession[];
  onSendCommand: (sessionId: string, command: string) => void;
}

const MAX_HISTORY_ITEMS = 5;

export function CommandBar({ sessions, onSendCommand }: CommandBarProps) {
  const [commands, setCommands] = useState<CoreCommand[]>([]);
  const [selectedCommand, setSelectedCommand] = useState<string>('');
  const [input, setInput] = useState('');
  const [targetSession, setTargetSession] = useState<string>('');
  const [commandHistory, setCommandHistory] = useState<CommandHistoryItem[]>([]);

  // Fetch commands
  useEffect(() => {
    fetch('/api/commands')
      .then((res) => res.json())
      .then((data) => {
        setCommands(data.commands || []);
        if (data.commands?.length > 0) {
          setSelectedCommand(data.commands[0].id);
        }
      })
      .catch(console.error);
  }, []);

  // Auto-select first available session
  useEffect(() => {
    if (!targetSession && sessions.length > 0) {
      setTargetSession(sessions[0].id);
    }
  }, [sessions, targetSession]);

  const handleSend = useCallback(() => {
    if (!targetSession || !selectedCommand) return;

    const cmd = commands.find((c) => c.id === selectedCommand);
    if (!cmd) return;

    const trimmedInput = input.trim();
    const baseCommand = cmd.template.includes('{input}')
      ? cmd.template.replace('{input}', trimmedInput)
      : trimmedInput
        ? `${cmd.template} ${trimmedInput}`
        : cmd.template;
    const commandStr = baseCommand;
    onSendCommand(targetSession, commandStr);

    // Add to history
    const historyItem: CommandHistoryItem = {
      id: crypto.randomUUID(),
      command: baseCommand.trim(),
      targetSessionId: targetSession,
      timestamp: Date.now(),
    };
    setCommandHistory((prev) => [historyItem, ...prev].slice(0, MAX_HISTORY_ITEMS));

    setInput('');
  }, [targetSession, selectedCommand, input, commands, onSendCommand]);

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      const nativeEvent = e.nativeEvent as KeyboardEvent;
      const isComposing = e.isComposing || nativeEvent.isComposing || nativeEvent.keyCode === 229;
      if (e.key === 'Enter' && !e.shiftKey && !isComposing) {
        e.preventDefault();
        handleSend();
      }
    },
    [handleSend]
  );

  const activeSessions = sessions.filter((s) => s.status !== 'IDLE');

  return (
    <div className="command-bar">
      <div className="command-bar-row">
        <select
          className="command-select"
          value={selectedCommand}
          onChange={(e) => setSelectedCommand(e.target.value)}
          disabled={commands.length === 0}
        >
          {commands.length === 0 ? (
            <option value="">No commands (migrated to skills)</option>
          ) : (
            commands.map((cmd) => (
              <option key={cmd.id} value={cmd.id}>
                {cmd.name}
              </option>
            ))
          )}
        </select>

        <select
          className="target-select"
          value={targetSession}
          onChange={(e) => setTargetSession(e.target.value)}
          disabled={activeSessions.length === 0}
        >
          {activeSessions.length === 0 ? (
            <option value="">No active terminal</option>
          ) : (
            activeSessions.map((s) => (
              <option key={s.id} value={s.id}>
                Terminal #{s.id.slice(-6)}
              </option>
            ))
          )}
        </select>
      </div>

      <div className="command-bar-row">
        <input
          type="text"
          className="command-input"
          placeholder="一言指示を入力（省略可）..."
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={handleKeyDown}
        />
        <button
          className="btn btn-primary"
          onClick={handleSend}
          disabled={!targetSession || activeSessions.length === 0}
        >
          Send
        </button>
      </div>

      {selectedCommand && (
        <div className="command-hint">
          {commands.find((c) => c.id === selectedCommand)?.description}
        </div>
      )}

      {commandHistory.length > 0 && (
        <div className="command-history">
          <div className="history-title">Recent Commands ({commandHistory.length})</div>
          <div className="history-list">
            {commandHistory.map((item) => (
              <div key={item.id} className="history-item">
                <span className="history-command">{item.command}</span>
                <span className="history-time">
                  {new Date(item.timestamp).toLocaleTimeString()}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
