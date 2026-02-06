import type { CsvParseOptions, CsvParseResult, CsvError } from './types';

/**
 * Parse a CSV string into structured data.
 */
export function parseCsv(input: string, options?: CsvParseOptions): CsvParseResult {
  const delimiter = options?.delimiter ?? ',';
  const hasHeader = options?.hasHeader ?? true;
  const skipEmpty = options?.skipEmpty ?? true;
  const trimValues = options?.trimValues ?? true;

  const errors: CsvError[] = [];
  const rows: Record<string, string>[] = [];

  if (!input || input.trim() === '') {
    return { headers: [], rows: [], errors: [] };
  }

  // Split into lines
  const lines = input.split('\n');

  // TODO: extract headers from first line (if hasHeader is true)
  //   - split by delimiter
  //   - trim each header if trimValues
  // TODO: if no header, generate headers like "col0", "col1", ...

  let headers: string[] = [];
  let startLine = 0;

  // TODO: set headers and startLine based on hasHeader flag

  // Process data rows
  for (let i = startLine; i < lines.length; i++) {
    const line = lines[i];

    // TODO: skip empty lines if skipEmpty is true
    // TODO: parse the line respecting quoted values
    //   - fields inside double quotes can contain delimiters and newlines
    //   - escaped quotes ("") inside quoted fields
    // TODO: trim values if trimValues is true
    // TODO: if field count doesn't match header count, add to errors
    // TODO: create record mapping headers to values and add to rows
  }

  return { headers, rows, errors };
}
