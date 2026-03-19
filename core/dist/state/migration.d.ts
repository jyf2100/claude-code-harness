/**
 * core/src/state/migration.ts
 * Harness v2 JSON / JSONL → v3 SQLite 移行スクリプト
 *
 * v2 の状態ファイルを v3 SQLite DB に取り込む。
 * 移行対象:
 *   .claude/state/session.json      → sessions テーブル
 *   .claude/state/session.events.jsonl → signals テーブル（task_completed 等）
 *   .claude/work-active.json         → work_states テーブル
 *
 * 冪等設計: 既に移行済みの場合は再実行しても安全。
 */
export interface MigrationResult {
    sessions: number;
    signals: number;
    workStates: number;
    skipped: boolean;
    errors: string[];
}
/**
 * v2 JSON/JSONL 状態ファイルを v3 SQLite DB に移行する。
 *
 * @param projectRoot - プロジェクトルートのパス（デフォルト: process.cwd()）
 * @param dbPath - SQLite DB のパス（デフォルト: <projectRoot>/.harness/state.db）
 * @returns 移行結果
 */
export declare function migrate(projectRoot?: string, dbPath?: string): MigrationResult;
//# sourceMappingURL=migration.d.ts.map