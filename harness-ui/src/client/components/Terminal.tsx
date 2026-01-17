import { useEffect, useRef, useImperativeHandle, forwardRef } from 'react';
import { Terminal as XTerm } from 'xterm';
import { FitAddon } from 'xterm-addon-fit';
import 'xterm/css/xterm.css';

export interface TerminalHandle {
  write: (data: string) => void;
  focus: () => void;
  reset: () => void;
  fit: () => void;
}

interface TerminalProps {
  sessionId: string;
  onInput: (data: string) => void;
  onResize: (cols: number, rows: number) => void;
}

export const Terminal = forwardRef<TerminalHandle, TerminalProps>(function Terminal(
  { sessionId, onInput, onResize },
  ref
) {
  const containerRef = useRef<HTMLDivElement>(null);
  const terminalRef = useRef<XTerm | null>(null);
  const fitAddonRef = useRef<FitAddon | null>(null);
  const onInputRef = useRef(onInput);
  const onResizeRef = useRef(onResize);

  useEffect(() => {
    onInputRef.current = onInput;
  }, [onInput]);

  useEffect(() => {
    onResizeRef.current = onResize;
  }, [onResize]);

  // Expose write and focus methods to parent
  useImperativeHandle(ref, () => ({
    write: (data: string) => {
      if (terminalRef.current) {
        terminalRef.current.write(data);
      }
    },
    focus: () => {
      if (terminalRef.current) {
        terminalRef.current.focus();
      }
    },
    reset: () => {
      if (terminalRef.current) {
        terminalRef.current.reset();
      }
    },
    fit: () => {
      if (fitAddonRef.current) {
        fitAddonRef.current.fit();
        if (terminalRef.current) {
          terminalRef.current.refresh(0, terminalRef.current.rows - 1);
        }
      }
    },
  }), []);

  // Initialize terminal
  useEffect(() => {
    if (!containerRef.current || terminalRef.current) return;

    const terminal = new XTerm({
      theme: {
        background: '#000000',
        foreground: '#e0e0e0',
        cursor: '#e0e0e0',
        cursorAccent: '#000000',
        selectionBackground: '#3a3a3a',
      },
      fontSize: 13,
      fontFamily: 'Menlo, Monaco, monospace',
      cursorBlink: true,
      scrollback: 5000,
    });

    const fitAddon = new FitAddon();
    terminal.loadAddon(fitAddon);

    terminal.open(containerRef.current);
    fitAddon.fit();

    terminalRef.current = terminal;
    fitAddonRef.current = fitAddon;

    // Handle input
    terminal.onData((data) => {
      onInputRef.current(data);
    });

    // Notify initial size
    onResizeRef.current(terminal.cols, terminal.rows);

    // Handle resize
    const resizeObserver = new ResizeObserver(() => {
      if (fitAddonRef.current) {
        fitAddonRef.current.fit();
        if (terminalRef.current) {
          onResizeRef.current(terminalRef.current.cols, terminalRef.current.rows);
        }
      }
    });

    resizeObserver.observe(containerRef.current);

    return () => {
      resizeObserver.disconnect();
      terminal.dispose();
      terminalRef.current = null;
      fitAddonRef.current = null;
    };
  }, [sessionId]);

  return <div ref={containerRef} style={{ width: '100%', height: '100%' }} />;
});
