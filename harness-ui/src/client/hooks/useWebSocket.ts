import { useEffect, useRef, useCallback, useState } from 'react';
import type {
  WSMessage,
  PTYSession,
  PlansData,
  SessionsListPayload,
  SessionUpdatePayload,
  LogChunkPayload,
} from '@shared/types';

interface UseWebSocketOptions {
  onSessionsUpdate?: (sessions: PTYSession[]) => void;
  onLogChunk?: (sessionId: string, data: string) => void;
  onPlansUpdate?: (data: PlansData) => void;
}

export function useWebSocket(options: UseWebSocketOptions = {}) {
  const handlersRef = useRef<UseWebSocketOptions>(options);
  const wsRef = useRef<WebSocket | null>(null);
  const [connected, setConnected] = useState(false);
  const [sessions, setSessions] = useState<PTYSession[]>([]);
  const reconnectTimeoutRef = useRef<number | null>(null);

  useEffect(() => {
    handlersRef.current = options;
  }, [options.onSessionsUpdate, options.onLogChunk, options.onPlansUpdate]);

  const connect = useCallback(() => {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.host}/ws`;

    const ws = new WebSocket(wsUrl);
    wsRef.current = ws;

    ws.onopen = () => {
      console.log('WebSocket connected');
      setConnected(true);
    };

    ws.onclose = () => {
      console.log('WebSocket disconnected');
      setConnected(false);

      // Reconnect after 2 seconds
      reconnectTimeoutRef.current = window.setTimeout(() => {
        connect();
      }, 2000);
    };

    ws.onerror = (error) => {
      console.error('WebSocket error:', error);
    };

    ws.onmessage = (event) => {
      try {
        const message = JSON.parse(event.data) as WSMessage;

        switch (message.type) {
          case 'sessions_list': {
            const { sessions: newSessions } = message.payload as SessionsListPayload;
            setSessions(newSessions);
            handlersRef.current.onSessionsUpdate?.(newSessions);
            break;
          }

          case 'session_update': {
            const { session } = message.payload as SessionUpdatePayload;
            setSessions((prev) => {
              const idx = prev.findIndex((s) => s.id === session.id);
              if (idx >= 0) {
                const updated = [...prev];
                updated[idx] = session;
                return updated;
              }
              return [...prev, session];
            });
            break;
          }

          case 'log_chunk': {
            const { sessionId, data } = message.payload as LogChunkPayload;
        setSessions((prev) => {
          const idx = prev.findIndex((s) => s.id === sessionId);
          if (idx < 0) return prev;
          const current = prev[idx];
          const nextLogs = [...(current.logs || []), data];
          if (nextLogs.length > 1000) {
            nextLogs.splice(0, nextLogs.length - 500);
          }
          const updatedSession = { ...current, logs: nextLogs };
          const updated = [...prev];
          updated[idx] = updatedSession;
          return updated;
        });
            handlersRef.current.onLogChunk?.(sessionId, data);
            break;
          }

          case 'plans_update': {
            const data = message.payload as PlansData;
            handlersRef.current.onPlansUpdate?.(data);
            break;
          }
        }
      } catch (error) {
        console.error('Failed to parse message:', error);
      }
    };
  }, []);

  useEffect(() => {
    connect();

    return () => {
      if (reconnectTimeoutRef.current) {
        clearTimeout(reconnectTimeoutRef.current);
      }
      if (wsRef.current) {
        wsRef.current.close();
      }
    };
  }, [connect]);

  const send = useCallback(<T,>(message: WSMessage<T>) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify(message));
    }
  }, []);

  const sendInput = useCallback(
    (sessionId: string, data: string) => {
      send({ type: 'send_input', payload: { sessionId, data } });
    },
    [send]
  );

  const createSession = useCallback(
    (projectId: string, worktreePath?: string) => {
      send({ type: 'create_session', payload: { projectId, worktreePath } });
    },
    [send]
  );

  const destroySession = useCallback(
    (sessionId: string) => {
      send({ type: 'destroy_session', payload: { sessionId } });
    },
    [send]
  );

  const resizeTerminal = useCallback(
    (sessionId: string, cols: number, rows: number) => {
      send({ type: 'resize_terminal', payload: { sessionId, cols, rows } });
    },
    [send]
  );

  return {
    connected,
    sessions,
    sendInput,
    createSession,
    destroySession,
    resizeTerminal,
  };
}
