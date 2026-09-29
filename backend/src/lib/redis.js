import Redis from 'ioredis';
import { config } from '../config/index.js';
import { logger } from './logger.js';

/**
 * Redis is an accelerator, never a dependency. Every call goes through `safe()`,
 * which returns the fallback when Redis is disabled, disconnected, slow, or erroring.
 */
let client = null;
let ready = false;
let lastErrorLog = 0;

export function initRedis() {
  if (!config.redis.enabled || client) return client;
  client = new Redis(config.redis.url, {
    keyPrefix: config.redis.keyPrefix,
    lazyConnect: true,
    enableOfflineQueue: false, // fail fast instead of queueing while down
    maxRetriesPerRequest: 1,
    connectTimeout: 3000,
    commandTimeout: 1500,
    retryStrategy: (times) => Math.min(times * 500, 10_000),
    reconnectOnError: (err) => /READONLY|ETIMEDOUT/.test(err.message),
  });
  client.on('ready', () => {
    ready = true;
    logger.info('redis ready');
  });
  client.on('end', () => {
    ready = false;
  });
  client.on('error', (err) => {
    ready = false;
    const now = Date.now();
    if (now - lastErrorLog > 30_000) {
      lastErrorLog = now;
      logger.warn({ err: err.message }, 'redis unavailable — serving from fallbacks');
    }
  });
  client.connect().catch(() => {}); // retryStrategy keeps trying in the background
  return client;
}

export const redisReady = () => Boolean(client && ready);
export const redisStatus = () => (!config.redis.enabled ? 'disabled' : ready ? 'up' : 'down');

export async function safe(fn, fallback) {
  const fb = () => (typeof fallback === 'function' ? fallback() : fallback);
  if (!redisReady()) return fb();
  try {
    return await fn(client);
  } catch (err) {
    logger.debug({ err: err.message }, 'redis op failed, using fallback');
    return fb();
  }
}

export async function closeRedis() {
  if (!client) return;
  try {
    await client.quit();
  } catch {
    client.disconnect();
  }
}
