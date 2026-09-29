import { toCents, toMillis, fromCents } from '../lib/money.js';
import { todayUtc } from '../lib/time.js';
import { conflict } from '../lib/errors.js';
import { logger } from '../lib/logger.js';
import { analyze } from './analysisEngine.js';
import { explainFindings } from './explanationService.js';
import { priceMap, mpfsMap } from './providerService.js';
import { estimate as fplEstimate } from './fplService.js';
import { enqueue } from './jobRunner.js';
import { mapFinding, mapJob } from '../repositories/mappers.js';
import * as billRepo from '../repositories/billRepo.js';
import * as findingRepo from '../repositories/findingRepo.js';
import * as jobs from '../repositories/jobRepo.js';
import * as ref from '../repositories/referenceRepo.js';

const STEP_DEFS = [
  { key: 'read', label: 'Reading your bill…' },
  { key: 'arithmetic', label: 'Checking the math…' },
  { key: 'duplicates', label: 'Finding duplicate charges…' },
  { key: 'eob_reconcile', label: 'Comparing with your EOB…', needsEob: true },
  { key: 'pricing', label: 'Looking up hospital prices…' },
  { key: 'rights', label: 'Checking your rights…' },
  { key: 'explain', label: 'Building your action plan…' },
];

const c = (v) => (v === null || v === undefined ? null : toCents(v));

function toEngineInput({ bill, lines, eob, eobLines, gfe }) {
  return {
    bill: {
      providerName: bill.provider_name,
      accountNumber: bill.account_number,
      billDate: bill.bill_date,
      serviceDateStart: bill.service_date_start,
      serviceDateEnd: bill.service_date_end,
      totalCharges: c(bill.total_charges),
      insurancePayment: c(bill.insurance_payment),
      adjustments: c(bill.adjustments),
      previousPayments: c(bill.previous_payments),
      patientResponsibility: c(bill.patient_responsibility),
      currentBalance: c(bill.current_balance),
      isItemized: Boolean(bill.is_itemized),
      lineItems: lines.map((l) => ({
        id: l.id, lineNumber: l.line_number, code: l.code, description: l.description, dateOfService: l.date_of_service,
        quantityMillis: toMillis(l.quantity) ?? 1000, unitPrice: c(l.unit_price), totalAmount: c(l.total_amount), adjustment: c(l.adjustment),
      })),
    },
    eob: eob ? {
      claimNumber: eob.claim_number, eobDate: eob.eob_date, networkStatus: eob.network_status,
      serviceDateStart: eob.service_date_start, serviceDateEnd: eob.service_date_end,
      billedAmount: c(eob.billed_amount), allowedAmount: c(eob.allowed_amount), insurerPayment: c(eob.insurer_payment),
      patientResponsibility: c(eob.patient_responsibility),
      lineItems: eobLines.map((l) => ({ networkStatus: l.network_status })),
    } : null,
    gfe: gfe ? { totalEstimate: c(gfe.total_estimate), estimateDate: gfe.estimate_date, providerName: gfe.provider_name } : null,
  };
}

export async function startAnalysis(userId, caseId, context = {}) {
  const loaded = await billRepo.loadForAnalysis(caseId);
  if (!loaded.bill) throw conflict('Add and confirm your bill before running the analysis.', 'BILL_REQUIRED');
  const existing = await jobs.activeForCase(caseId, 'analysis');
  if (existing) return { jobId: existing.id, estimatedSeconds: 20, reused: true };

  const steps = STEP_DEFS.filter((s) => !s.needsEob || loaded.eob).map(({ key, label }) => ({ key, label, status: 'pending' }));
  const jobId = await jobs.create({ userId, caseId, type: 'analysis', steps, payload: { context } });
  enqueue(jobId, (id) => runAnalysis(id, caseId, context, steps));
  return { jobId, estimatedSeconds: 20, reused: false };
}

async function runAnalysis(jobId, caseId, context, steps) {
  const advance = async (key) => {
    let seen = false;
    for (const s of steps) {
      if (s.key === key) { s.status = 'running'; seen = true; } else if (!seen) s.status = 'complete';
    }
    const done = steps.filter((s) => s.status === 'complete').length;
    await jobs.updateProgress(jobId, done / steps.length, steps);
  };

  await advance('read');
  const loaded = await billRepo.loadForAnalysis(caseId);
  const input = toEngineInput(loaded);
  const codes = input.bill.lineItems.map((l) => l.code).filter(Boolean);

  await advance('arithmetic');
  await advance('duplicates');
  if (steps.some((s) => s.key === 'eob_reconcile')) await advance('eob_reconcile');

  await advance('pricing');
  // Provider: explicit link on the case, else best-effort name match against the CMS directory.
  let providerRow = loaded.caseRow.provider_id ? await ref.getProvider(loaded.caseRow.provider_id) : null;
  if (!providerRow && input.bill.providerName) {
    providerRow = await ref.matchProviderByName(input.bill.providerName, context.state).catch(() => null);
  }
  const [prices, mpfs] = await Promise.all([
    providerRow ? priceMap(providerRow.id, codes).catch(() => new Map()) : new Map(),
    mpfsMap(codes).catch(() => new Map()),
  ]);

  await advance('rights');
  let fpl = null;
  if (context.householdSize && context.annualIncome !== undefined && context.annualIncome !== null) {
    fpl = await fplEstimate({ householdSize: context.householdSize, annualIncomeCents: toCents(context.annualIncome), state: context.state })
      .catch((err) => { logger.warn({ err: err.message }, 'fpl estimate failed'); return null; });
  }
  const fap = providerRow ? await ref.getFap(providerRow.id).catch(() => null) : null;
  const provider = providerRow ? {
    name: providerRow.name,
    taxStatus: providerRow.tax_status,
    fap: fap ? {
      freeCareThresholdFpl: fap.free_care_threshold_fpl !== null ? Number(fap.free_care_threshold_fpl) : null,
      incomeThresholdFpl: fap.income_threshold_fpl !== null ? Number(fap.income_threshold_fpl) : null,
      fapUrl: fap.fap_url ?? providerRow.fap_url ?? null,
    } : (providerRow.fap_url ? { fapUrl: providerRow.fap_url } : null),
  } : null;

  const result = analyze({
    ...input,
    provider,
    prices,
    mpfs,
    fpl: fpl ? { pct: fpl.pct, year: fpl.year, householdSize: fpl.householdSize } : null,
    context: { ...context, initialBillDate: loaded.caseRow.initial_bill_date ?? loaded.caseRow.bill_date },
    today: todayUtc(),
  });

  await advance('explain');
  const explained = await explainFindings(result.findings, { providerName: input.bill.providerName })
    .catch((err) => { logger.warn({ err: err.message }, 'explanations failed — using deterministic text'); return result.findings; });

  await findingRepo.replaceFindings(caseId, explained, { potentialSavingsCents: result.potentialSavings });
  steps.forEach((s) => { s.status = 'complete'; });
  await jobs.complete(jobId, 'findings', caseId, steps);
}

export async function status(caseId) {
  const job = await jobs.latestForCase(caseId, 'analysis');
  return job ? mapJob(job) : { status: 'none', progress: 0, steps: [] };
}

const SEVERITY_KEYS = ['strong', 'likely', 'possible', 'informational'];
const ALWAYS_VISIBLE = new Set(['itemized_bill_missing']);

/** Findings for the app, with free-tier locking enforced here (not in the app). */
export async function findingsFor(caseRow, tier) {
  const rows = await findingRepo.listWithEvidence(caseRow.id);
  const premium = tier.tier === 'premium';
  let freeShown = 0;
  const findings = rows.map(({ row, evidence }) => {
    const f = mapFinding(row, evidence);
    if (premium || ALWAYS_VISIBLE.has(f.type)) return f;
    if (f.severity !== 'informational' && freeShown === 0) { freeShown += 1; return f; }
    return { ...f, locked: true, title: 'Unlock to see this finding', explanation: '', whatYouCanDo: null, counterCase: null,
      amountFlagged: null, amountReference: null, amountDifference: null, evidence: [] };
  });

  const bySeverity = Object.fromEntries(SEVERITY_KEYS.map((k) => [k, findings.filter((f) => f.severity === k && f.status === 'open').length]));
  const firstIdx = findings.findIndex((f) => f.type === 'itemized_bill_missing');
  const top = firstIdx >= 0 ? findings[firstIdx] : findings.find((f) => !f.locked && f.recommendedAction && f.recommendedAction !== 'none');
  return {
    findings,
    summary: {
      total: findings.filter((f) => f.severity !== 'informational').length,
      bySeverity,
      potentialSavings: premium ? caseRow.potential_savings ?? null : null,
      potentialSavingsLocked: !premium && caseRow.potential_savings !== null,
      recommendedFirstAction: top ? { findingId: top.id, action: top.recommendedAction, title: top.title } : null,
    },
  };
}

export { fromCents };
