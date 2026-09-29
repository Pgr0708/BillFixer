/**
 * Money math in integer cents. Floats never touch a dollar amount.
 * MySQL DECIMAL arrives as a string (mysql2 decimalNumbers=false), which parses exactly.
 */
const MONEY_RE = /^-?\d{1,10}(\.\d{1,2})?$/;

export function toCents(value) {
  if (value === null || value === undefined || value === '') return null;
  const s = typeof value === 'number' ? value.toFixed(2) : String(value).trim();
  if (!MONEY_RE.test(s)) throw new RangeError(`Invalid money value: ${s}`);
  const negative = s.startsWith('-');
  const [whole, frac = ''] = s.replace('-', '').split('.');
  const cents = Number(whole) * 100 + Number(frac.padEnd(2, '0'));
  if (!Number.isSafeInteger(cents)) throw new RangeError('Money value out of range');
  return negative ? -cents : cents;
}

export function fromCents(cents) {
  if (cents === null || cents === undefined) return null;
  const negative = cents < 0;
  const abs = Math.abs(cents);
  const s = `${Math.trunc(abs / 100)}.${String(abs % 100).padStart(2, '0')}`;
  return negative ? `-${s}` : s;
}

/** "$1,234.56" for human-facing text. */
export function formatUsd(cents) {
  if (cents === null || cents === undefined) return '';
  const negative = cents < 0;
  const abs = Math.abs(cents);
  const dollars = Math.trunc(abs / 100).toLocaleString('en-US');
  return `${negative ? '-' : ''}$${dollars}.${String(abs % 100).padStart(2, '0')}`;
}

export const sumCents = (values) => values.reduce((acc, v) => acc + (v ?? 0), 0);

/** Quantities are DECIMAL(8,3): parse to thousandths so qty×price stays exact. */
export function toMillis(value) {
  if (value === null || value === undefined || value === '') return null;
  const s = String(value).trim();
  if (!/^\d{1,5}(\.\d{1,3})?$/.test(s)) throw new RangeError(`Invalid quantity: ${s}`);
  const [whole, frac = ''] = s.split('.');
  return Number(whole) * 1000 + Number(frac.padEnd(3, '0'));
}

/** Median of integer cents (rounded half-up to the cent). */
export function medianCents(values) {
  const v = values.filter((x) => Number.isFinite(x)).sort((a, b) => a - b);
  if (!v.length) return null;
  const mid = Math.floor(v.length / 2);
  return v.length % 2 ? v[mid] : Math.round((v[mid - 1] + v[mid]) / 2);
}
