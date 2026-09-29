import { formatUsd } from '../lib/money.js';
import { validateGeneratedText } from '../lib/contentGuard.js';
import { generateJson, SYSTEM_BASE } from './llmService.js';

/**
 * Letters: LLM draft when available and valid, otherwise a professional template.
 * Values the user must fill in are [BRACKETED PLACEHOLDERS].
 */
export const LETTER_TYPES = ['itemized_bill_request', 'duplicate_dispute', 'eob_mismatch_dispute', 'cash_price_adjustment',
  'financial_assistance', 'gfe_dispute', 'insurance_appeal', 'collections_dispute', 'payment_plan_request', 'nsa_dispute'];

const $ = (c) => (c === null || c === undefined ? '[AMOUNT]' : formatUsd(c));

const TEMPLATES = {
  itemized_bill_request: (f) => ({
    subject: 'Request for itemized statement',
    paragraphs: [
      'I am requesting a complete itemized statement for the account above before I make any payment.',
      'For each charge, please include the date of service, the CPT/HCPCS or revenue code, a description, the quantity and the amount, along with every payment and adjustment applied to the account.',
      f.findingSentence || null,
    ],
  }),
  duplicate_dispute: (f) => ({
    subject: 'Dispute of duplicate charge',
    paragraphs: [
      `My statement lists the same charge more than once: ${f.evidenceSentence || 'the lines referenced below'}.`,
      `My records indicate this service was provided once. Please remove the duplicate charge of ${$(f.difference)} and send me a corrected statement, or provide documentation showing a separate order for each charge.`,
    ],
  }),
  eob_mismatch_dispute: (f) => ({
    subject: 'Balance does not match insurer Explanation of Benefits',
    paragraphs: [
      `My insurer’s Explanation of Benefits${f.claimNumber ? ` for claim ${f.claimNumber}` : ''}${f.eobDate ? ` dated ${f.eobDate}` : ''} lists my patient responsibility as ${$(f.referenceAmount)}.`,
      `Your statement shows a balance of ${$(f.flaggedAmount)}, which is ${$(f.difference)} more than the adjudicated amount.`,
      `Please adjust my balance to ${$(f.referenceAmount)} to match the processed claim, or explain in writing what the additional ${$(f.difference)} is for. A copy of the EOB is enclosed.`,
    ],
  }),
  cash_price_adjustment: (f) => ({
    subject: 'Request to apply published cash price',
    paragraphs: [
      `Your hospital’s published price file lists a discounted cash price of ${$(f.referenceAmount)}${f.code ? ` for ${f.code}` : ''}. I was charged ${$(f.flaggedAmount)}.`,
      `As a self-pay patient, I ask that the published cash price be applied to my account, reducing the balance by ${$(f.difference)}.`,
    ],
  }),
  financial_assistance: () => ({
    subject: 'Application for financial assistance',
    paragraphs: [
      'I would like to apply for financial assistance under your hospital’s Financial Assistance Policy.',
      'Please send me the policy, the application form and a list of the documents you need. I will return the completed application promptly.',
      'I ask that you place this account on hold, and pause any collection activity, while my application is reviewed.',
    ],
  }),
  gfe_dispute: (f) => ({
    subject: 'Bill exceeds Good Faith Estimate',
    paragraphs: [
      `Before my care I received a Good Faith Estimate of ${$(f.referenceAmount)}. The bill I received totals ${$(f.flaggedAmount)}, which is ${$(f.difference)} more than the estimate.`,
      `Because the difference is $400.00 or more, I am eligible to use the patient-provider dispute resolution process under 45 CFR 149.620${f.deadline ? `, and I am within the 120-day window that ends on ${f.deadline}` : ''}.`,
      'Before starting that process, I am asking you to adjust the bill to the estimated amount. Please pause collection activity on this account while this is resolved.',
    ],
  }),
  insurance_appeal: (f) => ({
    subject: `Request for claim review${f.claimNumber ? ` — claim ${f.claimNumber}` : ''}`,
    paragraphs: [
      `I am requesting a review of the claim referenced above. ${f.findingSentence || ''}`.trim(),
      'Please explain how my responsibility was calculated, or reprocess the claim and send me an updated Explanation of Benefits.',
    ],
  }),
  collections_dispute: () => ({
    subject: 'Debt validation request',
    paragraphs: [
      'I am writing about the account referenced above. I dispute this debt and request validation.',
      'Please provide the name of the original creditor, an itemized statement of the amount claimed and documentation showing I am responsible for it. Until you provide this, please do not report the debt to credit bureaus.',
    ],
  }),
  payment_plan_request: (f) => ({
    subject: 'Request for payment plan',
    paragraphs: [
      `I would like to arrange a payment plan for the balance of ${$(f.flaggedAmount)}.`,
      'I can pay [MONTHLY AMOUNT] per month. Please confirm the plan in writing, including that no interest or fees will be added and that the account will not be sent to collections while payments are current.',
    ],
  }),
  nsa_dispute: (f) => ({
    subject: 'Request to process claim under the No Surprises Act',
    paragraphs: [
      `I believe this care may be protected under the No Surprises Act. ${f.findingSentence || ''}`.trim(),
      'Please review the claim and confirm that my cost-sharing is limited to in-network amounts. If the claim was processed as out-of-network, please reprocess it and send me an updated statement.',
    ],
  }),
};

const todayLong = () => new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric', timeZone: 'UTC' });

function renderLetter({ date = todayLong(), signerName, recipientName, providerName, accountNumber, serviceDates, claimNumber, subject, paragraphs, closing }) {
  const header = [
    date,
    '',
    recipientName || `${providerName || '[PROVIDER NAME]'} — Billing Department`,
    '[BILLING ADDRESS]',
    '',
    `Re: ${subject}`,
    `Account number: ${accountNumber || '[ACCOUNT NUMBER]'}`,
    serviceDates ? `Date(s) of service: ${serviceDates}` : null,
    claimNumber ? `Claim number: ${claimNumber}` : null,
    '',
    'To whom it may concern,',
    '',
  ].filter((l) => l !== null);
  const body = paragraphs.filter(Boolean).flatMap((p) => [p, '']);
  const footer = [
    closing || 'Thank you for your help. Please send your written response to the address below.',
    '',
    'Sincerely,',
    '',
    signerName || '[YOUR NAME]',
    '[YOUR ADDRESS]',
    '[PHONE NUMBER]',
  ];
  return [...header, ...body, ...footer].join('\n');
}

/** facts: { type, recipientName, providerName, accountNumber, serviceDates, claimNumber, eobDate, code,
 *           flaggedAmount, referenceAmount, difference, deadline, findingSentence, evidenceSentence } */
export async function generateLetter(facts, { signerName = null } = {}) {
  const template = (TEMPLATES[facts.type] ?? TEMPLATES.itemized_bill_request)(facts);
  const allowed = new Set([facts.flaggedAmount, facts.referenceAmount, facts.difference, 40000].filter(Number.isFinite));

  const system = `${SYSTEM_BASE} Write a short, polite, professional letter from a patient. Do not threaten legal action. `
    + 'Request one specific action. Use [PLACEHOLDER] for anything the patient must fill in. '
    + 'Return {"subject": string (<=100 chars), "paragraphs": string[] (2-4 paragraphs, each <=600 chars), "closing": string (<=200 chars)}.';
  const llm = await generateJson({
    task: `letter_${facts.type}`,
    system,
    input: {
      letterType: facts.type,
      providerName: facts.providerName,
      accountNumber: facts.accountNumber || '[ACCOUNT NUMBER]',
      claimNumber: facts.claimNumber,
      eobDate: facts.eobDate,
      serviceDates: facts.serviceDates,
      code: facts.code,
      billedOrFlaggedAmount: facts.flaggedAmount != null ? formatUsd(facts.flaggedAmount) : null,
      referenceAmount: facts.referenceAmount != null ? formatUsd(facts.referenceAmount) : null,
      difference: facts.difference != null ? formatUsd(facts.difference) : null,
      deadline: facts.deadline,
      issueSummary: facts.findingSentence,
      evidence: facts.evidenceSentence,
      exampleOfAcceptableLetter: template,
    },
    maxTokens: 1400,
    validate: (o) => {
      if (typeof o?.subject !== 'string' || !Array.isArray(o?.paragraphs) || !o.paragraphs.length) return { ok: false, reason: 'schema' };
      if (o.subject.length > 120 || o.paragraphs.length > 5 || o.paragraphs.some((p) => typeof p !== 'string' || p.length > 800)) {
        return { ok: false, reason: 'length' };
      }
      const text = [o.subject, ...o.paragraphs, o.closing ?? ''].join('\n');
      const check = validateGeneratedText(text, allowed);
      return check.ok ? { ok: true, value: o } : check;
    },
  });

  const chosen = llm ?? template;
  return {
    subject: chosen.subject,
    content: renderLetter({ ...facts, signerName, subject: chosen.subject, paragraphs: chosen.paragraphs, closing: llm?.closing }),
    isFallback: !llm,
  };
}
