import { logger } from '../lib/logger.js';
import * as jobs from '../repositories/jobRepo.js';

/**
 * In-process job runner with bounded concurrency. Job *state* lives in MySQL, so any
 * worker/server can answer status polls, and a crashed worker's job is failed by the
 * sweeper (and the app can retry) instead of hanging forever.
 */
const MAX_CONCURRENT = 4;
let running = 0;
let accepting = true;
const queue = [];
const active = new Set();

function pump() {
  while (accepting && running < MAX_CONCURRENT && queue.length) {
    const { jobId, handler } = queue.shift();
    running += 1;
    const p = (async () => {
      try {
        await jobs.markRunning(jobId);
        await handler(jobId);
      } catch (err) {
        logger.error({ jobId, err: err.message, stack: err.stack }, 'job failed');
        await jobs.fail(jobId, err.code || 'JOB_FAILED').catch(() => {});
      } finally {
        running -= 1;
        active.delete(p);
        pump();
      }
    })();
    active.add(p);
  }
}

export function enqueue(jobId, handler) {
  queue.push({ jobId, handler });
  setImmediate(pump);
}

let sweeper = null;
export function startSweeper() {
  sweeper = setInterval(() => {
    jobs.sweepStale().catch((err) => logger.warn({ err: err.message }, 'job sweep failed'));
  }, 60_000);
  sweeper.unref();
}

/** Graceful shutdown: stop taking work, let in-flight jobs finish (bounded). */
export async function drain(timeoutMs = 20_000) {
  accepting = false;
  if (sweeper) clearInterval(sweeper);
  for (const { jobId } of queue.splice(0)) await jobs.fail(jobId, 'SHUTDOWN').catch(() => {});
  await Promise.race([Promise.allSettled([...active]), new Promise((r) => setTimeout(r, timeoutMs))]);
}
