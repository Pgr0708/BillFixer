import { logger } from './logger.js';

/**
 * Rolling-window circuit breaker. Opens when the failure ratio over the window crosses
 * the threshold (with a minimum sample size), then half-opens after `openMs` to probe.
 */
export class CircuitBreaker {
  constructor(name, { windowMs = 5 * 60_000, failureRatio = 0.2, minSamples = 10, openMs = 60_000 } = {}) {
    Object.assign(this, { name, windowMs, failureRatio, minSamples, openMs });
    this.events = []; // [timestamp, ok]
    this.state = 'closed';
    this.openedAt = 0;
  }

  #prune(now) {
    const cutoff = now - this.windowMs;
    while (this.events.length && this.events[0][0] < cutoff) this.events.shift();
  }

  canRequest() {
    if (this.state === 'open' && Date.now() - this.openedAt >= this.openMs) {
      this.state = 'half_open';
      logger.info({ breaker: this.name }, 'circuit half-open');
    }
    return this.state !== 'open';
  }

  record(ok) {
    const now = Date.now();
    this.events.push([now, ok]);
    this.#prune(now);
    if (this.state === 'half_open') {
      this.state = ok ? 'closed' : 'open';
      if (!ok) this.openedAt = now;
      logger.info({ breaker: this.name, state: this.state }, 'circuit probe result');
      return;
    }
    const failures = this.events.filter(([, success]) => !success).length;
    if (this.events.length >= this.minSamples && failures / this.events.length > this.failureRatio) {
      this.state = 'open';
      this.openedAt = now;
      logger.warn({ breaker: this.name, failures, samples: this.events.length }, 'circuit opened');
    }
  }

  status() {
    return this.state;
  }
}
