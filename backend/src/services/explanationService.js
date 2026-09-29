import { generateJson, SYSTEM_BASE } from './llmService.js';
import { validateGeneratedText } from '../lib/contentGuard.js';

/**
 * Rewrite deterministic finding text in patient-friendly language — one LLM call for the
 * whole case. Titles/amounts/severity stay deterministic; only prose may change, and only
 * if every amount it mentions exists in that finding's evidence.
 */
const LIMITS = { title: 80, fullExplanation: 420, whatYouCanDo: 220 };

function allowedAmounts(f) {
  const set = new Set([f.amountFlagged, f.amountReference, f.amountDifference].filter((v) => Number.isFinite(v)));
  for (const e of f.evidence) {
    for (const m of String(e.value ?? '').matchAll(/\$\s?(\d{1,3}(?:,\d{3})*|\d+)(?:\.(\d{2}))?/g)) {
      set.add(Number(m[1].replace(/,/g, '')) * 100 + Number(m[2] || 0));
    }
  }
  return set;
}

export async function explainFindings(findings, { providerName }) {
  const candidates = findings.map((f, index) => ({ f, index })).filter(({ f }) => f.severity !== 'informational');
  if (!candidates.length) return findings;

  const input = {
    providerName: providerName || 'the provider',
    findings: candidates.map(({ f, index }) => ({
      index,
      type: f.type,
      severity: f.severity,
      confidence: f.confidence,
      currentTitle: f.title,
      currentExplanation: f.explanation,
      evidence: f.evidence.map((e) => `${e.label}: ${e.value ?? ''}`.trim()),
    })),
  };
  const system = `${SYSTEM_BASE} Rewrite each finding for a stressed patient. For each input item return `
    + '{"index": number, "title": string (<=80 chars), "fullExplanation": string (<=400 chars, reference the specific evidence, say what it might mean), '
    + '"whatYouCanDo": string (<=200 chars, one concrete next step)}. Output: {"items": [...]}. Keep the same index values.';

  const byIndex = new Map(candidates.map(({ f, index }) => [index, allowedAmounts(f)]));
  const result = await generateJson({
    task: 'explain_findings',
    system,
    input,
    maxTokens: 1800,
    validate: (obj) => {
      if (!Array.isArray(obj?.items)) return { ok: false, reason: 'missing items array' };
      const accepted = new Map();
      for (const item of obj.items) {
        const allowed = byIndex.get(item?.index);
        if (!allowed) continue;
        const fields = ['title', 'fullExplanation', 'whatYouCanDo'];
        const ok = fields.every((k) => typeof item[k] === 'string' && item[k].trim() && item[k].length <= LIMITS[k] + 20
          && validateGeneratedText(item[k], allowed).ok);
        if (ok) accepted.set(item.index, item);
      }
      // Partial success is fine — unaccepted findings keep their deterministic text.
      return accepted.size ? { ok: true, value: accepted } : { ok: false, reason: 'no valid items' };
    },
  });
  if (!result) return findings;

  return findings.map((f, index) => {
    const item = result.get(index);
    if (!item) return f;
    return {
      ...f,
      title: item.title.trim().slice(0, LIMITS.title),
      explanation: item.fullExplanation.trim(),
      whatYouCanDo: item.whatYouCanDo.trim(),
      llmExplained: true,
    };
  });
}
