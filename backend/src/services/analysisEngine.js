/**
 * Deterministic bill analysis (docs/analysis/BILL_ANALYSIS.md).
 * Pure functions, integer cents, no I/O, no LLM. Every finding carries its evidence.
 *
 * input = {
 *   bill:   { providerName, accountNumber, billDate, serviceDateStart, serviceDateEnd, totalCharges,
 *             insurancePayment, adjustments, previousPayments, patientResponsibility, currentBalance,
 *             isItemized, lineItems:[{ id, lineNumber, code, description, dateOfService,
 *             quantityMillis, unitPrice, totalAmount, adjustment }] }        ← all money in cents
 *   eob:    null | { claimNumber, eobDate, networkStatus, serviceDateStart, serviceDateEnd, billedAmount,
 *             allowedAmount, insurerPayment, patientResponsibility, lineItems:[{ networkStatus }] }
 *   gfe:    null | { totalEstimate, estimateDate, providerName }
 *   provider: null | { name, taxStatus, fap: null | { freeCareThresholdFpl, incomeThresholdFpl, fapUrl, applicationUrl } }
 *   prices: Map<code, { cashPrice, grossCharge, minRate, maxRate, effectiveDate, sourceUrl }>
 *   mpfs:   Map<code, { facilityAmount, nonfacilityAmount, year, quarter }>
 *   context:{ wasEmergency?, hasInsurance?, outOfNetwork?, initialBillDate? }
 *   fpl:    null | { pct, year, householdSize }
 *   today:  Date (UTC midnight)
 * }
 */
import { formatUsd, sumCents } from '../lib/money.js';
import { parseDate, addDays, daysBetween, rangesOverlap, toDateString } from '../lib/time.js';
import {
  normalizeCode, isEmergencyCode, isAncillaryCode, isRepeatableCode, isUnusualQuantityCode,
} from './codeSets.js';
import { RIGHTS_BY_KEY } from './rightsCatalog.js';

export const SEVERITY_RANK = { strong: 0, likely: 1, possible: 2, informational: 3 };
const ONE_CENT = 1;

const normalizeDescription = (s) =>
  String(s || '').toLowerCase().replace(/[^a-z0-9 ]+/g, ' ').replace(/\s+/g, ' ').trim();

const lineLabel = (li) => `Bill · line ${li.lineNumber}`;
const lineValue = (li) =>
  [li.dateOfService, li.code, li.description, formatUsd(li.totalAmount)].filter(Boolean).join('  ·  ');

function finding(fields) {
  return {
    severity: 'possible',
    confidence: 'medium',
    amountFlagged: null,
    amountReference: null,
    amountDifference: null,
    whatYouCanDo: null,
    counterCase: null,
    recommendedAction: null,
    deadlineDate: null,
    evidence: [],
    ...fields,
  };
}

// ── Check 0: itemization ──────────────────────────────────────────────────
function checkItemization({ bill }) {
  if (bill.isItemized && bill.lineItems.length > 0) return [];
  return [finding({
    type: 'itemized_bill_missing',
    severity: 'informational',
    confidence: 'high',
    title: 'Request an itemized bill',
    explanation: 'This statement shows totals without a full line-by-line breakdown. An itemized bill lists every code, date and quantity, which is what we need to check each charge.',
    whatYouCanDo: 'Ask the billing office for an itemized statement with CPT/HCPCS codes before paying.',
    recommendedAction: 'request_itemized_bill',
    evidence: [{ sourceType: 'bill_header', label: 'Your statement', value: `${bill.lineItems.length} itemized lines found` }],
  })];
}

// ── Check 1: arithmetic ───────────────────────────────────────────────────
function checkArithmetic({ bill }) {
  const out = [];
  const lines = bill.lineItems;
  const sumLines = lines.length ? sumCents(lines.map((l) => l.totalAmount)) : null;

  // 1a. Line items exceed the stated total charges.
  if (sumLines !== null && bill.totalCharges !== null && sumLines > bill.totalCharges + ONE_CENT) {
    const diff = sumLines - bill.totalCharges;
    out.push(finding({
      type: 'arithmetic_error',
      severity: 'likely',
      confidence: 'medium',
      title: 'Line items add up to more than the total',
      explanation: `The individual charges add up to ${formatUsd(sumLines)}, but the bill lists total charges of ${formatUsd(bill.totalCharges)} — a gap of ${formatUsd(diff)}.`,
      whatYouCanDo: 'Ask the billing office which total is correct and request a corrected statement.',
      counterCase: 'If a line was captured twice during scanning, re-check the extracted lines before disputing.',
      amountFlagged: sumLines, amountReference: bill.totalCharges, amountDifference: diff,
      recommendedAction: 'request_itemized_bill',
      evidence: [
        { sourceType: 'bill_line_item', label: `Sum of ${lines.length} line items`, value: formatUsd(sumLines) },
        { sourceType: 'bill_header', label: 'Bill · total charges', value: formatUsd(bill.totalCharges) },
      ],
    }));
  }

  // 1b. Header math: charges − adjustments − insurance − prior payments should equal the balance.
  const chargesBase = bill.totalCharges ?? sumLines;
  const lineAdjustments = lines.some((l) => l.adjustment) ? sumCents(lines.map((l) => l.adjustment)) : null;
  const adjustments = bill.adjustments ?? lineAdjustments;
  const deductionsKnown = [adjustments, bill.insurancePayment, bill.previousPayments].some((v) => v !== null);
  if (chargesBase !== null && bill.currentBalance !== null && deductionsKnown) {
    const expected = chargesBase - Math.abs(adjustments ?? 0) - Math.abs(bill.insurancePayment ?? 0) - Math.abs(bill.previousPayments ?? 0);
    const diff = bill.currentBalance - expected;
    if (diff > ONE_CENT) {
      out.push(finding({
        type: 'arithmetic_error',
        severity: 'strong',
        confidence: 'high',
        title: 'The bill’s math doesn’t add up',
        explanation: `Charges of ${formatUsd(chargesBase)}, minus adjustments and payments, come to ${formatUsd(expected)}. The bill asks for ${formatUsd(bill.currentBalance)} — ${formatUsd(diff)} more than the numbers support.`,
        whatYouCanDo: 'Ask the billing office to explain the difference and send a corrected statement.',
        counterCase: 'A late fee or a payment reversal can raise a balance. Ask them to show what the extra amount is for.',
        amountFlagged: bill.currentBalance, amountReference: expected, amountDifference: diff,
        recommendedAction: 'request_itemized_bill',
        evidence: [
          { sourceType: 'bill_header', label: 'Bill · total charges', value: formatUsd(chargesBase) },
          ...(adjustments !== null ? [{ sourceType: 'bill_header', label: 'Bill · adjustments', value: `−${formatUsd(Math.abs(adjustments))}` }] : []),
          ...(bill.insurancePayment !== null ? [{ sourceType: 'bill_header', label: 'Bill · insurance paid', value: `−${formatUsd(Math.abs(bill.insurancePayment))}` }] : []),
          ...(bill.previousPayments !== null ? [{ sourceType: 'bill_header', label: 'Bill · previous payments', value: `−${formatUsd(Math.abs(bill.previousPayments))}` }] : []),
          { sourceType: 'bill_header', label: 'Bill · balance due', value: formatUsd(bill.currentBalance) },
        ],
      }));
    }
  }
  return out;
}

// ── Check 2: duplicates ───────────────────────────────────────────────────
function duplicateFinding(group, severity, confidence, basis) {
  const [first] = group;
  const extra = group.length - 1;
  const flagged = first.totalAmount * extra;
  const label = first.code ? `${first.code} (${first.description})` : first.description;
  return finding({
    type: 'duplicate_charge',
    severity,
    confidence,
    title: extra === 1 ? 'Possible duplicate charge' : `Charge appears ${group.length} times`,
    explanation: `${label} appears ${group.length} times ${basis} at ${formatUsd(first.totalAmount)} each.`,
    whatYouCanDo: 'Ask the billing office to remove the duplicate, or to show the separate order for each service.',
    counterCase: 'Sometimes a repeat service is legitimate — for example a second X-ray after a procedure. If so, they should be able to show a separate order.',
    amountFlagged: flagged, amountReference: first.totalAmount, amountDifference: flagged,
    recommendedAction: 'dispute_duplicate',
    evidence: group.map((li) => ({ sourceType: 'bill_line_item', sourceRef: li.id ?? null, label: lineLabel(li), value: lineValue(li) })),
  });
}

function checkDuplicates({ bill }) {
  const out = [];
  const lines = bill.lineItems.filter((l) => l.totalAmount > 0);
  const claimed = new Set();
  const group = (keyFn) => {
    const map = new Map();
    for (const li of lines) {
      if (claimed.has(li)) continue;
      const key = keyFn(li);
      if (key === null) continue;
      if (!map.has(key)) map.set(key, []);
      map.get(key).push(li);
    }
    return [...map.values()].filter((g) => g.length > 1);
  };

  // Strong: same code + same date + same amount.
  for (const g of group((l) => (l.code && l.dateOfService ? `${l.code}|${l.dateOfService}|${l.totalAmount}` : null))) {
    const repeatable = isRepeatableCode(g[0].code);
    out.push(duplicateFinding(g, repeatable ? 'possible' : 'strong', repeatable ? 'low' : 'high', 'on the same date'));
    g.forEach((li) => claimed.add(li));
  }
  // Likely: no code, same normalised description + date + amount.
  for (const g of group((l) => {
    const d = normalizeDescription(l.description);
    return !l.code && l.dateOfService && d.length >= 4 ? `${d}|${l.dateOfService}|${l.totalAmount}` : null;
  })) {
    out.push(duplicateFinding(g, 'likely', 'medium', 'on the same date'));
    g.forEach((li) => claimed.add(li));
  }
  // Possible: same description + amount on different dates within 7 days.
  for (const g of group((l) => {
    const d = normalizeDescription(l.description);
    return d.length >= 6 ? `${d}|${l.totalAmount}` : null;
  })) {
    const dates = g.map((l) => parseDate(l.dateOfService)).filter(Boolean).sort((a, b) => a - b);
    if (dates.length === g.length && daysBetween(dates[0], dates[dates.length - 1]) <= 7 && !isRepeatableCode(g[0].code)) {
      out.push(duplicateFinding(g, 'possible', 'low', 'within the same week'));
      g.forEach((li) => claimed.add(li));
    }
  }
  return out;
}

// ── Check 3–5: EOB ────────────────────────────────────────────────────────
function checkEob({ bill, eob }) {
  if (!eob) return [];
  const out = [];
  const billAmount = bill.patientResponsibility ?? bill.currentBalance;
  const bStart = parseDate(bill.serviceDateStart);
  const bEnd = parseDate(bill.serviceDateEnd) ?? bStart;
  const eStart = parseDate(eob.serviceDateStart);
  const eEnd = parseDate(eob.serviceDateEnd) ?? eStart;
  const datesKnown = bStart && eStart;
  const overlap = datesKnown ? rangesOverlap(bStart, bEnd, eStart, eEnd) : true;

  // Check 3: bill vs EOB patient responsibility.
  if (billAmount !== null && eob.patientResponsibility !== null && billAmount > eob.patientResponsibility + ONE_CENT) {
    const diff = billAmount - eob.patientResponsibility;
    const claim = eob.claimNumber ? `claim ${eob.claimNumber}` : 'your claim';
    out.push(finding({
      type: 'bill_eob_mismatch',
      severity: overlap ? 'strong' : 'likely',
      confidence: overlap ? 'high' : 'medium',
      title: 'Bill doesn’t match your EOB',
      explanation: `Your insurer’s EOB for ${claim} says you owe ${formatUsd(eob.patientResponsibility)}. The bill asks for ${formatUsd(billAmount)} — ${formatUsd(diff)} more.${overlap ? '' : ' The service dates don’t line up, so check this EOB is for the same visit.'}`,
      whatYouCanDo: `Ask the provider to correct the balance to ${formatUsd(eob.patientResponsibility)}, the amount on your EOB.`,
      counterCase: 'If the insurer reprocessed the claim, or this balance includes a different visit, the amounts can differ. Ask which claim this balance belongs to.',
      amountFlagged: billAmount, amountReference: eob.patientResponsibility, amountDifference: diff,
      recommendedAction: 'dispute_eob_mismatch',
      evidence: [
        { sourceType: 'bill_header', label: 'Bill · amount you owe', value: formatUsd(billAmount) },
        { sourceType: 'eob', label: `EOB${eob.claimNumber ? ` · claim ${eob.claimNumber}` : ''}${eob.eobDate ? ` · ${eob.eobDate}` : ''}`, value: `Your responsibility: ${formatUsd(eob.patientResponsibility)}` },
      ],
    }));
  }

  // Check 4: EOB internal math (EOBs round, so $1.00 tolerance).
  if (eob.allowedAmount !== null && eob.insurerPayment !== null && eob.patientResponsibility !== null) {
    const expected = eob.allowedAmount - eob.insurerPayment;
    const diff = eob.patientResponsibility - expected;
    if (Math.abs(diff) > 100) {
      out.push(finding({
        type: 'paid_amount_mismatch',
        severity: 'likely',
        confidence: 'medium',
        title: 'Your EOB’s numbers don’t reconcile',
        explanation: `The EOB shows an allowed amount of ${formatUsd(eob.allowedAmount)} and a plan payment of ${formatUsd(eob.insurerPayment)}, which leaves ${formatUsd(expected)} — but it lists your responsibility as ${formatUsd(eob.patientResponsibility)}.`,
        whatYouCanDo: 'Call your insurer and ask them to explain how your responsibility was calculated.',
        counterCase: 'Another insurance plan paying part of the claim can explain the difference.',
        amountFlagged: eob.patientResponsibility, amountReference: expected, amountDifference: diff,
        recommendedAction: 'contact_insurer',
        evidence: [
          { sourceType: 'eob', label: 'EOB · allowed amount', value: formatUsd(eob.allowedAmount) },
          { sourceType: 'eob', label: 'EOB · plan paid', value: formatUsd(eob.insurerPayment) },
          { sourceType: 'eob', label: 'EOB · your responsibility', value: formatUsd(eob.patientResponsibility) },
        ],
      }));
    }
  }

  // Check 5: service dates.
  if (datesKnown) {
    if (!overlap) {
      out.push(finding({
        type: 'service_date_mismatch', severity: 'likely', confidence: 'medium',
        title: 'Bill and EOB cover different dates',
        explanation: `The bill is for ${toDateString(bStart)}${bEnd > bStart ? ` to ${toDateString(bEnd)}` : ''}, but the EOB covers ${toDateString(eStart)}${eEnd > eStart ? ` to ${toDateString(eEnd)}` : ''}. This may mean the EOB is for a different service.`,
        whatYouCanDo: 'Find the EOB that matches this bill’s dates before comparing amounts.',
        recommendedAction: 'verify_with_provider',
        evidence: [
          { sourceType: 'bill_header', label: 'Bill · service dates', value: `${toDateString(bStart)} – ${toDateString(bEnd)}` },
          { sourceType: 'eob', label: 'EOB · service dates', value: `${toDateString(eStart)} – ${toDateString(eEnd)}` },
        ],
      }));
    } else if (bStart < eStart || bEnd > eEnd) {
      out.push(finding({
        type: 'service_date_mismatch', severity: 'possible', confidence: 'low',
        title: 'Bill covers more dates than the EOB',
        explanation: 'The bill’s service dates extend beyond the dates on your EOB. Some charges may not have been sent to your insurer yet.',
        whatYouCanDo: 'Ask whether every date on the bill was submitted to your insurance.',
        recommendedAction: 'verify_with_provider',
        evidence: [
          { sourceType: 'bill_header', label: 'Bill · service dates', value: `${toDateString(bStart)} – ${toDateString(bEnd)}` },
          { sourceType: 'eob', label: 'EOB · service dates', value: `${toDateString(eStart)} – ${toDateString(eEnd)}` },
        ],
      }));
    }
  }
  return out;
}

// ── Check 6: quantity anomaly ─────────────────────────────────────────────
function checkQuantities({ bill }) {
  return bill.lineItems
    .filter((li) => li.quantityMillis > 1000 && isUnusualQuantityCode(li.code))
    .map((li) => finding({
      type: 'quantity_anomaly', severity: 'possible', confidence: 'low',
      title: 'Unusual quantity',
      explanation: `${li.code} (${li.description}) is billed with a quantity of ${li.quantityMillis / 1000}. This type of service is usually billed once per visit.`,
      whatYouCanDo: 'Ask the billing office to confirm the quantity for this line.',
      counterCase: 'Bilateral procedures or multiple sites can legitimately have a quantity above one.',
      amountFlagged: li.totalAmount,
      recommendedAction: 'request_itemized_bill',
      evidence: [{ sourceType: 'bill_line_item', sourceRef: li.id ?? null, label: lineLabel(li), value: lineValue(li) }],
    }));
}

// ── Balance vs patient responsibility on the same statement ───────────────
function checkBalance({ bill }) {
  if (bill.currentBalance === null || bill.patientResponsibility === null) return [];
  const diff = bill.currentBalance - bill.patientResponsibility;
  if (diff <= ONE_CENT) return [];
  return [finding({
    type: 'balance_mismatch', severity: 'likely', confidence: 'medium',
    title: 'Balance is higher than your responsibility',
    explanation: `This statement lists your responsibility as ${formatUsd(bill.patientResponsibility)} but asks for ${formatUsd(bill.currentBalance)}.`,
    whatYouCanDo: 'Ask what the additional amount is for.',
    counterCase: 'An earlier unpaid balance or a late fee can be included in the amount due.',
    amountFlagged: bill.currentBalance, amountReference: bill.patientResponsibility, amountDifference: diff,
    recommendedAction: 'verify_with_provider',
    evidence: [
      { sourceType: 'bill_header', label: 'Bill · patient responsibility', value: formatUsd(bill.patientResponsibility) },
      { sourceType: 'bill_header', label: 'Bill · balance due', value: formatUsd(bill.currentBalance) },
    ],
  })];
}

// ── Stage 2: pricing ──────────────────────────────────────────────────────
function checkPricing({ bill, eob, prices, mpfs, context }) {
  const out = [];
  const selfPay = context.hasInsurance === false || (!eob && !bill.insurancePayment && context.hasInsurance !== true);
  const priced = [];

  for (const li of bill.lineItems) {
    const code = normalizeCode(li.code);
    const ref = code ? prices?.get(code) : null;
    if (!ref) continue;
    const qty = Math.max(1, (li.quantityMillis ?? 1000) / 1000);
    const unit = li.unitPrice ?? Math.round(li.totalAmount / qty);
    const source = { sourceType: 'hospital_price_record', label: `${bill.providerName || 'Hospital'} published prices${ref.effectiveDate ? ` · ${ref.effectiveDate}` : ''}`, url: ref.sourceUrl ?? null };

    if (selfPay && ref.cashPrice !== null && unit > ref.cashPrice + ONE_CENT) {
      const diff = Math.round((unit - ref.cashPrice) * qty);
      priced.push(finding({
        type: 'price_above_cash_price', severity: 'strong', confidence: 'high',
        title: 'Charged more than the hospital’s cash price',
        explanation: `You were charged ${formatUsd(unit)} for ${code} (${li.description}). This hospital publishes a cash price of ${formatUsd(ref.cashPrice)} for the same code.`,
        whatYouCanDo: 'As a self-pay patient, ask for the published cash price to be applied.',
        counterCase: 'Published prices can be for a different setting (inpatient vs outpatient). Ask which price applies to your visit.',
        amountFlagged: unit, amountReference: ref.cashPrice, amountDifference: diff,
        recommendedAction: 'ask_cash_price',
        evidence: [{ sourceType: 'bill_line_item', sourceRef: li.id ?? null, label: lineLabel(li), value: lineValue(li) },
          { ...source, value: `Cash price ${formatUsd(ref.cashPrice)}` }],
      }));
    } else if (ref.maxRate !== null && unit > ref.maxRate + ONE_CENT) {
      const diff = Math.round((unit - ref.maxRate) * qty);
      priced.push(finding({
        type: 'price_above_negotiated_rate',
        // For insured patients the insurer's allowed amount — not the billed charge — sets what you pay.
        severity: selfPay ? 'likely' : 'informational',
        confidence: selfPay ? 'medium' : 'low',
        title: 'Above every negotiated rate',
        explanation: `${code} was billed at ${formatUsd(unit)}. The highest rate this hospital has negotiated with any insurer for this code is ${formatUsd(ref.maxRate)}.${selfPay ? '' : ' Because you have insurance, your EOB’s allowed amount is what determines what you owe.'}`,
        whatYouCanDo: selfPay ? 'Ask for a self-pay discount closer to negotiated rates.' : 'Check that your EOB shows an allowed amount, not the full billed charge.',
        amountFlagged: unit, amountReference: ref.maxRate, amountDifference: diff,
        recommendedAction: selfPay ? 'ask_cash_price' : 'none',
        evidence: [{ sourceType: 'bill_line_item', sourceRef: li.id ?? null, label: lineLabel(li), value: lineValue(li) },
          { ...source, value: `Negotiated range ${formatUsd(ref.minRate ?? ref.maxRate)} – ${formatUsd(ref.maxRate)}` }],
      }));
    }
  }
  priced.sort((a, b) => (b.amountDifference ?? 0) - (a.amountDifference ?? 0));
  out.push(...priced.slice(0, 3));

  // Medicare benchmark — reference point only, for the three largest coded charges.
  if (mpfs?.size) {
    const top = [...bill.lineItems].filter((l) => mpfs.has(normalizeCode(l.code)))
      .sort((a, b) => b.totalAmount - a.totalAmount).slice(0, 3);
    for (const li of top) {
      const code = normalizeCode(li.code);
      const m = mpfs.get(code);
      const benchmark = m.facilityAmount ?? m.nonfacilityAmount;
      if (!benchmark) continue;
      out.push(finding({
        type: 'medicare_benchmark', severity: 'informational', confidence: 'medium',
        title: `Medicare benchmark for ${code}`,
        explanation: `Medicare’s ${m.year} national rate for this service is about ${formatUsd(benchmark)}. You were charged ${formatUsd(li.totalAmount)}. This is a reference point only, not a maximum.`,
        amountFlagged: li.totalAmount, amountReference: benchmark,
        recommendedAction: 'none',
        evidence: [{ sourceType: 'bill_line_item', sourceRef: li.id ?? null, label: lineLabel(li), value: lineValue(li) },
          { sourceType: 'cms_data', label: `CMS Physician Fee Schedule ${m.year}${m.quarter ? ` (${m.quarter})` : ''}`, value: formatUsd(benchmark), url: 'https://www.cms.gov/medicare/payment/fee-schedules/physician' }],
      }));
    }
  }
  return out;
}

// ── Stage 3: rights ───────────────────────────────────────────────────────
function checkNoSurprises({ bill, eob, context }) {
  if (context.hasInsurance === false) return []; // NSA balance-billing protections are for insured patients
  const codes = bill.lineItems.map((l) => normalizeCode(l.code)).filter(Boolean);
  const outOfNetwork = context.outOfNetwork === true || eob?.networkStatus === 'out'
    || eob?.lineItems?.some((l) => l.networkStatus === 'out');
  const emergency = context.wasEmergency === true || codes.some(isEmergencyCode)
    || bill.lineItems.some((l) => /\bemergency\b|\bER visit\b|\bED visit\b/i.test(l.description));
  const ancillary = codes.some(isAncillaryCode);
  if (!outOfNetwork && !emergency) return [];

  const right = RIGHTS_BY_KEY.no_surprises_act;
  const reasons = [
    outOfNetwork && 'part of this care was billed as out-of-network',
    emergency && 'this includes emergency care',
    outOfNetwork && ancillary && 'it includes anesthesia, radiology or lab services',
  ].filter(Boolean);
  return [finding({
    type: 'no_surprises_possible',
    severity: outOfNetwork ? 'likely' : 'possible',
    confidence: 'medium',
    title: 'No Surprises Act may apply',
    explanation: `Because ${reasons.join(' and ')}, federal rules may limit what you owe to your in-network cost-sharing.`,
    whatYouCanDo: 'Ask your insurer whether this claim was processed under the No Surprises Act. If not, contact the No Surprises Help Desk at 1-800-985-3059.',
    counterCase: 'Protections don’t apply if you signed a valid notice-and-consent form for non-emergency out-of-network care.',
    recommendedAction: 'contact_insurer_nsa',
    evidence: [{ sourceType: 'cms_rule', label: right.citation, value: right.summary, url: right.sourceUrl }],
  })];
}

function checkGfe({ bill, gfe, context, today }) {
  if (!gfe || gfe.totalEstimate === null || context.hasInsurance === true) return [];
  const billed = bill.totalCharges ?? bill.currentBalance;
  if (billed === null) return [];
  const diff = billed - gfe.totalEstimate;
  if (diff < 40000) return []; // ≥ $400 threshold, 45 CFR 149.620

  const start = parseDate(context.initialBillDate ?? bill.billDate);
  const deadline = start ? addDays(start, 120) : null;
  const daysLeft = deadline ? daysBetween(today, deadline) : null;
  const expired = daysLeft !== null && daysLeft < 0;
  const urgent = daysLeft !== null && daysLeft >= 0 && daysLeft < 14;
  const right = RIGHTS_BY_KEY.good_faith_estimate;

  return [finding({
    type: 'gfe_dispute_eligible',
    severity: expired ? 'informational' : context.hasInsurance === false ? 'strong' : 'likely',
    confidence: context.hasInsurance === false ? 'high' : 'medium',
    title: expired ? 'Good Faith Estimate dispute window may have closed' : 'Eligible for a Good Faith Estimate dispute',
    explanation: `Your bill of ${formatUsd(billed)} is ${formatUsd(diff)} above your Good Faith Estimate of ${formatUsd(gfe.totalEstimate)}.`
      + (deadline ? (expired
        ? ` The 120-day window to start a dispute ended on ${toDateString(deadline)}.`
        : ` You have until ${toDateString(deadline)} (${daysLeft} days) to start a dispute.${urgent ? ' That is soon.' : ''}`) : ''),
    whatYouCanDo: expired
      ? 'You can still ask the provider to honour the estimate voluntarily.'
      : 'Start the patient-provider dispute process and ask the provider to pause collections.',
    counterCase: 'This process is for uninsured and self-pay patients. Confirm you did not bill this visit to insurance.',
    amountFlagged: billed, amountReference: gfe.totalEstimate, amountDifference: diff,
    recommendedAction: expired ? 'verify_with_provider' : 'start_ppdr',
    deadlineDate: deadline ? toDateString(deadline) : null,
    evidence: [
      { sourceType: 'gfe', label: `Good Faith Estimate${gfe.estimateDate ? ` · ${gfe.estimateDate}` : ''}`, value: formatUsd(gfe.totalEstimate) },
      { sourceType: 'bill_header', label: 'Bill · total charges', value: formatUsd(billed) },
      { sourceType: 'cms_rule', label: right.citation, value: '$400 threshold · 120-day window', url: right.sourceUrl },
    ],
  })];
}

function checkFinancialAssistance({ provider, fpl }) {
  const right = RIGHTS_BY_KEY.financial_assistance;
  const nonprofit = provider?.taxStatus === 'nonprofit';
  if (!nonprofit && !(fpl && fpl.pct <= 250)) return [];

  const fap = provider?.fap ?? null;
  const free = fap?.freeCareThresholdFpl ?? null;
  const discount = fap?.incomeThresholdFpl ?? null;
  let severity = 'possible';
  let confidence = fpl ? 'medium' : 'low';
  let detail;
  if (fpl && free !== null && fpl.pct <= free) {
    severity = 'likely';
    detail = `Your estimated income is ${fpl.pct}% of the federal poverty level, within this hospital’s free-care limit of ${free}%.`;
  } else if (fpl && discount !== null && fpl.pct <= discount) {
    detail = `Your estimated income is ${fpl.pct}% of the federal poverty level, within this hospital’s discount limit of ${discount}%.`;
  } else if (fpl) {
    detail = `Your estimated income is ${fpl.pct}% of the federal poverty level. Many hospitals offer help up to 200–400%.`;
  } else {
    detail = 'Many nonprofit hospitals reduce or forgive bills for patients up to 200–400% of the federal poverty level.';
  }

  return [finding({
    type: 'financial_assistance_eligible',
    severity: nonprofit ? severity : 'informational',
    confidence,
    title: nonprofit ? 'You may qualify for financial assistance' : 'Ask about financial assistance',
    explanation: nonprofit
      ? `${provider.name} is a nonprofit hospital, so it must offer a financial assistance program. ${detail}`
      : `${detail} Ask whether this provider has a financial assistance program.`,
    whatYouCanDo: 'Request the Financial Assistance Policy and application, and ask them to hold the account while you apply.',
    counterCase: 'The hospital decides eligibility. This is an estimate based on the information you gave.',
    recommendedAction: 'apply_financial_assistance',
    evidence: [
      { sourceType: 'cms_rule', label: right.citation, value: right.summary, url: right.sourceUrl },
      ...(fap?.fapUrl ? [{ sourceType: 'cms_data', label: `${provider.name} · financial assistance policy`, value: null, url: fap.fapUrl }] : []),
      ...(fpl ? [{ sourceType: 'cms_data', label: `HHS poverty guidelines ${fpl.year}`, value: `Household of ${fpl.householdSize}: ${fpl.pct}% FPL`, url: 'https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines' }] : []),
    ],
  })];
}

// ── Summary ───────────────────────────────────────────────────────────────
const RECOVERABLE = new Set(['duplicate_charge', 'arithmetic_error', 'price_above_cash_price',
  'price_above_negotiated_rate', 'balance_mismatch', 'gfe_dispute_eligible']);

export function potentialSavings(findings, bill) {
  const cap = bill.currentBalance ?? bill.patientResponsibility ?? null;
  const eobGap = findings.find((f) => f.type === 'bill_eob_mismatch' && f.severity !== 'informational');
  let total;
  if (eobGap) {
    // The EOB caps what you owe; line-level errors are already inside that gap.
    total = eobGap.amountDifference;
  } else {
    total = findings
      .filter((f) => RECOVERABLE.has(f.type) && (f.severity === 'strong' || f.severity === 'likely') && f.amountDifference > 0)
      .reduce((acc, f) => acc + f.amountDifference, 0);
  }
  if (!total) return null;
  return cap !== null ? Math.min(total, cap) : total;
}

export function recommendedFirstAction(findings) {
  const itemized = findings.find((f) => f.type === 'itemized_bill_missing');
  const top = itemized ?? findings.find((f) => f.recommendedAction && f.recommendedAction !== 'none');
  if (!top) return null;
  return { action: top.recommendedAction, title: top.title, findingIndex: findings.indexOf(top) };
}

/** Run every check and return findings sorted strongest-first. */
export function analyze(input) {
  const ctx = {
    ...input,
    context: input.context ?? {},
    prices: input.prices ?? new Map(),
    mpfs: input.mpfs ?? new Map(),
    today: input.today ?? new Date(),
  };
  const findings = [
    ...checkItemization(ctx),
    ...checkArithmetic(ctx),
    ...checkDuplicates(ctx),
    ...checkEob(ctx),
    ...checkBalance(ctx),
    ...checkQuantities(ctx),
    ...checkPricing(ctx),
    ...checkNoSurprises(ctx),
    ...checkGfe(ctx),
    ...checkFinancialAssistance(ctx),
  ];
  findings.sort((a, b) =>
    SEVERITY_RANK[a.severity] - SEVERITY_RANK[b.severity]
    || (b.amountDifference ?? 0) - (a.amountDifference ?? 0));
  return {
    findings,
    potentialSavings: potentialSavings(findings, ctx.bill),
    recommendedFirstAction: recommendedFirstAction(findings),
  };
}

export const LETTER_TYPE_FOR_FINDING = {
  duplicate_charge: 'duplicate_dispute',
  bill_eob_mismatch: 'eob_mismatch_dispute',
  arithmetic_error: 'itemized_bill_request',
  balance_mismatch: 'itemized_bill_request',
  quantity_anomaly: 'itemized_bill_request',
  service_date_mismatch: 'itemized_bill_request',
  itemized_bill_missing: 'itemized_bill_request',
  paid_amount_mismatch: 'insurance_appeal',
  price_above_cash_price: 'cash_price_adjustment',
  price_above_negotiated_rate: 'cash_price_adjustment',
  financial_assistance_eligible: 'financial_assistance',
  gfe_dispute_eligible: 'gfe_dispute',
  no_surprises_possible: 'nsa_dispute',
};
