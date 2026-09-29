import { Router } from 'express';
import { timingSafeEqual } from 'node:crypto';
import { config } from '../config/index.js';
import { logger } from '../lib/logger.js';
import { unauthorized } from '../lib/errors.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { syncFromRevenueCat, handleRevenueCatEvent } from '../services/subscriptionService.js';

export const subscriptionRoutes = Router();

subscriptionRoutes.get('/subscription/status', async (req, res) => {
  res.set('Cache-Control', 'no-store');
  res.json(await req.tier());
});

/** Called by the app after a purchase/restore. Verifies with RevenueCat — the app's claim alone is never trusted. */
subscriptionRoutes.post('/subscription/validate', rateLimit({ name: 'subvalidate', windowSec: 300, max: 20, key: (req) => req.user.id }),
  async (req, res) => {
    res.json(await syncFromRevenueCat(req.user.id));
  });

export const webhookRoutes = Router();

function authorized(header) {
  const expected = config.revenueCat.webhookAuth;
  if (!expected || !header) return false;
  const a = Buffer.from(String(header).replace(/^Bearer\s+/i, ''));
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

webhookRoutes.post('/webhooks/revenuecat', rateLimit({ name: 'webhook', windowSec: 60, max: 600 }), async (req, res) => {
  if (!authorized(req.get('authorization'))) throw unauthorized('Invalid webhook credentials.', 'WEBHOOK_UNAUTHORIZED');
  const result = await handleRevenueCatEvent(req.body?.event);
  logger.info({ type: req.body?.event?.type, ...result }, 'revenuecat webhook');
  res.json({ received: true }); // always 200 once authenticated so RevenueCat doesn't retry forever
});
