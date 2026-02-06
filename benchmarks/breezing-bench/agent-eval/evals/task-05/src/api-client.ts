export interface ApiResponse<T> {
  data: T;
  status: number;
}

export interface ApiClientOptions {
  baseUrl: string;
  timeout?: number;   // default 5000ms
  retries?: number;   // default 3
}

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
    public retryable: boolean
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export class ApiClient {
  private maxRetries: number;
  private timeout: number;

  constructor(private options: ApiClientOptions) {
    this.maxRetries = options.retries ?? 3;
    this.timeout = options.timeout ?? 5000;
  }

  async get<T>(path: string): Promise<ApiResponse<T>> {
    return this.requestWithRetry<T>('GET', path);
  }

  async post<T>(path: string, body: unknown): Promise<ApiResponse<T>> {
    return this.requestWithRetry<T>('POST', path, body);
  }

  private async requestWithRetry<T>(
    method: string,
    path: string,
    body?: unknown
  ): Promise<ApiResponse<T>> {
    let lastError: Error = new Error('Request failed');

    for (let attempt = 0; attempt <= this.maxRetries; attempt++) {
      try {
        // TODO: create AbortController for timeout
        // TODO: set up timeout with setTimeout + controller.abort()
        // TODO: build fetch options (method, headers, body, signal)
        // TODO: call fetch with the URL and options
        // TODO: clear the timeout
        // TODO: check response.ok
        //   - if 4xx: throw ApiError with retryable=false
        //   - if 5xx: throw ApiError with retryable=true
        // TODO: parse JSON and return { data, status }
        throw new Error('Not implemented');
      } catch (error) {
        lastError = error as Error;
        // TODO: if error is ApiError and not retryable, throw immediately (don't retry)
        // TODO: if this is the last attempt, throw
        // TODO: otherwise wait before retrying (exponential backoff: 2^attempt * 100ms)
      }
    }

    throw lastError;
  }
}
