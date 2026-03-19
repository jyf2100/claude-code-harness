/**
 * core/src/state/store.ts
 * Harness v3 SQLite ストア
 *
 * better-sqlite3 を使って sessions / signals / task_failures / work_states
 * テーブルを操作するラッパークラス。
 * 同期 API（better-sqlite3 の特性）を活用し、単純で堅牢な実装とする。
 */
import type { Signal, SessionState, TaskFailure } from "../types.js";
export declare class HarnessStore {
    private readonly db;
    constructor(dbPath: string);
    private initSchema;
    /** セッションを登録または更新する */
    upsertSession(session: SessionState): void;
    /** セッションを終了済みにする */
    endSession(sessionId: string): void;
    /** セッション情報を取得する */
    getSession(sessionId: string): SessionState | null;
    /** シグナルを送信する */
    sendSignal(signal: Omit<Signal, "timestamp">): number;
    /** 未消費のシグナルを受信する（宛先 = sessionId またはブロードキャスト） */
    receiveSignals(sessionId: string): Signal[];
    /** タスク失敗を記録する */
    recordFailure(failure: Omit<TaskFailure, "timestamp">, sessionId: string): number;
    /** タスクの失敗履歴を取得する */
    getFailures(taskId: string): TaskFailure[];
    /** work/codex モードを登録する（TTL 24 時間） */
    setWorkState(sessionId: string, options?: {
        codexMode?: boolean;
        bypassRmRf?: boolean;
        bypassGitPush?: boolean;
    }): void;
    /** 有効な work_state を取得する（期限切れは null） */
    getWorkState(sessionId: string): {
        codexMode: boolean;
        bypassRmRf: boolean;
        bypassGitPush: boolean;
    } | null;
    /** 期限切れの work_states を削除する */
    cleanExpiredWorkStates(): number;
    /** schema_meta テーブルから値を取得する（存在しない場合は null） */
    getMeta(key: string): string | null;
    /** schema_meta テーブルに値を保存する（upsert） */
    setMeta(key: string, value: string): void;
    close(): void;
}
//# sourceMappingURL=store.d.ts.map