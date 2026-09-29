import { toCents } from '../lib/money.js';
import { logger } from '../lib/logger.js';
import { estimate as fplEstimate } from './fplService.js';
import { startAnalysis } from './analysisService.js';
import * as profiles from '../repositories/profileRepo.js';
import * as jobs from '../repositories/jobRepo.js';

const toApi = (row) => row ? {
  householdSize: Number(row.household_size),
  annualIncome: String(row.annual_income),
  state: row.state ?? null,
  updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
} : null;

async function estimateFor(p) {
  if (!p) return null;
  const r = await fplEstimate({ householdSize: p.householdSize, annualIncomeCents: toCents(p.annualIncome), state: p.state ?? undefined });
  return { year: r.year, region: r.region, householdSize: r.householdSize, guideline: (r.guidelineCents / 100).toFixed(2), fplPercent: r.pct,
    sourceUrl: 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines' };
}

export async function getProfile(userId) {
  const profile = toApi(await profiles.get(userId));
  return { profile, estimate: await estimateFor(profile).catch(() => null) };
}

/**
 * Save the profile, then re-check every unresolved case with a bill so "You may qualify for help" is
 * recalculated with the new numbers. Each case keeps its own answers (emergency, insurance…) from its last run.
 */
export async function saveProfile(userId, body) {
  await profiles.upsert(userId, body);
  const saved = toApi(await profiles.get(userId));
  let rechecked = 0;
  for (const { id: caseId } of await profiles.openCasesWithBill(userId)) {
    try {
      const last = await jobs.latestForCase(caseId, 'analysis');
      const payload = typeof last?.payload === 'string' ? JSON.parse(last.payload) : (last?.payload ?? {});
      const context = { ...(payload.context ?? {}), householdSize: saved.householdSize, annualIncome: saved.annualIncome, state: saved.state ?? undefined };
      await startAnalysis(userId, caseId, context);
      rechecked += 1;
    } catch (err) {
      logger.warn({ caseId, err: err.message }, 'profile recheck skipped a case');
    }
  }
  return { profile: saved, estimate: await estimateFor(saved).catch(() => null), recheckedCases: rechecked };
}

export const deleteProfile = (userId) => profiles.remove(userId);
