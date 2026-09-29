import { test } from 'node:test';
import assert from 'node:assert/strict';
import { analyze, potentialSavings } from '../src/services/analysisEngine.js';

const today = new Date(Date.UTC(2026, 8, 28));
const line = (n, code, desc, date, total, extra = {}) =>
  ({ id: `li-${n}`, lineNumber: n, code, description: desc, dateOfService: date, quantityMillis: 1000, unitPrice: null, totalAmount: total, adjustment: null, ...extra });
const bill = (over = {}) => ({
  providerName: 'Riverside Medical Center', accountNumber: '4471-A', billDate: '2026-03-20',
  serviceDateStart: '2026-03-15', serviceDateEnd: '2026-03-15',
  totalCharges: null, insurancePayment: null, adjustments: null, previousPayments: null,
  patientResponsibility: null, currentBalance: null, isItemized: true, lineItems: [], ...over,
});
const types = (r) => r.findings.map((f) => f.type);
const find = (r, t) => r.findings.find((f) => f.type === t);

test('arithmetic: worked example from BILL_ANALYSIS.md ($150 overstated)', () => {
  const r = analyze({ bill: bill({
    totalCharges: 348000, insurancePayment: 210000, adjustments: 84000, currentBalance: 69000,
    lineItems: [line(1, '99284', 'ED visit', '2026-03-15', 348000)],
  }), today });
  const f = find(r, 'arithmetic_error');
  assert.ok(f, 'expected arithmetic finding');
  assert.equal(f.severity, 'strong');
  assert.equal(f.amountReference, 54000);
  assert.equal(f.amountDifference, 15000);
  assert.match(f.explanation, /\$150\.00/);
});

test('arithmetic: balance lower than computed is not flagged (in the patient’s favour)', () => {
  const r = analyze({ bill: bill({ totalCharges: 100000, insurancePayment: 60000, currentBalance: 30000,
    lineItems: [line(1, '99213', 'Office visit', '2026-03-15', 100000)] }), today });
  assert.equal(find(r, 'arithmetic_error'), undefined);
});

test('arithmetic: no deductions known → header check skipped (avoids false positives)', () => {
  const r = analyze({ bill: bill({ totalCharges: 100000, currentBalance: 120000,
    lineItems: [line(1, '99213', 'Office visit', '2026-03-15', 100000)] }), today });
  assert.equal(r.findings.filter((f) => f.type === 'arithmetic_error' && f.severity === 'strong').length, 0);
});

test('duplicates: same code + date + amount is strong, flags the extra charge only', () => {
  const r = analyze({ bill: bill({ lineItems: [
    line(3, '71046', 'Chest X-Ray 2 Views', '2026-03-15', 42000),
    line(7, '71046', 'Chest X-Ray 2 Views', '2026-03-15', 42000),
    line(8, '93000', 'EKG', '2026-03-15', 21000),
  ] }), today });
  const f = find(r, 'duplicate_charge');
  assert.equal(f.severity, 'strong');
  assert.equal(f.confidence, 'high');
  assert.equal(f.amountDifference, 42000);
  assert.equal(f.evidence.length, 2);
  assert.ok(f.counterCase, 'strong findings must carry a counter-case');
});

test('duplicates: repeatable drug units are downgraded to possible', () => {
  const r = analyze({ bill: bill({ lineItems: [
    line(1, 'J1885', 'Ketorolac', '2026-03-15', 9600), line(2, 'J1885', 'Ketorolac', '2026-03-15', 9600),
  ] }), today });
  assert.equal(find(r, 'duplicate_charge').severity, 'possible');
});

test('duplicates: uncoded lines match on normalised description (likely)', () => {
  const r = analyze({ bill: bill({ lineItems: [
    line(1, null, 'LAB - CBC w/ Diff', '2026-03-15', 5000), line(2, null, 'lab cbc w diff', '2026-03-15', 5000),
  ] }), today });
  assert.equal(find(r, 'duplicate_charge').severity, 'likely');
});

test('EOB: bill above EOB patient responsibility is strong, savings capped by EOB gap', () => {
  const r = analyze({
    bill: bill({ patientResponsibility: 123456, currentBalance: 123456, lineItems: [line(1, '99284', 'ED visit', '2026-03-15', 285000)] }),
    eob: { claimNumber: '8821-X', eobDate: '2026-03-18', networkStatus: 'in', serviceDateStart: '2026-03-15', serviceDateEnd: '2026-03-15',
      allowedAmount: null, insurerPayment: null, patientResponsibility: 34256, lineItems: [] },
    today,
  });
  const f = find(r, 'bill_eob_mismatch');
  assert.equal(f.severity, 'strong');
  assert.equal(f.amountDifference, 89200);
  assert.equal(r.potentialSavings, 89200);
});

test('EOB: non-overlapping dates downgrade the mismatch and add a date finding', () => {
  const r = analyze({
    bill: bill({ patientResponsibility: 50000 }),
    eob: { claimNumber: 'X', networkStatus: 'in', serviceDateStart: '2026-01-02', serviceDateEnd: '2026-01-02',
      allowedAmount: null, insurerPayment: null, patientResponsibility: 10000, lineItems: [] },
    today,
  });
  assert.equal(find(r, 'bill_eob_mismatch').severity, 'likely');
  assert.equal(find(r, 'service_date_mismatch').severity, 'likely');
});

test('EOB internal math uses a $1.00 tolerance', () => {
  const base = { claimNumber: 'X', networkStatus: 'in', serviceDateStart: '2026-03-15', serviceDateEnd: '2026-03-15', lineItems: [] };
  const ok = analyze({ bill: bill(), eob: { ...base, allowedAmount: 100000, insurerPayment: 80000, patientResponsibility: 20050 }, today });
  assert.equal(find(ok, 'paid_amount_mismatch'), undefined);
  const bad = analyze({ bill: bill(), eob: { ...base, allowedAmount: 100000, insurerPayment: 80000, patientResponsibility: 30000 }, today });
  assert.equal(find(bad, 'paid_amount_mismatch').severity, 'likely');
});

test('GFE: uninsured, $400+ over → strong with a 120-day deadline', () => {
  const r = analyze({ bill: bill({ totalCharges: 150000, billDate: '2026-09-01' }), gfe: { totalEstimate: 100000, estimateDate: '2026-08-01' },
    context: { hasInsurance: false }, today });
  const f = find(r, 'gfe_dispute_eligible');
  assert.equal(f.severity, 'strong');
  assert.equal(f.deadlineDate, '2026-12-30');
  assert.equal(f.recommendedAction, 'start_ppdr');
});

test('GFE: $399.99 over is below the threshold', () => {
  const r = analyze({ bill: bill({ totalCharges: 139999 }), gfe: { totalEstimate: 100000 }, context: { hasInsurance: false }, today });
  assert.equal(find(r, 'gfe_dispute_eligible'), undefined);
});

test('GFE: past the 120-day window is informational', () => {
  const r = analyze({ bill: bill({ totalCharges: 200000, billDate: '2026-01-01' }), gfe: { totalEstimate: 100000 },
    context: { hasInsurance: false }, today });
  assert.equal(find(r, 'gfe_dispute_eligible').severity, 'informational');
});

test('GFE: never applies to insured patients', () => {
  const r = analyze({ bill: bill({ totalCharges: 200000 }), gfe: { totalEstimate: 100000 }, context: { hasInsurance: true }, today });
  assert.equal(find(r, 'gfe_dispute_eligible'), undefined);
});

test('No Surprises Act: emergency code screens as possible; out-of-network as likely; uninsured never', () => {
  const lines = [line(1, '99285', 'ED visit level 5', '2026-03-15', 180000)];
  assert.equal(find(analyze({ bill: bill({ lineItems: lines }), context: { hasInsurance: true }, today }), 'no_surprises_possible').severity, 'possible');
  assert.equal(find(analyze({ bill: bill({ lineItems: lines }), context: { hasInsurance: true, outOfNetwork: true }, today }), 'no_surprises_possible').severity, 'likely');
  assert.equal(find(analyze({ bill: bill({ lineItems: lines }), context: { hasInsurance: false }, today }), 'no_surprises_possible'), undefined);
});

test('Financial assistance: nonprofit + income under free-care limit → likely', () => {
  const r = analyze({ bill: bill(), provider: { name: 'Riverside', taxStatus: 'nonprofit', fap: { freeCareThresholdFpl: 200, incomeThresholdFpl: 400 } },
    fpl: { pct: 188, year: 2026, householdSize: 3 }, today });
  const f = find(r, 'financial_assistance_eligible');
  assert.equal(f.severity, 'likely');
  assert.match(f.explanation, /188%/);
});

test('Financial assistance: nonprofit always shows, even with no income given', () => {
  const r = analyze({ bill: bill(), provider: { name: 'Riverside', taxStatus: 'nonprofit', fap: null }, today });
  assert.equal(find(r, 'financial_assistance_eligible').severity, 'possible');
});

test('Pricing: self-pay charged above published cash price → strong', () => {
  const prices = new Map([['71046', { cashPrice: 18000, maxRate: 30000, minRate: 9000, effectiveDate: '2026-01-01', sourceUrl: 'https://x/mrf.json' }]]);
  const r = analyze({ bill: bill({ lineItems: [line(1, '71046', 'Chest X-Ray', '2026-03-15', 42000)] }), prices, context: { hasInsurance: false }, today });
  const f = find(r, 'price_above_cash_price');
  assert.equal(f.severity, 'strong');
  assert.equal(f.amountDifference, 24000);
});

test('Pricing: insured patient above negotiated max is informational only', () => {
  const prices = new Map([['71046', { cashPrice: null, maxRate: 30000, minRate: 9000 }]]);
  const r = analyze({ bill: bill({ insurancePayment: 10000, lineItems: [line(1, '71046', 'Chest X-Ray', '2026-03-15', 42000)] }), prices,
    context: { hasInsurance: true }, today });
  assert.equal(find(r, 'price_above_negotiated_rate').severity, 'informational');
});

test('Itemization missing → recommended first action is to request an itemized bill', () => {
  const r = analyze({ bill: bill({ isItemized: false, currentBalance: 50000 }), today });
  assert.equal(r.recommendedFirstAction.action, 'request_itemized_bill');
});

test('Findings are sorted strongest first', () => {
  const r = analyze({ bill: bill({ lineItems: [
    line(1, '71046', 'Chest X-Ray', '2026-03-15', 42000), line(2, '71046', 'Chest X-Ray', '2026-03-15', 42000),
    line(3, '99285', 'ED visit', '2026-03-15', 180000),
  ] }), context: { hasInsurance: true }, today });
  const ranks = r.findings.map((f) => ['strong', 'likely', 'possible', 'informational'].indexOf(f.severity));
  assert.deepEqual(ranks, [...ranks].sort((a, b) => a - b));
  assert.equal(types(r)[0], 'duplicate_charge');
});

test('Potential savings never exceed the balance owed', () => {
  const findings = [{ type: 'duplicate_charge', severity: 'strong', amountDifference: 90000 }];
  assert.equal(potentialSavings(findings, { currentBalance: 50000 }), 50000);
  assert.equal(potentialSavings([], { currentBalance: 50000 }), null);
});
