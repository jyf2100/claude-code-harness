import type { PlanSection } from '@shared/types';

interface PlansBoardProps {
  sections: PlanSection[];
}

export function PlansBoard({ sections }: PlansBoardProps) {
  if (sections.length === 0) {
    return (
      <div className="plans-board">
        <h2>Plans Board</h2>
        <div style={{ color: 'var(--text-muted)', textAlign: 'center', padding: '32px' }}>
          No Plans.md found or empty
        </div>
      </div>
    );
  }

  return (
    <div className="plans-board">
      <h2>Plans Board</h2>
      {sections.map((section, idx) => (
        <div key={idx} className="plan-section">
          <h3>{section.title}</h3>
          {section.tasks.map((task) => (
            <div key={task.id} className={`plan-task status-${task.status}`}>
              {task.marker && <span className="marker">{task.marker}</span>}
              <span className="content">{task.content}</span>
            </div>
          ))}
        </div>
      ))}
    </div>
  );
}
