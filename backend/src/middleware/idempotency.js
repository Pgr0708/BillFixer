import { createHash } from 'node:crypto';
import { query, one } from '../lib/db.js';
import { conflict, unprocessable } from '../lib/errors.js';
import { logger } from '../lib/logger.js';

const KEY_RE = /^[A-Za-z0-9-]{16,64}$/;

/**
 * Idempotency for retried POSTs (flaky mobile networks). With an `Idempotency-Key` header:
 *  - first request is recorded and its response stored
 *  - a replay with the same body returns the stored response
 *  - a concurrent duplicate gets 409, a reused key with a different body gets 422
 */
export async function idempotency(req, res, next) {
  const key = req.get('idempotency-key');
  if (!key || !req.user) return next();
  if (!KEY_RE.test(key)) return next(unprocessable({ header: 'Idempotency-Key must be 16–64 chars [A-Za-z0-9-]' }));

  const hash = createHash('sha256').update(`${req.method} ${req.originalUrl} ${JSON.stringify(req.body ?? {})}`).digest('hex');
  try {
    const existing = await one(
      'SELECT request_hash, status_code, response_body FROM idempotency_keys WHERE user_id = ? AND idem_key = ?',
      [req.user.id, key],
    );
    if (existing) {
      if (existing.request_hash !== hash) return next(unprocessable({ header: 'Idempotency-Key reused with a different request' }));
      if (existing.status_code === null) return next(conflict('This request is already being processed.', 'IN_PROGRESS'));
      res.setHeader('Idempotent-Replay', 'true');
      const body = typeof existing.response_body === 'string' ? JSON.parse(existing.response_body) : existing.response_body;
      return res.status(existing.status_code).json(body);
    }
    await query('INSERT INTO idempotency_keys (user_id, idem_key, request_hash) VALUES (?, ?, ?)', [req.user.id, key, hash]);
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') return next(conflict('This request is already being processed.', 'IN_PROGRESS'));
    return next(err);
  }

  const originalJson = res.json.bind(res);
  res.json = (body) => {
    const status = res.statusCode;
    const persist = status < 500
      ? query('UPDATE idempotency_keys SET status_code = ?, response_body = ? WHERE user_id = ? AND idem_key = ?',
        [status, JSON.stringify(body ?? null), req.user.id, key])
      : query('DELETE FROM idempotency_keys WHERE user_id = ? AND idem_key = ?', [req.user.id, key]); // allow retry after 5xx
    persist.catch((err) => logger.warn({ err: err.message }, 'idempotency persist failed'));
    return originalJson(body);
  };
  return next();
}
