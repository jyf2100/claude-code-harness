interface ProgressSummaryProps {
  summary: {
    total: number;
    pending: number;
    inProgress: number;
    completed: number;
    blocked: number;
    progressPercent: number;
  };
}

export function ProgressSummary({ summary }: ProgressSummaryProps) {
  return (
    <div className="summary-panel">
      <div className="summary-stat">
        <div className="value">{summary.total}</div>
        <div className="label">Total</div>
      </div>
      <div className="summary-stat">
        <div className="value" style={{ color: 'var(--status-idle)' }}>
          {summary.pending}
        </div>
        <div className="label">Pending</div>
      </div>
      <div className="summary-stat">
        <div className="value" style={{ color: 'var(--status-waiting)' }}>
          {summary.inProgress}
        </div>
        <div className="label">In Progress</div>
      </div>
      <div className="summary-stat">
        <div className="value" style={{ color: 'var(--status-running)' }}>
          {summary.completed}
        </div>
        <div className="label">Completed</div>
      </div>
      <div className="summary-stat">
        <div className="value" style={{ color: 'var(--status-blocked)' }}>
          {summary.blocked}
        </div>
        <div className="label">Blocked</div>
      </div>

      <div className="progress-bar">
        <div className="track">
          <div className="fill" style={{ width: `${summary.progressPercent}%` }} />
        </div>
        <div className="percent">{summary.progressPercent}%</div>
      </div>
    </div>
  );
}
