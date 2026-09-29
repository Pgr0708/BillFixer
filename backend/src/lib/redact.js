/**
 * Last-line PII scrubbing before anything leaves for the LLM.
 * The app already sends only structured fields, so this is defence in depth.
 */
const PATTERNS = [
  [/\b\d{3}-\d{2}-\d{4}\b/g, '[SSN]'],
  [/\b(?:DOB|D\.O\.B\.|Date of Birth)\s*[:#]?\s*\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b/gi, '[DOB]'],
  [/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, '[EMAIL]'],
  [/\(?\b\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}\b/g, '[PHONE]'],
  [/\b[A-TV-Z]\d[0-9AB]\.[0-9A-TV-Z]{1,4}\b/g, '[DX]'], // ICD-10 written with a dot
];

export function redactText(value) {
  if (typeof value !== 'string') return value;
  return PATTERNS.reduce((s, [re, rep]) => s.replace(re, rep), value);
}

/** Keep only the last 4 characters of an identifier. */
export function last4(value) {
  if (!value) return null;
  const clean = String(value).replace(/\s+/g, '');
  return clean.length <= 4 ? clean : `••••${clean.slice(-4)}`;
}

export function redactDeep(obj) {
  if (Array.isArray(obj)) return obj.map(redactDeep);
  if (obj && typeof obj === 'object') {
    return Object.fromEntries(Object.entries(obj).map(([k, v]) => [k, redactDeep(v)]));
  }
  return redactText(obj);
}
