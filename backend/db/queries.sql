-- ═══════════════════════════════════════════════════════════════════════════
--  BillFixer — SQL reference: every query the API runs, plus admin operations.
--  The app always uses parameterised statements ("?"); values below are examples.
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── 0. ONE-TIME SERVER SETUP (run as MySQL root) ──────────────────────────
CREATE DATABASE IF NOT EXISTS billfixer CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER IF NOT EXISTS 'billfixer'@'localhost' IDENTIFIED BY 'CHANGE_ME_STRONG_PASSWORD';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, REFERENCES, EVENT, CREATE TEMPORARY TABLES
  ON billfixer.* TO 'billfixer'@'localhost';
FLUSH PRIVILEGES;
SET GLOBAL event_scheduler = ON;   -- also persisted in /etc/mysql/mysql.conf.d/billfixer.cnf

-- ─── 1. AUTH ───────────────────────────────────────────────────────────────
-- Apple sign-in: find or create
SELECT id, email, display_name FROM users WHERE apple_sub = ?;
INSERT INTO users (id, email, email_verified, apple_sub, display_name) VALUES (?, ?, ?, ?, ?);
-- Email sign-in
SELECT u.id, c.password_hash FROM users u JOIN user_credentials c ON c.user_id = u.id WHERE u.email = ?;
INSERT INTO user_credentials (user_id, password_hash) VALUES (?, ?);
-- Refresh token rotation
INSERT INTO refresh_tokens (id, user_id, token_hash, family_id, expires_at, user_agent) VALUES (?, ?, ?, ?, ?, ?);
SELECT id, user_id, family_id, expires_at, revoked_at FROM refresh_tokens WHERE token_hash = ? FOR UPDATE;
UPDATE refresh_tokens SET revoked_at = UTC_TIMESTAMP(), replaced_by = ? WHERE id = ?;
UPDATE refresh_tokens SET revoked_at = UTC_TIMESTAMP() WHERE family_id = ? AND revoked_at IS NULL; -- reuse detected
-- Password reset
INSERT INTO password_reset_codes (id, user_id, code_hash, expires_at) VALUES (?, ?, ?, ?);
SELECT id, code_hash, attempts FROM password_reset_codes
 WHERE user_id = ? AND used_at IS NULL AND expires_at > UTC_TIMESTAMP() ORDER BY created_at DESC LIMIT 1;

-- ─── 2. ACCOUNT ────────────────────────────────────────────────────────────
SELECT id, email, display_name, created_at FROM users WHERE id = ?;
UPDATE users SET display_name = ? WHERE id = ?;
-- DELETE /me — ONE statement hard-deletes the account and every row below it:
--   user_credentials, refresh_tokens, password_reset_codes, subscriptions, jobs, idempotency_keys,
--   cases → documents, bills → bill_line_items, eobs → eob_line_items, good_faith_estimates,
--           findings → finding_evidence, letters, phone_scripts, deadlines, case_events, outcomes
DELETE FROM users WHERE id = ?;

-- ─── 3. CASES ──────────────────────────────────────────────────────────────
SELECT c.*, (SELECT COUNT(*) FROM findings f WHERE f.case_id = c.id AND f.status = 'open') AS finding_count,
       (SELECT JSON_OBJECT('label', d.label, 'dueDate', d.due_date, 'type', d.type)
          FROM deadlines d WHERE d.case_id = c.id AND d.is_completed = 0 ORDER BY d.due_date LIMIT 1) AS next_deadline
  FROM cases c WHERE c.user_id = ? ORDER BY c.updated_at DESC LIMIT ? OFFSET ?;
SELECT COUNT(*) AS n FROM cases WHERE user_id = ? AND status IN ('draft','active','awaiting_response');
INSERT INTO cases (id, user_id, title, bill_date, initial_bill_date, service_type) VALUES (?, ?, ?, ?, ?, ?);
UPDATE cases SET title = ?, status = ?, current_balance = ?, notes = ? WHERE id = ? AND user_id = ?;
-- DELETE /cases/:id — cascades to documents, bills, line items, EOB, GFE, findings, evidence,
-- letters, scripts, deadlines, events, outcome, jobs.
DELETE FROM cases WHERE id = ? AND user_id = ?;

-- ─── 4. BILL / EOB / GFE (resubmission replaces — old line items cascade away) ──
DELETE FROM bills WHERE case_id = ?;
INSERT INTO bills (id, case_id, document_id, provider_name, account_number, bill_date, service_date_start,
  service_date_end, insurer_name, member_id_redacted, total_charges, insurance_payment, adjustments,
  previous_payments, patient_responsibility, current_balance, is_itemized, raw_ocr_confidence)
  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
INSERT INTO bill_line_items (id, bill_id, line_number, code, description, date_of_service, quantity,
  unit_price, total_amount, adjustment, is_user_edited, ocr_confidence) VALUES ?;   -- bulk
DELETE FROM eobs WHERE case_id = ?;
INSERT INTO good_faith_estimates (id, case_id, provider_name, estimate_date, total_estimate) VALUES (?, ?, ?, ?, ?)
  ON DUPLICATE KEY UPDATE provider_name = VALUES(provider_name), estimate_date = VALUES(estimate_date),
  total_estimate = VALUES(total_estimate);

-- ─── 5. ANALYSIS ───────────────────────────────────────────────────────────
INSERT INTO jobs (id, user_id, case_id, type, status, steps, payload) VALUES (?, ?, ?, 'analysis', 'queued', ?, ?);
UPDATE jobs SET status = 'running', started_at = UTC_TIMESTAMP() WHERE id = ?;
UPDATE jobs SET progress = ?, steps = ? WHERE id = ?;
UPDATE jobs SET status = 'complete', progress = 1, result_type = ?, result_id = ?, finished_at = UTC_TIMESTAMP() WHERE id = ?;
-- Stale sweeper: a crashed worker's job fails loudly instead of spinning forever
UPDATE jobs SET status = 'failed', error_code = 'WORKER_LOST', finished_at = UTC_TIMESTAMP()
 WHERE status IN ('queued','running') AND updated_at < UTC_TIMESTAMP() - INTERVAL 3 MINUTE;
DELETE FROM findings WHERE case_id = ?;   -- re-analysis replaces findings (evidence cascades)
INSERT INTO findings (id, case_id, type, severity, confidence, title, explanation, what_you_can_do, counter_case,
  amount_flagged, amount_reference, amount_difference, recommended_action, deadline_date, sort_order, llm_explained)
  VALUES ?;
INSERT INTO finding_evidence (id, finding_id, source_type, source_ref, label, value, url, sort_order) VALUES ?;
SELECT * FROM findings WHERE case_id = ? ORDER BY sort_order;
UPDATE findings SET status = ?, dismissed_at = IF(? = 'dismissed', UTC_TIMESTAMP(), NULL) WHERE id = ? AND case_id = ?;

-- ─── 6. LETTERS / SCRIPTS ──────────────────────────────────────────────────
INSERT INTO letters (id, case_id, finding_id, type, recipient_name, recipient_type, subject, content, is_fallback)
  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
UPDATE letters SET content = ?, version = version + 1 WHERE id = ? AND case_id = ?;
UPDATE letters SET sent_at = ? WHERE id = ? AND case_id = ?;
INSERT INTO phone_scripts (id, case_id, finding_id, call_target, issue_type, content, is_fallback) VALUES (?, ?, ?, ?, ?, ?, ?);

-- ─── 7. DEADLINES / TIMELINE / OUTCOME ─────────────────────────────────────
INSERT INTO deadlines (id, case_id, type, label, due_date, notify_days) VALUES (?, ?, ?, ?, ?, ?);
UPDATE deadlines SET is_completed = ?, completed_at = IF(? = 1, UTC_TIMESTAMP(), NULL) WHERE id = ? AND case_id = ?;
DELETE FROM deadlines WHERE id = ? AND case_id = ?;
INSERT INTO case_events (id, case_id, type, label, metadata, is_user_log) VALUES (?, ?, ?, ?, ?, ?);
SELECT * FROM case_events WHERE case_id = ? ORDER BY occurred_at DESC LIMIT 200;
INSERT INTO outcomes (id, case_id, resolution, original_balance, final_balance, notes) VALUES (?, ?, ?, ?, ?, ?)
  ON DUPLICATE KEY UPDATE resolution = VALUES(resolution), final_balance = VALUES(final_balance), notes = VALUES(notes);

-- ─── 8. REFERENCE DATA ─────────────────────────────────────────────────────
SELECT id, name, facility_name, city, state, tax_status, (mrf_url IS NOT NULL) AS has_mrf
  FROM providers WHERE is_active = 1 AND MATCH(name, facility_name, city) AGAINST (? IN BOOLEAN MODE)
  AND (? IS NULL OR state = ?) LIMIT 25;
SELECT code, description, cash_price, gross_charge, min_rate, max_rate, median_rate, effective_date
  FROM hospital_price_records WHERE provider_id = ? AND code IN (?);
SELECT household_size, amount FROM fpl_guidelines WHERE year = ? AND region = ? ORDER BY household_size;
SELECT code, description, nonfacility_amount, facility_amount, year, quarter FROM mpfs_rates WHERE code IN (?) AND modifier = '';

-- ─── 9. SUBSCRIPTIONS ──────────────────────────────────────────────────────
SELECT status, product_id, expires_at, grace_period_expires FROM subscriptions WHERE user_id = ?;
INSERT INTO subscriptions (id, user_id, status, product_id, entitlement, store, expires_at, grace_period_expires, last_synced_at)
  VALUES (?, ?, ?, ?, ?, ?, ?, ?, UTC_TIMESTAMP())
  ON DUPLICATE KEY UPDATE status = VALUES(status), product_id = VALUES(product_id), entitlement = VALUES(entitlement),
  store = VALUES(store), expires_at = VALUES(expires_at), grace_period_expires = VALUES(grace_period_expires),
  last_synced_at = VALUES(last_synced_at);

-- ─── 10. ADMIN / OPERATIONS ────────────────────────────────────────────────
-- Health of the data pipeline
SELECT name, status, last_checked_at, last_changed_at, error FROM data_sources;
SELECT source, status, rows_upserted, started_at, finished_at, message FROM ingest_runs ORDER BY id DESC LIMIT 20;
-- Register a hospital website so the pipeline can discover its price file (cms-hpt.txt)
UPDATE providers SET website = 'https://www.example-hospital.org' WHERE cms_facility_id = '010001';
-- Stuck/failed jobs in the last day
SELECT type, status, error_code, COUNT(*) FROM jobs WHERE created_at > UTC_TIMESTAMP() - INTERVAL 1 DAY GROUP BY 1,2,3;
-- Business metrics (no PII)
SELECT COUNT(*) AS users FROM users;
SELECT status, COUNT(*) FROM subscriptions GROUP BY status;
SELECT resolution, COUNT(*), SUM(verified_savings) FROM outcomes GROUP BY resolution;
