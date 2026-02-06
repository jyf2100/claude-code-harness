import type { RateLimiter, RateLimiterOptions } from './types';

export class TokenBucketLimiter implements RateLimiter {
  private tokens: number;
  private maxTokens: number;
  private refillRate: number;
  private lastRefillTime: number;

  constructor(options: RateLimiterOptions) {
    this.maxTokens = options.maxTokens;
    this.tokens = options.maxTokens;
    this.refillRate = options.refillRate;
    this.lastRefillTime = Date.now();
  }

  private refill(): void {
    const now = Date.now();
    const elapsed = (now - this.lastRefillTime) / 1000; // seconds
    // TODO: calculate tokens to add = elapsed * this.refillRate
    // TODO: add tokens but cap at this.maxTokens (use Math.min)
    // TODO: update this.lastRefillTime = now
  }

  tryConsume(tokens: number = 1): boolean {
    this.refill();
    // TODO: if this.tokens >= tokens, deduct and return true
    // TODO: otherwise return false
    throw new Error('Not implemented');
  }

  getAvailableTokens(): number {
    this.refill();
    // TODO: return Math.floor(this.tokens)
    throw new Error('Not implemented');
  }

  reset(): void {
    // TODO: reset tokens to maxTokens and lastRefillTime to Date.now()
    throw new Error('Not implemented');
  }
}
