import { safe } from '../lib/redis.js';
import { tooManyRequests } from '../lib/errors.js';

/**
 * Fixed-window rate limiter. Shared across processes/servers through Redis;
 * degrades to a per-process in-memory window when Redis is unavailable,
 * so limits still apply (just per-process) and requests are never blocked by an outage.
 */
const memory = new Map(); // key -> { count, resetAt }
setInterval(() => {
  const now = Date.now();
  for (const [k, v] of memory) if (v.resetAt <= now) memory.delete(k);
}, 60_000).unref();

function memoryHit(key, windowSec) {
  const now = Date.now();
  let entry = memory.get(key);
  if (!entry || entry.resetAt <= now) {
    entry = { count: 0, resetAt: now + windowSec * 1000 };
    memory.set(key, entry);
  }
  entry.count += 1;
  return { count: entry.count, ttlMs: entry.resetAt - now };
}

export function rateLimit({ name, windowSec, max, key = (req) => req.ip }) {
  return async (req, res, next) => {
    const id = key(req);
    if (!id) return next();
    const bucket = Math.floor(Date.now() / (windowSec * 1000));
    const redisKey = `rl:${name}:${id}:${bucket}`;

    const { count, ttlMs } = await safe(
      async (r) => {
        const [[, c], [, ttl]] = await r.multi().incr(redisKey).pttl(redisKey).exec();
        if (ttl < 0) await r.pexpire(redisKey, windowSec * 1000);
        return { count: c, ttlMs: ttl < 0 ? windowSec * 1000 : ttl };
      },
      () => memoryHit(redisKey, windowSec),
    );

    const resetSec = Math.max(1, Math.ceil(ttlMs / 1000));
    res.setHeader('RateLimit-Limit', String(max));
    res.setHeader('RateLimit-Remaining', String(Math.max(0, max - count)));
    res.setHeader('RateLimit-Reset', String(resetSec));
    if (count > max) {
      res.setHeader('Retry-After', String(resetSec));
      return next(tooManyRequests(resetSec));
    }
    return next();
  };
}

/** Key by authenticated user when present, else by IP. */
export const byUserOrIp = (req) => req.user?.id || req.ip;
