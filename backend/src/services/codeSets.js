/**
 * Billing code reference sets used by the deterministic engine.
 * CPT® codes are AMA-owned; we use code *ranges* only, never descriptions.
 */
const inRange = (code, lo, hi) => {
  if (!/^\d{5}$/.test(code)) return false;
  const n = Number(code);
  return n >= lo && n <= hi;
};

export const normalizeCode = (code) => (code ? String(code).trim().toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 7) : null);

/** Emergency department E/M and critical care. */
export const isEmergencyCode = (c) => inRange(c, 99281, 99285) || c === '99291' || c === '99292';

/** No Surprises Act ancillary specialties: anesthesia, radiology, pathology/lab. */
export const isAncillaryCode = (c) => inRange(c, 100, 1999) || inRange(c, 70010, 79999) || inRange(c, 80047, 89398);

/**
 * Codes where the same code on the same day is commonly legitimate
 * (drug units, infusions, timed therapy, repeated labs/venipuncture) → duplicate check downgraded.
 */
export function isRepeatableCode(c) {
  if (!c) return false;
  if (/^J\d{4}$/.test(c)) return true; // injectable drugs billed per unit
  if (inRange(c, 96360, 96379)) return true; // hydration / infusion add-ons
  if (inRange(c, 97010, 97799)) return true; // physical medicine, timed units
  if (c === '36415' || c === '36416') return true; // venipuncture
  return false;
}

/** Services where quantity > 1 per encounter is unusual (BILL_ANALYSIS check 6). */
export function isUnusualQuantityCode(c) {
  if (!c) return false;
  if (inRange(c, 99202, 99215)) return true; // office E/M
  if (inRange(c, 99221, 99239)) return true; // hospital inpatient E/M
  if (inRange(c, 99242, 99255)) return true; // consultations
  if (isEmergencyCode(c)) return true;
  if (inRange(c, 10004, 69990)) return true; // surgery section
  if (inRange(c, 70010, 76499)) return true; // diagnostic radiology (not ultrasound series)
  if (inRange(c, 100, 1999)) return true; // anesthesia base
  return false;
}

export function codeType(code) {
  if (!code) return 'other';
  if (/^\d{4}[0-9A-Z]$/.test(code)) return 'hcpcs'; // CPT is HCPCS Level I
  if (/^[A-V]\d{4}$/.test(code)) return 'hcpcs'; // HCPCS Level II
  if (/^0\d{3}$/.test(code)) return 'rev_code';
  return 'other';
}
