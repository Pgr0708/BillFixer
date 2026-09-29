import { Router } from 'express';
import { ping } from '../lib/db.js';
import { redisStatus } from '../lib/redis.js';
import { llmStatus } from '../services/llmService.js';

export const health = Router();

/** Liveness: the process is up. PM2/nginx use this; never touches dependencies. */
health.get('/health/live', (_req, res) => res.json({ status: 'ok', uptimeSeconds: Math.round(process.uptime()) }));

/** Readiness: MySQL is required; Redis and the LLM are optional and only mark "degraded". */
health.get('/health/ready', async (_req, res) => {
  let dbMs = null;
  let dbOk = false;
  try {
    dbMs = await Promise.race([ping(), new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 2000))]);
    dbOk = true;
  } catch {
    dbOk = false;
  }
  const redis = redisStatus();
  const llm = llmStatus();
  const status = !dbOk ? 'down' : redis === 'down' || llm === 'open' ? 'degraded' : 'ok';
  res.status(dbOk ? 200 : 503).json({ status, checks: { database: dbOk ? 'up' : 'down', databaseLatencyMs: dbMs, redis, llm } });
});
