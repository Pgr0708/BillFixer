import { verifyAccessToken } from '../lib/jwt.js';
import { unauthorized, paymentRequired } from '../lib/errors.js';
import { getTier } from '../services/subscriptionService.js';

export async function requireAuth(req, _res, next) {
  const header = req.get('authorization') || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) return next(unauthorized('Please sign in to continue.', 'AUTH_REQUIRED'));
  try {
    const payload = await verifyAccessToken(token);
    req.user = { id: payload.sub };
    // Memoised per request; the tier itself is cached for 60s in the cache layer.
    let tierPromise;
    req.tier = () => (tierPromise ??= getTier(payload.sub));
    return next();
  } catch (err) {
    return next(err);
  }
}

/** Server-side premium gate — the app's own view of the tier is never trusted alone. */
export const requirePremium = (feature) => async (req, _res, next) => {
  try {
    const tier = await req.tier();
    if (tier.tier !== 'premium') return next(paymentRequired(feature));
    return next();
  } catch (err) {
    return next(err);
  }
};
