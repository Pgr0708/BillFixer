import { query, one } from '../lib/db.js';
import { uuid } from '../lib/ids.js';

export async function create({ userId, caseId, type, steps, payload }) {
  const id = uuid();
  await query('INSERT INTO jobs (id, user_id, case_id, type, steps, payload) VALUES (?, ?, ?, ?, ?, ?)',
    [id, userId, caseId ?? null, type, JSON.stringify(steps ?? []), JSON.stringify(payload ?? {})]);
  return id;
}
export const get = (id) => one('SELECT * FROM jobs WHERE id = ?', [id]);
export const getOwned = (userId, id) => one('SELECT * FROM jobs WHERE id = ? AND user_id = ?', [id, userId]);
export const latestForCase = (caseId, type) =>
  one('SELECT * FROM jobs WHERE case_id = ? AND type = ? ORDER BY created_at DESC LIMIT 1', [caseId, type]);
export const activeForCase = (caseId, type) =>
  one("SELECT id FROM jobs WHERE case_id = ? AND type = ? AND status IN ('queued','running') LIMIT 1", [caseId, type]);

export const markRunning = (id) => query("UPDATE jobs SET status = 'running', started_at = UTC_TIMESTAMP() WHERE id = ?", [id]);
export const updateProgress = (id, progress, steps) =>
  query('UPDATE jobs SET progress = ?, steps = ? WHERE id = ?', [progress.toFixed(3), JSON.stringify(steps), id]);
export const complete = (id, resultType, resultId, steps) =>
  query(`UPDATE jobs SET status = 'complete', progress = 1, result_type = ?, result_id = ?, steps = ?,
         finished_at = UTC_TIMESTAMP() WHERE id = ?`, [resultType, resultId, JSON.stringify(steps), id]);
export const fail = (id, errorCode, steps) =>
  query("UPDATE jobs SET status = 'failed', error_code = ?, steps = COALESCE(?, steps), finished_at = UTC_TIMESTAMP() WHERE id = ?",
    [errorCode.slice(0, 60), steps ? JSON.stringify(steps) : null, id]);

/** A job whose worker died stops updating; fail it so the app can retry instead of spinning. */
export const sweepStale = () =>
  query(`UPDATE jobs SET status = 'failed', error_code = 'WORKER_LOST', finished_at = UTC_TIMESTAMP()
         WHERE status IN ('queued','running') AND updated_at < UTC_TIMESTAMP() - INTERVAL 3 MINUTE`);
