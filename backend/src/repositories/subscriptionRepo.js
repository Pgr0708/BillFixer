import { query, one } from '../lib/db.js';
import { uuid } from '../lib/ids.js';

export const getByUser = (userId) =>
  one('SELECT status, product_id, entitlement, store, expires_at, grace_period_expires, last_synced_at FROM subscriptions WHERE user_id = ?', [userId], { read: true });

export const upsert = ({ userId, status, productId, entitlement, store, expiresAt, gracePeriodExpires }) =>
  query(
    `INSERT INTO subscriptions (id, user_id, status, product_id, entitlement, store, expires_at, grace_period_expires, last_synced_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, UTC_TIMESTAMP())
     ON DUPLICATE KEY UPDATE status = VALUES(status), product_id = VALUES(product_id), entitlement = VALUES(entitlement),
       store = VALUES(store), expires_at = VALUES(expires_at), grace_period_expires = VALUES(grace_period_expires),
       last_synced_at = VALUES(last_synced_at)`,
    [uuid(), userId, status, productId, entitlement, store, expiresAt, gracePeriodExpires],
  );
