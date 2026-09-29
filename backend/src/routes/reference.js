import { Router } from 'express';
import { validate } from '../middleware/validate.js';
import { toCents } from '../lib/money.js';
import { RIGHTS } from '../services/rightsCatalog.js';
import * as providers from '../services/providerService.js';
import * as fpl from '../services/fplService.js';
import * as v from '../validators/index.js';

export const referenceRoutes = Router();

referenceRoutes.get('/providers/search', validate({ query: v.providerSearchQuery }), async (req, res) => {
  res.set('Cache-Control', 'private, max-age=300');
  res.json({ results: await providers.search(req.validQuery) });
});
referenceRoutes.get('/providers/:providerId/pricing', validate({ params: v.providerParams, query: v.pricingQuery }), async (req, res) => {
  res.set('Cache-Control', 'private, max-age=3600');
  res.json(await providers.pricing(req.params.providerId, req.validQuery.codes));
});
referenceRoutes.get('/providers/:providerId/financial-assistance', validate({ params: v.providerParams }), async (req, res) => {
  res.set('Cache-Control', 'private, max-age=3600');
  res.json(await providers.financialAssistance(req.params.providerId));
});

referenceRoutes.get('/reference/rights', (_req, res) => {
  res.set('Cache-Control', 'public, max-age=86400');
  res.json({ rights: RIGHTS });
});
referenceRoutes.get('/reference/fpl', validate({ query: v.fplQuery }), async (req, res) => {
  res.set('Cache-Control', 'public, max-age=86400');
  res.json(await fpl.fullTable(req.validQuery));
});
referenceRoutes.post('/reference/fpl/estimate', validate({ body: v.fplEstimateBody }), async (req, res) => {
  const r = await fpl.estimate({ ...req.body, annualIncomeCents: toCents(req.body.annualIncome) });
  res.json({ year: r.year, region: r.region, householdSize: r.householdSize, guideline: (r.guidelineCents / 100).toFixed(2), fplPercent: r.pct,
    sourceUrl: 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines' });
});
referenceRoutes.get('/reference/benchmark', validate({ query: v.benchmarkQuery }), async (req, res) => {
  res.set('Cache-Control', 'public, max-age=86400');
  const map = await providers.mpfsMap(req.validQuery.codes);
  res.json({
    note: 'Medicare national rates — a reference point only, never a maximum.',
    rates: [...map.entries()].map(([code, m]) => ({ code, facilityAmount: m.facilityAmount !== null ? (m.facilityAmount / 100).toFixed(2) : null,
      nonfacilityAmount: m.nonfacilityAmount !== null ? (m.nonfacilityAmount / 100).toFixed(2) : null, year: m.year, quarter: m.quarter })),
  });
});
