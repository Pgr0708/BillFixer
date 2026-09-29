import { toCents } from '../lib/money.js';
import { notFound } from '../lib/errors.js';
import { query } from '../lib/db.js';
import { enqueue } from './jobRunner.js';
import { generateLetter } from './letterService.js';
import { generateScript } from './scriptService.js';
import { LETTER_TYPE_FOR_FINDING } from './analysisEngine.js';
import * as billRepo from '../repositories/billRepo.js';
import * as findingRepo from '../repositories/findingRepo.js';
import * as content from '../repositories/contentRepo.js';
import * as jobs from '../repositories/jobRepo.js';
import * as users from '../repositories/userRepo.js';

/** Turns an issue slug into words that fit "…and I have ___." in a phone script. */
const ISSUE_PHRASES = {
  itemized_bill: 'a question about the charges, and I’d like a fully itemized bill',
  itemized_bill_missing: 'a question about the charges, and I’d like a fully itemized bill',
  duplicate_charge: 'what looks like the same charge listed more than once',
  bill_eob_mismatch: 'a balance that doesn’t match what my insurer says I owe',
  arithmetic_error: 'totals that don’t add up',
  price_above_cash_price: 'a charge that’s higher than your published cash price',
  financial_assistance_eligible: 'a question about your financial assistance program',
  no_surprises_possible: 'an out-of-network charge I believe is protected by the No Surprises Act',
};
const issuePhrase = (issueType) => ISSUE_PHRASES[issueType] ?? 'a question about my bill';

const c = (v) => (v === null || v === undefined ? null : toCents(v));

/** Everything a letter or script may cite — built from stored, user-confirmed data only. */
async function buildFacts(caseId, findingId) {
  const { bill, eob } = await billRepo.loadForAnalysis(caseId);
  const found = findingId ? await findingRepo.getOne(caseId, findingId) : null;
  if (findingId && !found) throw notFound('Finding');
  const f = found?.row;

  let code = null;
  const lineRefs = (found?.evidence ?? []).map((e) => e.source_ref).filter(Boolean);
  if (lineRefs.length) {
    const [line] = await query('SELECT code FROM bill_line_items WHERE id = ?', [lineRefs[0]]);
    code = line?.code ?? null;
  }
  const serviceDates = bill?.service_date_start
    ? (bill.service_date_end && bill.service_date_end !== bill.service_date_start
      ? `${bill.service_date_start} to ${bill.service_date_end}` : bill.service_date_start)
    : null;

  return {
    providerName: bill?.provider_name ?? null,
    accountNumber: bill?.account_number ?? null,
    serviceDates,
    claimNumber: eob?.claim_number ?? null,
    eobDate: eob?.eob_date ?? null,
    code,
    flaggedAmount: c(f?.amount_flagged) ?? c(bill?.current_balance),
    referenceAmount: c(f?.amount_reference),
    difference: c(f?.amount_difference),
    deadline: f?.deadline_date ?? null,
    findingType: f?.type ?? null,
    findingSentence: f?.explanation ?? null,
    evidenceSentence: (found?.evidence ?? []).slice(0, 3).map((e) => [e.label, e.value].filter(Boolean).join(': ')).join('; ') || null,
    requestedAction: f?.what_you_can_do ?? null,
  };
}

export async function requestLetter(userId, caseId, { type, findingId, recipientName, recipientType }) {
  const jobId = await jobs.create({ userId, caseId, type: 'letter', payload: { type, findingId } });
  enqueue(jobId, async (id) => {
    const facts = await buildFacts(caseId, findingId);
    const letterType = type ?? LETTER_TYPE_FOR_FINDING[facts.findingType] ?? 'itemized_bill_request';
    // The signer's name is added at render time only — it is never part of the LLM prompt.
    const signerName = (await users.findById(userId))?.display_name ?? null;
    const letter = await generateLetter({ ...facts, type: letterType, recipientName }, { signerName });
    const letterId = await content.insertLetter(caseId, {
      findingId, type: letterType, recipientName, recipientType, subject: letter.subject, content: letter.content, isFallback: letter.isFallback,
    });
    await jobs.complete(id, 'letter', letterId, []);
  });
  return { jobId, estimatedSeconds: 15 };
}

export async function requestScript(userId, caseId, { findingId, callTarget, issueType }) {
  const jobId = await jobs.create({ userId, caseId, type: 'script', payload: { findingId, callTarget, issueType } });
  enqueue(jobId, async (id) => {
    const facts = await buildFacts(caseId, findingId);
    const script = await generateScript({ ...facts, callTarget, issueType, issueSummary: issuePhrase(issueType) });
    const scriptId = await content.insertScript(caseId, { findingId, callTarget, issueType, content: script.content, isFallback: script.isFallback });
    await jobs.complete(id, 'script', scriptId, []);
  });
  return { jobId, estimatedSeconds: 15 };
}
