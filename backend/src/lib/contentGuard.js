/**
 * Output validation for every LLM response (docs/ai/AI_PIPELINE.md).
 * 1. no prohibited phrases  2. every dollar amount must exist in the evidence bundle.
 */
export const PROHIBITED_PATTERNS = [
  /\billegal(ly)?\b/i,
  /\bfraud(ulent)?\b/i,
  /\byou definitely\b/i,
  /\bguarantee(d)?\b/i,
  /\bwill save \$[\d,]+/i,
  /\bcriminal\b/i,
  /\bsue\b/i,
  /\blawsuit\b/i,
  /\battorney\b/i,
  /\byou don'?t owe (this|anything)\b/i,
  /\bscam\b/i,
];

export function findProhibited(text) {
  if (!text) return null;
  const hit = PROHIBITED_PATTERNS.find((re) => re.test(text));
  return hit ? String(hit) : null;
}

const AMOUNT_RE = /\$\s?(\d{1,3}(?:,\d{3})*|\d+)(?:\.(\d{2}))?/g;

/** Return every dollar amount in text as integer cents. */
export function extractAmountsCents(text) {
  const out = [];
  if (!text) return out;
  for (const m of text.matchAll(AMOUNT_RE)) {
    out.push(Number(m[1].replace(/,/g, '')) * 100 + Number(m[2] || 0));
  }
  return out;
}

/** True when each amount in `text` matches an allowed amount within ±1 cent. */
export function amountsGrounded(text, allowedCents) {
  const allowed = [...allowedCents].filter((c) => Number.isFinite(c));
  return extractAmountsCents(text).every((c) => allowed.some((a) => Math.abs(a - c) <= 1));
}

export function validateGeneratedText(text, allowedCents) {
  const prohibited = findProhibited(text);
  if (prohibited) return { ok: false, reason: `prohibited:${prohibited}` };
  if (!amountsGrounded(text, allowedCents)) return { ok: false, reason: 'ungrounded_amount' };
  return { ok: true };
}
