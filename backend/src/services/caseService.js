import { notFound, paymentRequired } from '../lib/errors.js';
import { config } from '../config/index.js';
import * as cases from '../repositories/caseRepo.js';

/** Load a case the caller owns, or 404 (never 403 — don't reveal that the id exists). */
export async function requireOwnedCase(userId, caseId) {
  const row = await cases.getOwned(userId, caseId);
  if (!row) throw notFound('Case');
  return row;
}

export async function assertCanCreateCase(req) {
  const tier = await req.tier();
  if (tier.tier === 'premium') return;
  if ((await cases.countActive(req.user.id)) >= config.limits.freeActiveCases) throw paymentRequired('more than one active case');
}
