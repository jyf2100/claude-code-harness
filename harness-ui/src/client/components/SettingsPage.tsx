import { useState, useEffect, useCallback } from 'react';
import type { AppSettings } from '@shared/types';

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
    mainPath: '',
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

export function SettingsPage() {
  const [settings, setSettings] = useState<AppSettings>(defaultSettings);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  // Load settings
  useEffect(() => {
    fetch('/api/settings')
      .then((res) => res.json())
      .then((data) => setSettings(data))
      .catch(console.error);
  }, []);

  const handleSave = useCallback(async () => {
    setSaving(true);
    setMessage(null);
    try {
      const res = await fetch('/api/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(settings),
      });
      if (res.ok) {
        setMessage('Settings saved successfully');
      } else {
        setMessage('Failed to save settings');
      }
    } catch (err) {
      setMessage('Error saving settings');
    }
    setSaving(false);
  }, [settings]);

  const updateClaude = (key: keyof AppSettings['claude'], value: string | string[]) => {
    setSettings((prev) => ({
      ...prev,
      claude: { ...prev.claude, [key]: value },
    }));
  };

  const updateTerminal = (key: keyof AppSettings['terminal'], value: number | Record<string, string>) => {
    setSettings((prev) => ({
      ...prev,
      terminal: { ...prev.terminal, [key]: value },
    }));
  };

  const updateProject = (
    key: keyof AppSettings['project'],
    value: string | string[] | number
  ) => {
    setSettings((prev) => ({
      ...prev,
      project: { ...prev.project, [key]: value },
    }));
  };

  const updateCommands = (key: keyof AppSettings['commands'], value: string) => {
    setSettings((prev) => ({
      ...prev,
      commands: { ...prev.commands, [key]: value },
    }));
  };

  const handleReloadCommands = useCallback(async () => {
    try {
      const res = await fetch('/api/commands/reload', { method: 'POST' });
      if (res.ok) {
        setMessage('Commands reloaded successfully');
      } else {
        setMessage('Failed to reload commands');
      }
    } catch {
      setMessage('Error reloading commands');
    }
  }, []);

  return (
    <div className="settings-page">
      <div className="settings-section">
        <h2>Claude Code</h2>
        <div className="form-group">
          <label>Executable Path</label>
          <input
            type="text"
            value={settings.claude.path}
            onChange={(e) => updateClaude('path', e.target.value)}
            placeholder="/usr/local/bin/claude"
          />
        </div>
        <div className="form-group">
          <label>Arguments (comma separated)</label>
          <input
            type="text"
            value={settings.claude.args.join(', ')}
            onChange={(e) =>
              updateClaude(
                'args',
                e.target.value.split(',').map((s) => s.trim()).filter(Boolean)
              )
            }
            placeholder="--project, /path/to/project"
          />
        </div>
      </div>

      <div className="settings-section">
        <h2>Terminal</h2>
        <div className="form-row">
          <div className="form-group">
            <label>Columns</label>
            <input
              type="number"
              value={settings.terminal.cols}
              onChange={(e) => updateTerminal('cols', parseInt(e.target.value) || 80)}
            />
          </div>
          <div className="form-group">
            <label>Rows</label>
            <input
              type="number"
              value={settings.terminal.rows}
              onChange={(e) => updateTerminal('rows', parseInt(e.target.value) || 24)}
            />
          </div>
        </div>
        <div className="form-group">
          <label>Environment Variables (JSON)</label>
          <textarea
            value={JSON.stringify(settings.terminal.env, null, 2)}
            onChange={(e) => {
              try {
                const env = JSON.parse(e.target.value);
                updateTerminal('env', env);
              } catch {
                // Invalid JSON, ignore
              }
            }}
            placeholder='{"TERM": "xterm-256color"}'
          />
        </div>
      </div>

      <div className="settings-section">
        <h2>Project</h2>
        <div className="form-group">
          <label>Main Project Path</label>
          <input
            type="text"
            value={settings.project.mainPath}
            onChange={(e) => updateProject('mainPath', e.target.value)}
            placeholder="/path/to/main/project"
          />
        </div>
        <div className="form-group">
          <label>Worktree Paths (one per line)</label>
          <textarea
            value={settings.project.worktreePaths.join('\n')}
            onChange={(e) =>
              updateProject(
                'worktreePaths',
                e.target.value.split('\n').filter(Boolean)
              )
            }
            placeholder="/path/to/worktree1&#10;/path/to/worktree2"
          />
        </div>
        <div className="form-group">
          <label>WAITING Detection Patterns (one per line, regex)</label>
          <textarea
            value={settings.project.waitingPatterns.join('\n')}
            onChange={(e) =>
              updateProject(
                'waitingPatterns',
                e.target.value.split('\n').filter(Boolean)
              )
            }
            placeholder="Do you want to proceed\nWaiting for"
          />
        </div>
        <div className="form-group">
          <label>Idle Timeout (ms)</label>
          <input
            type="number"
            value={settings.project.idleTimeout}
            onChange={(e) => updateProject('idleTimeout', parseInt(e.target.value) || 30000)}
          />
        </div>
      </div>

      <div className="settings-section">
        <h2>Commands</h2>
        <div className="form-group">
          <label>Core Commands Path</label>
          <input
            type="text"
            value={settings.commands.corePath}
            onChange={(e) => updateCommands('corePath', e.target.value)}
            placeholder="/path/to/commands/core"
          />
          <small style={{ color: 'var(--text-secondary)', marginTop: '4px', display: 'block' }}>
            Path to the commands/core directory containing .md command files
          </small>
        </div>
        <button
          className="btn"
          onClick={handleReloadCommands}
          style={{ marginTop: '8px' }}
        >
          Reload Commands
        </button>
      </div>

      <div style={{ display: 'flex', gap: '16px', alignItems: 'center' }}>
        <button className="btn btn-primary" onClick={handleSave} disabled={saving}>
          {saving ? 'Saving...' : 'Save Settings'}
        </button>
        {message && (
          <span style={{ color: message.includes('success') ? 'var(--status-running)' : 'var(--status-blocked)' }}>
            {message}
          </span>
        )}
      </div>
    </div>
  );
}
