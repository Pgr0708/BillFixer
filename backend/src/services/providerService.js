import { getOrSet } from '../lib/cache.js';
import { notFound } from '../lib/errors.js';
import { toCents, fromCents } from '../lib/money.js';
import { normalizeCode } from './codeSets.js';
import { mapProvider } from '../repositories/mappers.js';
import * as ref from '../repositories/referenceRepo.js';

export async function search({ q, state }) {
  const key = `${q.toLowerCase().trim()}|${state ?? ''}`;
  return getOrSet('providers', `search:${key}`, 600, async () => (await ref.searchProviders({ q, state, limit: 20 })).map(mapProvider));
}

/** Collapse price rows (several settings per code) into one reference per code, in cents. */
export async function priceMap(providerId, codes) {
  const wanted = [...new Set(codes.map(normalizeCode).filter(Boolean))].sort();
  if (!providerId || !wanted.length) return new Map();
  const rows = await getOrSet('providers', `prices:${providerId}:${wanted.join(',')}`, 3600, () => ref.pricesForCodes(providerId, wanted));
  const provider = await getProvider(providerId).catch(() => null);
  const map = new Map();
  for (const r of rows) {
    const code = normalizeCode(r.code);
    const prev = map.get(code);
    const cand = {
      description: r.description,
      cashPrice: r.cash_price !== null ? toCents(r.cash_price) : null,
      grossCharge: r.gross_charge !== null ? toCents(r.gross_charge) : null,
      minRate: r.min_rate !== null ? toCents(r.min_rate) : null,
      maxRate: r.max_rate !== null ? toCents(r.max_rate) : null,
      medianRate: r.median_rate !== null ? toCents(r.median_rate) : null,
      effectiveDate: r.effective_date,
      sourceUrl: provider?.mrf_url ?? null,
    };
    // Prefer outpatient/both over inpatient — bills with CPT codes are typically outpatient.
    if (!prev || (r.setting !== 'inpatient' && prev.setting === 'inpatient')) map.set(code, { ...cand, setting: r.setting });
  }
  return map;
}

export async function mpfsMap(codes) {
  const wanted = [...new Set(codes.map(normalizeCode).filter(Boolean))].sort();
  if (!wanted.length) return new Map();
  const rows = await getOrSet('mpfs', `codes:${wanted.join(',')}`, 86_400, () => ref.mpfsForCodes(wanted));
  return new Map(rows.map((r) => [normalizeCode(r.code), {
    facilityAmount: r.facility_amount !== null ? toCents(r.facility_amount) : null,
    nonfacilityAmount: r.nonfacility_amount !== null ? toCents(r.nonfacility_amount) : null,
    year: r.year,
    quarter: r.quarter,
  }]));
}

export async function getProvider(providerId) {
  const p = await getOrSet('providers', `p:${providerId}`, 3600, () => ref.getProvider(providerId));
  if (!p) throw notFound('Provider');
  return p;
}

export async function pricing(providerId, codes) {
  const provider = await getProvider(providerId);
  const map = await priceMap(providerId, codes);
  return {
    providerId,
    providerName: provider.name,
    effectiveDate: [...map.values()].map((v) => v.effectiveDate).filter(Boolean).sort().pop() ?? null,
    sourceUrl: provider.mrf_url ?? null,
    records: [...map.entries()].map(([code, v]) => ({
      code, description: v.description, cashPrice: fromCents(v.cashPrice), grossCharge: fromCents(v.grossCharge),
      minNegotiatedRate: fromCents(v.minRate), maxNegotiatedRate: fromCents(v.maxRate), medianNegotiatedRate: fromCents(v.medianRate),
    })),
  };
}

export async function financialAssistance(providerId) {
  const provider = await getProvider(providerId);
  const fap = await getOrSet('providers', `fap:${providerId}`, 3600, () => ref.getFap(providerId));
  const docs = fap?.required_docs ? (typeof fap.required_docs === 'string' ? JSON.parse(fap.required_docs) : fap.required_docs) : null;
  return {
    providerId,
    providerName: provider.name,
    taxStatus: provider.tax_status,
    fapUrl: fap?.fap_url ?? provider.fap_url ?? null,
    applicationUrl: fap?.application_url ?? null,
    applicationPhone: fap?.application_phone ?? provider.phone ?? null,
    incomeThresholdFpl: fap?.income_threshold_fpl !== undefined && fap?.income_threshold_fpl !== null ? Number(fap.income_threshold_fpl) : null,
    freeCareThresholdFpl: fap?.free_care_threshold_fpl !== undefined && fap?.free_care_threshold_fpl !== null ? Number(fap.free_care_threshold_fpl) : null,
    requiredDocs: docs ?? ['Proof of income (recent pay stubs or tax return)', 'Photo ID', 'Proof of household size', 'The bill you are asking about'],
    allowsRetroactive: fap?.allows_retroactive === null || fap?.allows_retroactive === undefined ? null : Boolean(fap.allows_retroactive),
  };
}
