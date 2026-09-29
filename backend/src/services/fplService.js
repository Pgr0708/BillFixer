import { getOrSet } from '../lib/cache.js';
import { notFound } from '../lib/errors.js';
import * as ref from '../repositories/referenceRepo.js';

export const regionForState = (state) => {
  const s = String(state || '').toUpperCase();
  return s === 'AK' ? 'ak' : s === 'HI' ? 'hi' : 'us';
};

async function table(year, region) {
  const y = year ?? (await getOrSet('fpl', `latest:${region}`, 3600, () => ref.latestFplYear(region)));
  if (!y) throw notFound('Poverty guideline data');
  const rows = await getOrSet('fpl', `${y}:${region}`, 86_400, async () =>
    (await ref.fplTable(y, region)).map((r) => ({ householdSize: r.household_size, amount: String(r.amount) })));
  if (!rows?.length) throw notFound(`Poverty guidelines for ${y}`);
  return { year: y, rows };
}

/** Guideline in cents for a household size (sizes > 8 use the official per-person increment). */
export async function guideline({ year, state, householdSize }) {
  const region = regionForState(state);
  const { year: y, rows } = await table(year, region);
  const byN = new Map(rows.map((r) => [r.householdSize, Math.round(Number(r.amount) * 100)]));
  const size = Math.max(1, Math.min(20, householdSize));
  let cents = byN.get(size);
  if (cents === undefined) {
    const inc = byN.get(8) - byN.get(7);
    cents = byN.get(8) + (size - 8) * inc;
  }
  return { year: y, region, householdSize: size, guidelineCents: cents };
}

export async function estimate({ householdSize, annualIncomeCents, state }) {
  const g = await guideline({ state, householdSize });
  const pct = Math.round((annualIncomeCents / g.guidelineCents) * 100);
  return { ...g, pct };
}

export async function fullTable({ year, state }) {
  const region = regionForState(state);
  const t = await table(year, region);
  return { year: t.year, region, guidelines: t.rows };
}
