import { query, one } from '../lib/db.js';

export const get = (userId) =>
  one('SELECT household_size, annual_income, state, updated_at FROM financial_profiles WHERE user_id = ?', [userId]);

export const upsert = (userId, { householdSize, annualIncome, state }) =>
  query(
    `INSERT INTO financial_profiles (user_id, household_size, annual_income, state) VALUES (?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE household_size = VALUES(household_size), annual_income = VALUES(annual_income), state = VALUES(state)`,
    [userId, householdSize, annualIncome, state ?? null],
  );

export const remove = (userId) => query('DELETE FROM financial_profiles WHERE user_id = ?', [userId]);

/** Open cases that already have a confirmed bill — the ones worth re-checking when income changes. */
export const openCasesWithBill = (userId, limit = 10) =>
  query(
    `SELECT c.id FROM cases c WHERE c.user_id = ? AND c.status IN ('draft','active','awaiting_response')
       AND EXISTS (SELECT 1 FROM bills b WHERE b.case_id = c.id)
     ORDER BY c.updated_at DESC LIMIT ?`,
    [userId, limit],
  );
