import { LRUCache } from 'lru-cache';
import { safe } from './redis.js';

/**
 * Two-level cache: in-process LRU (L1, microseconds) → Redis (L2, shared across processes/servers).
 * Namespaces are versioned (`cachever:<ns>`) so the data pipeline can invalidate everything
 * in a namespace with a single INCR — no KEYS/SCAN in production.
 */
const l1 = new LRUCache({ max: 5000, ttl: 30_000, ttlAutopurge: false });
const inflight = new Map(); // single-flight: concurrent misses share one loader call

async function nsVersion(ns) {
  return safe(async (r) => (await r.get(`cachever:${ns}`)) || '0', '0');
}

export async function getOrSet(ns, key, ttlSeconds, loader) {
  const version = await nsVersion(ns);
  const fullKey = `c:${ns}:v${version}:${key}`;

  const local = l1.get(fullKey);
  if (local !== undefined) return local;

  const remote = await safe(async (r) => {
    const raw = await r.get(fullKey);
    return raw === null ? undefined : JSON.parse(raw);
  }, undefined);
  if (remote !== undefined) {
    l1.set(fullKey, remote, { ttl: Math.min(ttlSeconds, 30) * 1000 });
    return remote;
  }

  if (inflight.has(fullKey)) return inflight.get(fullKey);
  const promise = (async () => {
    try {
      const value = await loader();
      if (value !== undefined) {
        l1.set(fullKey, value, { ttl: Math.min(ttlSeconds, 30) * 1000 });
        await safe((r) => r.set(fullKey, JSON.stringify(value), 'EX', ttlSeconds), null);
      }
      return value;
    } finally {
      inflight.delete(fullKey);
    }
  })();
  inflight.set(fullKey, promise);
  return promise;
}

/** Drop one key (current version) from both levels. */
export async function invalidate(ns, key) {
  const version = await nsVersion(ns);
  const fullKey = `c:${ns}:v${version}:${key}`;
  l1.delete(fullKey);
  await safe((r) => r.del(fullKey), null);
}

/** Invalidate an entire namespace everywhere. */
export async function bumpNamespace(ns) {
  l1.clear();
  await safe((r) => r.incr(`cachever:${ns}`), null);
}
