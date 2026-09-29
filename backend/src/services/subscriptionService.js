import { config } from '../config/index.js';
import { logger } from '../lib/logger.js';
import { getOrSet, invalidate } from '../lib/cache.js';
import { toIso } from '../lib/time.js';
import { UUID_RE } from '../lib/ids.js';
import * as repo from '../repositories/subscriptionRepo.js';

/**
 * Tier is decided server-side from the subscriptions table (docs/infra/SUBSCRIPTIONS.md),
 * which is kept in sync with RevenueCat via REST verification and webhooks.
 */
function computeTier(row, now = new Date()) {
  if (!row) return { tier: 'free', productId: null, expiresAt: null, isInGracePeriod: false };
  const expires = row.expires_at ? new Date(row.expires_at) : null;
  const grace = row.grace_period_expires ? new Date(row.grace_period_expires) : null;
  const inGrace = row.status === 'in_grace' && grace && grace > now;
  const active = row.status === 'active' && (!expires || expires > now);
  return {
    tier: active || inGrace ? 'premium' : 'free',
    productId: row.product_id ?? null,
    expiresAt: toIso(expires),
    isInGracePeriod: Boolean(inGrace),
  };
}

export const getTier = (userId) => getOrSet('tier', userId, 60, async () => computeTier(await repo.getByUser(userId)));

async function fetchRevenueCatSubscriber(appUserId) {
  const res = await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`, {
    headers: { Authorization: `Bearer ${config.revenueCat.secretKey}`, Accept: 'application/json' },
    signal: AbortSignal.timeout(8000),
  });
  if (!res.ok) throw new Error(`RevenueCat HTTP ${res.status}`);
  return (await res.json()).subscriber;
}

/** Pull the canonical state from RevenueCat and store it. Never trusts what the app reports. */
export async function syncFromRevenueCat(userId) {
  if (!config.revenueCat.secretKey) {
    logger.warn('REVENUECAT_SECRET_KEY not set — cannot verify purchases server-side');
    return getTier(userId);
  }
  const subscriber = await fetchRevenueCatSubscriber(userId);
  const ent = subscriber?.entitlements?.[config.revenueCat.entitlement];
  const now = new Date();
  let record = { status: 'free', productId: null, store: null, expiresAt: null, gracePeriodExpires: null };
  if (ent) {
    const expires = ent.expires_date ? new Date(ent.expires_date) : null;
    const sub = subscriber.subscriptions?.[ent.product_identifier] ?? {};
    const grace = sub.grace_period_expires_date ? new Date(sub.grace_period_expires_date) : null;
    const status = !expires || expires > now ? 'active' : grace && grace > now ? 'in_grace' : 'expired';
    record = { status, productId: ent.product_identifier, store: sub.store ?? null, expiresAt: expires, gracePeriodExpires: grace };
  }
  await repo.upsert({ userId, entitlement: config.revenueCat.entitlement, ...record });
  await invalidate('tier', userId);
  return computeTier({ status: record.status, product_id: record.productId, expires_at: record.expiresAt, grace_period_expires: record.gracePeriodExpires });
}

/** RevenueCat webhook: find our user id, then re-sync from the REST API (source of truth). */
export async function handleRevenueCatEvent(event) {
  const candidates = [event?.app_user_id, event?.original_app_user_id, ...(event?.aliases ?? [])];
  const userId = candidates.find((id) => typeof id === 'string' && UUID_RE.test(id));
  if (!userId) return { handled: false, reason: 'no_app_user_id' };
  try {
    if (config.revenueCat.secretKey) {
      await syncFromRevenueCat(userId);
    } else {
      const expires = event.expiration_at_ms ? new Date(event.expiration_at_ms) : null;
      const grace = event.grace_period_expiration_at_ms ? new Date(event.grace_period_expiration_at_ms) : null;
      const status = event.type === 'EXPIRATION' ? 'expired'
        : event.type === 'BILLING_ISSUE' ? (grace ? 'in_grace' : 'expired')
          : ['INITIAL_PURCHASE', 'RENEWAL', 'UNCANCELLATION', 'PRODUCT_CHANGE', 'CANCELLATION', 'NON_RENEWING_PURCHASE', 'SUBSCRIPTION_EXTENDED'].includes(event.type)
            ? 'active' : null;
      if (!status) return { handled: false, reason: `ignored_${event.type}` };
      await repo.upsert({ userId, status, productId: event.product_id ?? null, entitlement: config.revenueCat.entitlement,
        store: event.store ?? null, expiresAt: expires, gracePeriodExpires: grace });
      await invalidate('tier', userId);
    }
    return { handled: true };
  } catch (err) {
    if (err.code === 'ER_NO_REFERENCED_ROW_2') return { handled: false, reason: 'unknown_user' }; // account deleted
    throw err;
  }
}
