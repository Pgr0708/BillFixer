import { query, one, transaction } from '../lib/db.js';
import { uuid } from '../lib/ids.js';

export async function insertRefreshToken({ userId, tokenHash, familyId, expiresAt, userAgent }) {
  const id = uuid();
  await query(
    'INSERT INTO refresh_tokens (id, user_id, token_hash, family_id, expires_at, user_agent) VALUES (?, ?, ?, ?, ?, ?)',
    [id, userId, tokenHash, familyId, expiresAt, userAgent?.slice(0, 200) ?? null],
  );
  return id;
}

/**
 * Rotate atomically. Returns { status: 'ok'|'invalid'|'reused'|'expired', userId, familyId }.
 * Presenting an already-rotated token means it leaked: the whole family is revoked.
 */
export async function consumeRefreshToken(tokenHash, newRecord) {
  return transaction(async ({ q }) => {
    const [row] = await q(
      'SELECT id, user_id, family_id, expires_at, revoked_at FROM refresh_tokens WHERE token_hash = ? FOR UPDATE',
      [tokenHash],
    );
    if (!row) return { status: 'invalid' };
    if (row.revoked_at) {
      await q('UPDATE refresh_tokens SET revoked_at = UTC_TIMESTAMP() WHERE family_id = ? AND revoked_at IS NULL', [row.family_id]);
      return { status: 'reused', userId: row.user_id };
    }
    if (new Date(row.expires_at) <= new Date()) return { status: 'expired', userId: row.user_id };

    const newId = uuid();
    await q(
      'INSERT INTO refresh_tokens (id, user_id, token_hash, family_id, expires_at, user_agent) VALUES (?, ?, ?, ?, ?, ?)',
      [newId, row.user_id, newRecord.tokenHash, row.family_id, newRecord.expiresAt, newRecord.userAgent?.slice(0, 200) ?? null],
    );
    await q('UPDATE refresh_tokens SET revoked_at = UTC_TIMESTAMP(), replaced_by = ? WHERE id = ?', [newId, row.id]);
    return { status: 'ok', userId: row.user_id, familyId: row.family_id };
  });
}

export const revokeByHash = (tokenHash) =>
  query('UPDATE refresh_tokens SET revoked_at = UTC_TIMESTAMP() WHERE token_hash = ? AND revoked_at IS NULL', [tokenHash]);

export const revokeAllForUser = (userId) =>
  query('UPDATE refresh_tokens SET revoked_at = UTC_TIMESTAMP() WHERE user_id = ? AND revoked_at IS NULL', [userId]);

export async function insertResetCode({ userId, codeHash, expiresAt }) {
  await query('UPDATE password_reset_codes SET used_at = UTC_TIMESTAMP() WHERE user_id = ? AND used_at IS NULL', [userId]);
  await query('INSERT INTO password_reset_codes (id, user_id, code_hash, expires_at) VALUES (?, ?, ?, ?)',
    [uuid(), userId, codeHash, expiresAt]);
}

export const latestResetCode = (userId) =>
  one(`SELECT id, code_hash, attempts FROM password_reset_codes
        WHERE user_id = ? AND used_at IS NULL AND expires_at > UTC_TIMESTAMP()
        ORDER BY created_at DESC LIMIT 1`, [userId]);

export const bumpResetAttempts = (id) => query('UPDATE password_reset_codes SET attempts = attempts + 1 WHERE id = ?', [id]);
export const markResetUsed = (id) => query('UPDATE password_reset_codes SET used_at = UTC_TIMESTAMP() WHERE id = ?', [id]);
export const recentResetCount = async (userId) =>
  Number((await one('SELECT COUNT(*) AS n FROM password_reset_codes WHERE user_id = ? AND created_at > UTC_TIMESTAMP() - INTERVAL 1 HOUR', [userId]))?.n ?? 0);
