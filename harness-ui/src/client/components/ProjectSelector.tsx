import { useState, useCallback } from 'react';
import type { Project } from '@shared/types';

interface ProjectSelectorProps {
  projects: Project[];
  activeProjectId: string | null;
  onActivate: (projectId: string) => void;
  onAdd: (project: Omit<Project, 'id' | 'isActive'>) => Promise<Project | null>;
  onRemove: (projectId: string) => void;
}

export function ProjectSelector({
  projects,
  activeProjectId,
  onActivate,
  onAdd,
  onRemove,
}: ProjectSelectorProps) {
  const [showAddForm, setShowAddForm] = useState(false);
  const [newName, setNewName] = useState('');
  const [newPath, setNewPath] = useState('');

  const handleAdd = useCallback(async () => {
    if (!newName.trim() || !newPath.trim()) return;

    await onAdd({
      name: newName.trim(),
      path: newPath.trim(),
      plansPath: `${newPath.trim()}/Plans.md`,
      worktreePaths: [],
    });

    setNewName('');
    setNewPath('');
    setShowAddForm(false);
  }, [newName, newPath, onAdd]);

  return (
    <div className="project-selector">
      <label>Project:</label>
      <select
        value={activeProjectId || ''}
        onChange={(e) => onActivate(e.target.value)}
      >
        {projects.map((p) => (
          <option key={p.id} value={p.id}>
            {p.name}
          </option>
        ))}
      </select>

      <button className="btn" onClick={() => setShowAddForm(!showAddForm)}>
        {showAddForm ? 'Cancel' : '+ Add'}
      </button>

      {activeProjectId && activeProjectId !== 'default' && (
        <button
          className="btn"
          onClick={() => {
            if (confirm('Remove this project?')) {
              onRemove(activeProjectId);
            }
          }}
        >
          Remove
        </button>
      )}

      {showAddForm && (
        <div style={{ display: 'flex', gap: '8px', marginLeft: '8px' }}>
          <input
            type="text"
            placeholder="Name"
            value={newName}
            onChange={(e) => setNewName(e.target.value)}
            style={{
              padding: '4px 8px',
              background: 'var(--bg-secondary)',
              border: '1px solid var(--border-color)',
              borderRadius: '4px',
              color: 'var(--text-primary)',
              fontSize: '12px',
              width: '100px',
            }}
          />
          <input
            type="text"
            placeholder="/path/to/project"
            value={newPath}
            onChange={(e) => setNewPath(e.target.value)}
            style={{
              padding: '4px 8px',
              background: 'var(--bg-secondary)',
              border: '1px solid var(--border-color)',
              borderRadius: '4px',
              color: 'var(--text-primary)',
              fontSize: '12px',
              width: '200px',
            }}
          />
          <button className="btn btn-primary" onClick={handleAdd}>
            Add
          </button>
        </div>
      )}
    </div>
  );
}
