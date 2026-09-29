import { formatUsd } from '../lib/money.js';
import { validateGeneratedText } from '../lib/contentGuard.js';
import { generateJson, SYSTEM_BASE } from './llmService.js';

const $ = (c) => (c === null || c === undefined ? 'the amount on my statement' : formatUsd(c));

const branch = (trigger, response, followUp = null, childBranches = []) => ({ trigger, response, followUp, childBranches });

function fallbackScript(f) {
  const acct = f.accountNumber || '[ACCOUNT NUMBER]';
  const issue = f.issueSummary || 'a question about my bill';
  const ask = f.requestedAction || 'correct the balance';
  const target = f.callTarget;

  if (target === 'collections') {
    return {
      openingStatement: `Hi, I'm calling about account ${acct}. I'm requesting validation of this debt, including an itemized statement from the original provider. Please note that I dispute the amount.`,
      branches: [
        branch('“You need to pay today.”', 'I’m not able to make a payment until I receive written validation of the debt. Please send it to my mailing address.'),
        branch('“We’ll report this to the credit bureaus.”', 'I’m disputing this debt in writing. Please note the dispute on the account.', 'Ask for the name of the person you spoke with.'),
        branch('“We can settle for less.”', 'Thank you. Please send any settlement offer in writing, including that the account will be reported as paid in full.'),
        branch('“We don’t have the itemized bill.”', 'Then please request it from the original provider and pause collection until you have it.'),
      ],
      doNotSay: ['Don’t agree that you owe the debt.', 'Don’t give bank or card details on this call.'],
      postCallChecklist: ['Write down the date, time and the representative’s name', 'Send a written dispute within 30 days', 'Log the call in Bill Fixer'],
    };
  }

  if (target === 'insurer') {
    return {
      openingStatement: `Hi, I’m calling about a claim for account ${acct}. I’ve compared my bill and my Explanation of Benefits and I have ${issue}. Can you walk through how this claim was processed with me?`,
      branches: [
        branch('“The claim was processed correctly.”', 'Thanks. Can you tell me the allowed amount, what the plan paid, and how my responsibility was calculated?'),
        branch('“That provider is out of network.”', 'This may be protected under the No Surprises Act. Can you reprocess the claim so my cost-sharing is in-network?', 'Ask for a reference number for the reprocessing request.'),
        branch('“You’ll need to file an appeal.”', 'Okay. What’s the deadline, and where should I send it? Can you send me the appeal form?'),
        branch('“We’ll reprocess the claim.”', 'Great. When should I expect the new EOB? Can I have a reference number?'),
      ],
      doNotSay: ['Don’t guess at dates or amounts — read them from your documents.'],
      postCallChecklist: ['Get a call reference number', 'Note the deadline for any appeal', 'Log the call in Bill Fixer'],
    };
  }

  return {
    openingStatement: `Hi, I’m calling about account ${acct}. I’ve reviewed my statement and I have ${issue}. Can you look at the itemized details with me?`,
    branches: [
      branch('“The bill is correct as issued.”', `I understand. ${f.evidenceSentence ? `My documents show ${f.evidenceSentence}. ` : ''}Can you explain how the balance of ${$(f.flaggedAmount)} was calculated?`,
        'If they can’t explain it, ask for a supervisor or a billing review.'),
      branch('“We can’t adjust that — it’s final.”', `I’d like to request a formal billing review. Can you transfer me to someone who can review the account and ${ask}?`),
      branch('“Please send us documents.”', 'Of course. What’s the best address or fax, and whose attention should it go to? Can you note on the account that a review is pending?'),
      branch('“We can offer a discount.”', 'Thank you. What would the new balance be? Please send the adjusted amount to me in writing before I pay.'),
      branch('“This will go to collections.”', 'I’m actively disputing this balance. Please place a hold on the account while the review is open.', 'Ask for the hold to be noted with the date.'),
      branch('“We agreed to reduce it.”', 'Thank you. Could you confirm the new balance and send me an updated statement? Can I have a reference number for this call?'),
    ],
    doNotSay: ['Don’t accuse anyone of wrongdoing — stay factual.', 'Don’t agree to pay on the call before you have the corrected amount in writing.'],
    postCallChecklist: ['Write down the date, time and the representative’s name', 'Get a reference number', 'Ask for any change in writing', 'Log the outcome in Bill Fixer'],
  };
}

function validBranch(b, depth) {
  return b && typeof b.trigger === 'string' && typeof b.response === 'string' && b.trigger.length <= 200 && b.response.length <= 500
    && (b.followUp === null || b.followUp === undefined || typeof b.followUp === 'string')
    && (!b.childBranches || (Array.isArray(b.childBranches) && depth < 2 && b.childBranches.every((c) => validBranch(c, depth + 1))));
}

/** facts: { callTarget, issueType, accountNumber, issueSummary, evidenceSentence, requestedAction, flaggedAmount, referenceAmount, difference } */
export async function generateScript(facts) {
  const fallback = fallbackScript(facts);
  const allowed = new Set([facts.flaggedAmount, facts.referenceAmount, facts.difference].filter(Number.isFinite));

  const system = `${SYSTEM_BASE} Write a phone script for a patient. Keep each response under three sentences. Never threaten legal action. `
    + 'Return {"openingStatement": string, "branches": [{"trigger": string, "response": string, "followUp": string|null, "childBranches": []}] (4-6 items), '
    + '"doNotSay": string[], "postCallChecklist": string[]}.';
  const llm = await generateJson({
    task: `script_${facts.callTarget}`,
    system,
    input: {
      callTarget: facts.callTarget,
      issueType: facts.issueType,
      accountNumber: facts.accountNumber || '[ACCOUNT NUMBER]',
      keyFacts: [facts.issueSummary, facts.evidenceSentence].filter(Boolean),
      amounts: {
        flagged: facts.flaggedAmount != null ? formatUsd(facts.flaggedAmount) : null,
        reference: facts.referenceAmount != null ? formatUsd(facts.referenceAmount) : null,
        difference: facts.difference != null ? formatUsd(facts.difference) : null,
      },
      exampleOfAcceptableScript: fallback,
    },
    maxTokens: 1800,
    validate: (o) => {
      const shapeOk = typeof o?.openingStatement === 'string' && o.openingStatement.length <= 600
        && Array.isArray(o.branches) && o.branches.length >= 3 && o.branches.length <= 8 && o.branches.every((b) => validBranch(b, 0))
        && Array.isArray(o.postCallChecklist) && o.postCallChecklist.every((s) => typeof s === 'string');
      if (!shapeOk) return { ok: false, reason: 'schema' };
      const text = JSON.stringify(o);
      const check = validateGeneratedText(text, allowed);
      if (!check.ok) return check;
      return { ok: true, value: { ...o, doNotSay: Array.isArray(o.doNotSay) ? o.doNotSay.filter((s) => typeof s === 'string') : [] } };
    },
  });
  return { content: llm ?? fallback, isFallback: !llm };
}

/** Static library for the Learn tab (no case needed). */
export const SCRIPT_LIBRARY = [
  { key: 'duplicate', title: 'Dispute a duplicate charge', callTarget: 'provider_billing', branchCount: 6, tag: 'Most used' },
  { key: 'eob_mismatch', title: 'Reconcile bill against EOB', callTarget: 'provider_billing', branchCount: 6, tag: null },
  { key: 'financial_assistance', title: 'Ask for financial assistance', callTarget: 'provider_billing', branchCount: 6, tag: null },
  { key: 'claim_review', title: 'Appeal or review a claim', callTarget: 'insurer', branchCount: 4, tag: null },
  { key: 'collections', title: 'Respond to a collector', callTarget: 'collections', branchCount: 4, tag: 'Know your rights' },
].map((s) => ({ ...s, script: fallbackScript({ callTarget: s.callTarget, issueSummary: s.title.toLowerCase() }) }));
