import { query, one, transaction } from '../lib/db.js';
import { uuid } from '../lib/ids.js';

const USER_COLS = `u.id, u.email, u.email_verified, u.apple_sub, u.display_name, u.created_at,
  EXISTS (SELECT 1 FROM user_credentials c WHERE c.user_id = u.id) AS has_password`;

export const findById = (id) => one(`SELECT ${USER_COLS} FROM users u WHERE u.id = ?`, [id]);
export const findByEmail = (email) => one(`SELECT ${USER_COLS} FROM users u WHERE u.email = ?`, [email]);
export const findByAppleSub = (sub) => one(`SELECT ${USER_COLS} FROM users u WHERE u.apple_sub = ?`, [sub]);

export async function createAppleUser({ appleSub, email, emailVerified, displayName }) {
  const id = uuid();
  await query(
    'INSERT INTO users (id, email, email_verified, apple_sub, display_name) VALUES (?, ?, ?, ?, ?)',
    [id, email, emailVerified ? 1 : 0, appleSub, displayName],
  );
  return findById(id);
}

export async function createEmailUser({ email, passwordHash, displayName }) {
  const id = uuid();
  await transaction(async ({ q }) => {
    await q('INSERT INTO users (id, email, display_name) VALUES (?, ?, ?)', [id, email, displayName]);
    await q('INSERT INTO user_credentials (user_id, password_hash) VALUES (?, ?)', [id, passwordHash]);
  });
  return findById(id);
}

export const linkAppleSub = (userId, appleSub) =>
  query('UPDATE users SET apple_sub = ? WHERE id = ? AND apple_sub IS NULL', [appleSub, userId]);

export const getPasswordHash = async (userId) =>
  (await one('SELECT password_hash FROM user_credentials WHERE user_id = ?', [userId]))?.password_hash ?? null;

export const setPasswordHash = (userId, hash) =>
  query(`INSERT INTO user_credentials (user_id, password_hash) VALUES (?, ?)
         ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash)`, [userId, hash]);

export const updateDisplayName = (userId, displayName) =>
  query('UPDATE users SET display_name = ? WHERE id = ?', [displayName, userId]);

export const touchActive = (userId) =>
  query('UPDATE users SET last_active_at = UTC_TIMESTAMP() WHERE id = ? AND (last_active_at IS NULL OR last_active_at < UTC_TIMESTAMP() - INTERVAL 1 HOUR)', [userId]);

/** Hard delete — foreign keys cascade to every table holding this user's data. */
export const deleteUser = (userId) => query('DELETE FROM users WHERE id = ?', [userId]);
