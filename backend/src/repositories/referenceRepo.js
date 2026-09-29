import { query, one, queryText } from '../lib/db.js';

export function searchProviders({ q, state, limit = 20 }) {
  const terms = q.replace(/[^\p{L}\p{N}\s'-]/gu, ' ').split(/\s+/).filter((t) => t.length >= 2).slice(0, 6);
  if (!terms.length) return [];
  const boolean = terms.map((t) => `+${t}*`).join(' ');
  return query(
    `SELECT id, name, facility_name, address, city, state, zip, phone, hospital_type, tax_status, mrf_url, fap_url,
            MATCH(name, facility_name, city) AGAINST (? IN BOOLEAN MODE) AS score
       FROM providers
      WHERE is_active = 1 AND MATCH(name, facility_name, city) AGAINST (? IN BOOLEAN MODE)
        AND (? IS NULL OR state = ?)
      ORDER BY score DESC LIMIT ${Number(limit)}`,
    [boolean, boolean, state ?? null, state ?? null], { read: true },
  );
}

export const getProvider = (id) => one('SELECT * FROM providers WHERE id = ?', [id], { read: true });

/** Best-effort match of a free-text provider name (from the bill) to the directory. */
export async function matchProviderByName(name, state) {
  const rows = await searchProviders({ q: name, state, limit: 1 });
  return rows[0] ?? null;
}

export const getFap = (providerId) =>
  one('SELECT * FROM financial_assistance_policies WHERE provider_id = ?', [providerId], { read: true });

export function pricesForCodes(providerId, codes) {
  if (!codes.length) return [];
  return queryText(
    `SELECT code, code_type, description, setting, gross_charge, cash_price, min_rate, max_rate, median_rate, payer_count,
            effective_date, fetched_at
       FROM hospital_price_records WHERE provider_id = ? AND code IN (?)`,
    [providerId, codes], { read: true },
  );
}

export function mpfsForCodes(codes) {
  if (!codes.length) return [];
  return queryText(
    "SELECT code, description, nonfacility_amount, facility_amount, year, quarter FROM mpfs_rates WHERE modifier = '' AND code IN (?)",
    [codes], { read: true },
  );
}

export const fplTable = (year, region) =>
  query('SELECT household_size, amount FROM fpl_guidelines WHERE year = ? AND region = ? ORDER BY household_size', [year, region], { read: true });

export const latestFplYear = async (region) =>
  (await one('SELECT MAX(year) AS y FROM fpl_guidelines WHERE region = ?', [region], { read: true }))?.y ?? null;

export const dataSources = () => query('SELECT name, status, last_checked_at, last_changed_at FROM data_sources', [], { read: true });
