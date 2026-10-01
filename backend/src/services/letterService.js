import { formatUsd } from '../lib/money.js';
import { validateGeneratedText } from '../lib/contentGuard.js';
import { generateJson, SYSTEM_BASE } from './llmService.js';

/**
 * Letters: formal block-format letters for certified mail. The legal basis and requests are
 * deterministic, reviewed text; the LLM may only polish the factual opening. The letter is
 * written by the patient, not on anyone's behalf — no legal representation is implied.
 * Values the user must fill in are [BRACKETED PLACEHOLDERS].
 */
export const LETTER_TYPES = ['itemized_bill_request', 'duplicate_dispute', 'eob_mismatch_dispute', 'cash_price_adjustment',
  'financial_assistance', 'gfe_dispute', 'insurance_appeal', 'collections_dispute', 'payment_plan_request', 'nsa_dispute'];

const $ = (c) => (c === null || c === undefined ? '[AMOUNT]' : formatUsd(c));

/*
 * Each template has four parts:
 *   facts     — what happened on this account (the only part the LLM may reword)
 *   basis     — the legal/regulatory basis, fixed text reviewed against the cited rules
 *   requests  — numbered, specific actions requested of the recipient
 *   enclosures
 * Citations live ONLY in `basis`/`requests`; the LLM never adds or edits law.
 */
const HOLD = 'Place this account on billing hold and refrain from referring it to a collection agency or reporting it to any consumer reporting agency while this matter is pending.';

const TEMPLATES = {
  itemized_bill_request: (f) => ({
    subject: 'Request for Itemized Statement and Billing Records',
    facts: [
      'I am writing regarding the account referenced above. Before making any payment, I request a complete, itemized statement of every charge on this account.',
      f.findingSentence,
    ],
    basis: [
      'Billing records are part of the “designated record set” defined in the HIPAA Privacy Rule (45 CFR 164.501), and an individual has a right of access to those records under 45 CFR 164.524. That regulation generally requires a covered entity to act on a request for access no later than 30 calendar days after receiving it.',
    ],
    requests: [
      'Provide an itemized statement showing, for each charge, the date of service, the CPT®, HCPCS or revenue code, a plain-language description, the number of units and the amount charged;',
      'Show every payment, insurance adjustment, contractual allowance and write-off applied to the account;',
      HOLD,
    ],
  }),

  duplicate_dispute: (f) => ({
    subject: 'Formal Billing Dispute — Duplicate Charge',
    facts: [
      `Upon review of my statement, I found that the same service is billed more than once${f.evidenceSentence ? `: ${f.evidenceSentence}` : ''}.`,
      `According to my records, this service was rendered only once. The duplicate entry overstates my balance by ${$(f.difference)}.`,
    ],
    basis: [
      'I dispute this charge in writing and in good faith, and I ask that you investigate it and correct the account before taking any further collection action.',
    ],
    requests: [
      `Remove the duplicate charge of ${$(f.difference)} and issue a corrected statement;`,
      'If you maintain that each charge is valid, provide the documentation supporting each separately billed unit, such as the physician order and the record showing the service was performed;',
      HOLD,
    ],
    enclosures: ['Copy of the billing statement with the duplicate entries marked'],
  }),

  eob_mismatch_dispute: (f) => ({
    subject: 'Formal Billing Dispute — Balance Exceeds Explanation of Benefits',
    facts: [
      `My health plan’s Explanation of Benefits${f.claimNumber ? ` for claim ${f.claimNumber}` : ''}${f.eobDate ? `, dated ${f.eobDate},` : ''} states that my patient responsibility is ${$(f.referenceAmount)}.`,
      `Your statement seeks ${$(f.flaggedAmount)}, which is ${$(f.difference)} more than the amount determined by my health plan.`,
    ],
    basis: [
      'When a provider participates in a patient’s health plan network, its agreement with the plan generally limits what it may collect from the patient to the cost-sharing shown on the plan’s Explanation of Benefits. The additional amount you are seeking is not reflected in the adjudicated claim.',
    ],
    requests: [
      `Adjust my balance to ${$(f.referenceAmount)}, consistent with the adjudicated claim;`,
      `Alternatively, explain in writing the basis for the additional ${$(f.difference)}, identify each charge it relates to, and confirm whether those charges were submitted to my health plan;`,
      HOLD,
    ],
    enclosures: ['Explanation of Benefits from my health plan', 'Copy of your billing statement'],
  }),

  cash_price_adjustment: (f) => ({
    subject: 'Request to Apply Published Discounted Cash Price',
    facts: [
      `Your hospital’s published standard-charges file lists a discounted cash price of ${$(f.referenceAmount)}${f.code ? ` for service code ${f.code}` : ' for this service'}. I was billed ${$(f.flaggedAmount)} for the same service.`,
    ],
    basis: [
      'Under the federal hospital price transparency regulations (45 CFR Part 180), hospitals must make public their standard charges, including the discounted cash price, for the items and services they provide. As a self-pay patient, I am relying on the discounted cash price your hospital has published.',
    ],
    requests: [
      `Apply your published discounted cash price and reduce my balance by ${$(f.difference)};`,
      'If you believe a different price applies, identify the entry in your published file that you relied on and explain why the discounted cash price does not apply to my account;',
      HOLD,
    ],
    enclosures: ['Excerpt from your hospital’s published standard-charges file'],
  }),

  financial_assistance: (f) => ({
    subject: 'Application for Financial Assistance and Request to Suspend Collection',
    facts: [
      'I am writing to apply for financial assistance under your hospital’s Financial Assistance Policy for the account referenced above. Based on my household size and income, I believe I may qualify for free or discounted care.',
      f.findingSentence,
    ],
    basis: [
      'A hospital organization that is tax-exempt under Section 501(c)(3) of the Internal Revenue Code must maintain and widely publicize a written financial assistance policy (26 U.S.C. 501(r); 26 CFR 1.501(r)-4), must limit the amounts charged to eligible patients to no more than the amounts generally billed to insured patients (26 CFR 1.501(r)-5), and must suspend extraordinary collection actions while a financial assistance application is pending (26 CFR 1.501(r)-6).',
    ],
    requests: [
      'Send me your Financial Assistance Policy, its plain-language summary, the application form and a list of any supporting documents you require;',
      'Treat this letter as the start of my application and confirm in writing the date you received it;',
      'Suspend all collection activity, including any referral to a collection agency or consumer reporting agency, while my application is being processed;',
      'If I am found eligible, adjust my balance accordingly and refund any amount I have paid in excess of what I owe under the policy.',
    ],
    enclosures: ['[PROOF OF INCOME, e.g. recent pay stubs or tax return]'],
  }),

  gfe_dispute: (f) => ({
    subject: 'Dispute of Charges Exceeding Good Faith Estimate',
    facts: [
      `Before receiving care, I was given a Good Faith Estimate of ${$(f.referenceAmount)}. The bill I received totals ${$(f.flaggedAmount)}, which exceeds the estimate by ${$(f.difference)}.`,
      f.deadline ? `The 120-day period for initiating federal dispute resolution on this bill ends on ${f.deadline}.` : null,
    ],
    basis: [
      'Under the No Surprises Act’s good faith estimate rules, an uninsured or self-pay patient whose bill exceeds the provider’s good faith estimate by $400.00 or more may initiate the federal patient-provider dispute resolution process within 120 calendar days of receiving the initial bill (45 CFR 149.620). While that process is pending, the provider may not move the bill into collections and must suspend any ongoing collection activity.',
      'Before initiating that process, I am giving you the opportunity to resolve this matter directly.',
    ],
    requests: [
      `Adjust my bill to the amount stated in the Good Faith Estimate, ${$(f.referenceAmount)};`,
      'If you believe the additional charges are justified, provide an itemized bill and a written explanation of why the charges exceed the estimate;',
      HOLD,
    ],
    enclosures: ['Copy of the Good Faith Estimate', 'Copy of the bill'],
  }),

  insurance_appeal: (f) => ({
    subject: `Request for Internal Appeal of Adverse Benefit Determination${f.claimNumber ? ` — Claim No. ${f.claimNumber}` : ''}`,
    recipient: '[HEALTH PLAN NAME] — Appeals Department',
    facts: [
      'I request an internal appeal of the adverse benefit determination on the claim referenced above.',
      f.findingSentence,
    ],
    basis: [
      'I submit this appeal under my plan’s internal claims and appeals procedures, which federal law requires group health plans and health insurance issuers to provide (29 CFR 2560.503-1; 45 CFR 147.136). Those rules entitle me to a full and fair review and to receive, upon request and free of charge, reasonable access to and copies of all documents, records and other information relevant to my claim.',
    ],
    requests: [
      'Conduct a full and fair review of this claim and reprocess it in accordance with the terms of my plan;',
      'Provide copies of all documents relevant to my claim, including the plan provisions and any internal rule, guideline or criterion relied upon, and identify any medical or vocational expert whose advice was obtained;',
      'Issue a written decision stating the specific reasons for your determination and the plan provisions on which it is based, together with a description of my right to external review.',
    ],
    enclosures: ['Explanation of Benefits / denial notice', '[SUPPORTING MEDICAL RECORDS OR PROVIDER LETTER]'],
  }),

  collections_dispute: () => ({
    subject: 'Notice of Dispute and Request for Validation of Debt',
    recipient: '[COLLECTION AGENCY NAME]',
    accountLabel: 'Your reference no.',
    facts: [
      'I am responding to your communication regarding the account referenced above. I dispute this debt in its entirety and request validation.',
      'This letter is not an acknowledgment that I owe this debt and is not a promise to pay it.',
    ],
    basis: [
      'Under the Fair Debt Collection Practices Act, when a consumer disputes a debt in writing within 30 days of receiving the validation notice, the debt collector must cease collection of the debt until it obtains verification and mails it to the consumer (15 U.S.C. 1692g(b)). If you communicate information about this debt to any person, including a consumer reporting agency, you must disclose that the debt is disputed (15 U.S.C. 1692e(8)).',
    ],
    requests: [
      'Provide the name and address of the original creditor;',
      'Provide an itemization of the amount you claim, showing the original charges and any interest, fees, payments and credits since;',
      'Provide documentation showing that I am responsible for this debt and that you are authorized to collect it;',
      'Cease all collection activity until you have provided this verification.',
    ],
  }),

  payment_plan_request: (f) => ({
    subject: 'Request for Interest-Free Payment Arrangement',
    facts: [
      `I am writing to arrange payment of the balance of ${$(f.flaggedAmount)} on the account referenced above. I intend to resolve this balance but am not able to pay it in a single payment.`,
      'Before agreeing to a plan, I ask that you confirm whether I have been screened for financial assistance, as that may reduce the balance.',
    ],
    basis: [],
    requests: [
      'Accept monthly payments of [MONTHLY AMOUNT], beginning on [START DATE];',
      'Confirm in writing that no interest, late fees or finance charges will be added to the balance;',
      'Confirm that the account will not be referred to a collection agency or reported to any consumer reporting agency while payments are current;',
      'Advise me whether I qualify for financial assistance or a prompt-pay discount.',
    ],
  }),

  nsa_dispute: (f) => ({
    subject: 'Dispute of Balance Bill — No Surprises Act Protections',
    facts: [
      'I believe the charges on the account referenced above are subject to the federal No Surprises Act.',
      f.findingSentence,
    ],
    basis: [
      'The No Surprises Act (Public Health Service Act §§ 2799B-1 and 2799B-2; 42 U.S.C. 300gg-131 and 300gg-132) prohibits providers from balance billing for emergency services, and for non-emergency services furnished by out-of-network providers at in-network facilities, unless the applicable notice-and-consent requirements were satisfied (45 CFR 149.410 and 149.420). In those circumstances, my cost-sharing is limited to the in-network amount determined by my health plan.',
    ],
    requests: [
      'Confirm whether you are a participating provider in my health plan’s network;',
      'Reprocess this claim so that my responsibility does not exceed in-network cost-sharing, and issue a corrected statement;',
      'If you contend that I waived these protections, provide a copy of the signed notice-and-consent document;',
      'Refund any amount I have paid in excess of in-network cost-sharing.',
    ],
    postscript: 'If this matter is not resolved, I understand I may submit a complaint to the federal No Surprises Help Desk at 1-800-985-3059.',
    enclosures: ['Explanation of Benefits from my health plan', 'Copy of your billing statement'],
  }),
};

/** "2026-03-15" → "March 15, 2026" (also inside ranges like "2026-03-15 to 2026-03-17"). */
const longDates = (s) => (s == null ? s : String(s).replace(/\b(\d{4})-(\d{2})-(\d{2})\b/g, (_, y, m, d) =>
  new Date(Date.UTC(+y, +m - 1, +d)).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric', timeZone: 'UTC' })));

const todayLong = () => new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric', timeZone: 'UTC' });

/** Formal U.S. business letter (block format), ready for certified mail. */
export function renderLetter(t, { date = todayLong(), signerName, recipientName, providerName, accountNumber, serviceDates, claimNumber, facts }) {
  const clean = (arr) => (arr ?? []).filter((x) => typeof x === 'string' && x.trim());
  const signer = signerName || '[YOUR FULL NAME]';
  const ref = [
    `Re:     ${t.subject}`,
    `        Patient: ${signerName || '[PATIENT NAME]'}`,
    `        ${t.accountLabel ?? 'Account no.'}: ${accountNumber || '[ACCOUNT NUMBER]'}`,
    serviceDates ? `        Date(s) of service: ${serviceDates}` : null,
    claimNumber ? `        Claim no.: ${claimNumber}` : null,
  ];
  const requests = clean(t.requests);
  const lines = [
    signer, '[STREET ADDRESS]', '[CITY, STATE ZIP]', '[PHONE] · [EMAIL]', '',
    date, '',
    'SENT VIA CERTIFIED MAIL, RETURN RECEIPT REQUESTED', '',
    recipientName || t.recipient || `${providerName || '[PROVIDER NAME]'} — Patient Financial Services`,
    '[RECIPIENT ADDRESS]', '',
    ...ref, '',
    'Dear Sir or Madam:', '',
    ...clean(facts).flatMap((p) => [p, '']),
    ...clean(t.basis).flatMap((p) => [p, '']),
    ...(requests.length ? ['Accordingly, I request that you:', '', ...requests.map((r, i) => `    ${i + 1}. ${r}`), ''] : []),
    'Please respond in writing within 30 days of receipt of this letter. Please direct all communication about this matter to me in writing at the address above.',
    '',
    ...(t.postscript ? [t.postscript, ''] : []),
    'Nothing in this letter waives any right or remedy available to me under applicable federal or state law, all of which are expressly reserved.',
    '',
    'Sincerely,', '', '', '______________________________', signer,
  ];
  const enc = clean(t.enclosures);
  if (enc.length) lines.push('', `Enclosure${enc.length > 1 ? 's' : ''}:`, ...enc.map((e) => `    • ${e}`));
  return lines.filter((l) => l !== null).join('\n');
}

const CITATION_RE = /§|\bU\.?S\.?C\b|\bC\.?F\.?R\b|\bPublic Law\b|\bSection \d/i;

/** facts: { type, recipientName, providerName, accountNumber, serviceDates, claimNumber, eobDate, code,
 *           flaggedAmount, referenceAmount, difference, deadline, findingSentence, evidenceSentence } */
export async function generateLetter(rawFacts, { signerName = null } = {}) {
  const facts = { ...rawFacts, serviceDates: longDates(rawFacts.serviceDates), eobDate: longDates(rawFacts.eobDate), deadline: longDates(rawFacts.deadline) };
  const t = (TEMPLATES[facts.type] ?? TEMPLATES.itemized_bill_request)(facts);
  const allowed = new Set([facts.flaggedAmount, facts.referenceAmount, facts.difference, 40000].filter(Number.isFinite));
  const templateFacts = t.facts.filter(Boolean);

  // The LLM only rewrites the factual opening. Legal basis and requests stay fixed.
  const system = `${SYSTEM_BASE} You draft the opening factual paragraphs of a formal dispute letter written by a patient `
    + 'in the style of an experienced healthcare-billing advocate: precise, measured, first person, no emotion, no legal conclusions, '
    + 'no threats, and no statutes, regulations or case law (those are added separately). State only the facts provided. '
    + 'Use [PLACEHOLDER] for anything unknown. Return {"paragraphs": string[] (1-3 paragraphs, each <=600 chars)}.';
  const llm = await generateJson({
    task: `letter_${facts.type}`,
    system,
    input: {
      letterType: facts.type,
      subject: t.subject,
      providerName: facts.providerName,
      serviceDates: facts.serviceDates,
      claimNumber: facts.claimNumber,
      eobDate: facts.eobDate,
      code: facts.code,
      billedOrFlaggedAmount: facts.flaggedAmount != null ? formatUsd(facts.flaggedAmount) : null,
      referenceAmount: facts.referenceAmount != null ? formatUsd(facts.referenceAmount) : null,
      difference: facts.difference != null ? formatUsd(facts.difference) : null,
      issueSummary: facts.findingSentence,
      evidence: facts.evidenceSentence,
      draftToImprove: templateFacts,
    },
    maxTokens: 900,
    validate: (o) => {
      if (!Array.isArray(o?.paragraphs) || !o.paragraphs.length || o.paragraphs.length > 3
        || o.paragraphs.some((p) => typeof p !== 'string' || !p.trim() || p.length > 800)) return { ok: false, reason: 'schema' };
      const text = o.paragraphs.join('\n');
      if (CITATION_RE.test(text)) return { ok: false, reason: 'citation_in_facts' };
      const check = validateGeneratedText(text, allowed);
      return check.ok ? { ok: true, value: o } : check;
    },
  });

  return {
    subject: t.subject,
    content: renderLetter(t, { ...facts, signerName, facts: llm?.paragraphs ?? templateFacts }),
    isFallback: !llm,
  };
}
