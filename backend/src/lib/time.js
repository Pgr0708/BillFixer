const DAY_MS = 86_400_000;

/** Parse 'YYYY-MM-DD' as a UTC date (no timezone drift). */
export function parseDate(s) {
  if (!s) return null;
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(s));
  if (!m) return null;
  const d = new Date(Date.UTC(+m[1], +m[2] - 1, +m[3]));
  return Number.isNaN(d.getTime()) ? null : d;
}

export const toDateString = (d) => (d ? d.toISOString().slice(0, 10) : null);
export const addDays = (d, n) => new Date(d.getTime() + n * DAY_MS);
export const daysBetween = (a, b) => Math.round((b.getTime() - a.getTime()) / DAY_MS);

export function todayUtc() {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
}

/** True when [aStart,aEnd] and [bStart,bEnd] share at least one day. */
export function rangesOverlap(aStart, aEnd, bStart, bEnd) {
  return aStart <= bEnd && bStart <= aEnd;
}

export const toIso = (d) => (d instanceof Date ? d.toISOString() : d ?? null);
