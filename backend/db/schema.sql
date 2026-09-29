-- ═══════════════════════════════════════════════════════════════════════════
--  BillFixer — MySQL 8.0 schema
--  Idempotent: safe to run repeatedly (CREATE ... IF NOT EXISTS).
--  Run:  mysql -u billfixer -p billfixer < db/schema.sql      (or: npm run migrate)
--
--  Rules (docs/data/DATA_MODEL.md):
--   • Money is DECIMAL — never FLOAT.   • All DATETIME values are UTC.
--   • IDs are UUID CHAR(36).             • Medical data is HARD-deleted:
--     every child table cascades from its parent, so
--       DELETE FROM users WHERE id = ?   removes the account and ALL its data,
--       DELETE FROM cases WHERE id = ?   removes the case and ALL its data.
-- ═══════════════════════════════════════════════════════════════════════════

SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE TABLE IF NOT EXISTS schema_migrations (
  name        VARCHAR(100) PRIMARY KEY,
  checksum    CHAR(64)     NOT NULL,
  applied_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ── Accounts ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id              CHAR(36)      NOT NULL PRIMARY KEY,
  email           VARCHAR(255)  NULL,
  email_verified  TINYINT(1)    NOT NULL DEFAULT 0,
  apple_sub       VARCHAR(255)  NULL,
  display_name    VARCHAR(120)  NULL,
  created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  last_active_at  DATETIME      NULL,
  UNIQUE KEY uq_users_email (email),
  UNIQUE KEY uq_users_apple (apple_sub)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS user_credentials (
  user_id        CHAR(36)     NOT NULL PRIMARY KEY,
  password_hash  VARCHAR(100) NOT NULL,
  updated_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_cred_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id           CHAR(36)     NOT NULL PRIMARY KEY,
  user_id      CHAR(36)     NOT NULL,
  token_hash   CHAR(64)     NOT NULL,
  family_id    CHAR(36)     NOT NULL,              -- rotation family: reuse of a rotated token revokes the family
  expires_at   DATETIME     NOT NULL,
  revoked_at   DATETIME     NULL,
  replaced_by  CHAR(36)     NULL,
  user_agent   VARCHAR(200) NULL,
  created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_refresh_hash (token_hash),
  KEY ix_refresh_user (user_id),
  KEY ix_refresh_family (family_id),
  KEY ix_refresh_expiry (expires_at),
  CONSTRAINT fk_refresh_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS password_reset_codes (
  id          CHAR(36)   NOT NULL PRIMARY KEY,
  user_id     CHAR(36)   NOT NULL,
  code_hash   CHAR(64)   NOT NULL,
  attempts    TINYINT    NOT NULL DEFAULT 0,
  expires_at  DATETIME   NOT NULL,
  used_at     DATETIME   NULL,
  created_at  DATETIME   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_reset_user (user_id, created_at),
  CONSTRAINT fk_reset_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS subscriptions (
  id                       CHAR(36)     NOT NULL PRIMARY KEY,
  user_id                  CHAR(36)     NOT NULL,
  status                   ENUM('free','active','expired','in_grace','paused','revoked') NOT NULL DEFAULT 'free',
  product_id               VARCHAR(120) NULL,
  entitlement              VARCHAR(60)  NULL,
  store                    VARCHAR(30)  NULL,
  original_transaction_id  VARCHAR(255) NULL,
  expires_at               DATETIME     NULL,
  grace_period_expires     DATETIME     NULL,
  last_synced_at           DATETIME     NULL,
  created_at               DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at               DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_sub_user (user_id),
  CONSTRAINT fk_sub_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ── Reference: hospital directory (CMS Hospital General Information) ─────────
CREATE TABLE IF NOT EXISTS providers (
  id                  CHAR(36)      NOT NULL PRIMARY KEY,
  cms_facility_id     VARCHAR(20)   NULL,
  npi                 VARCHAR(20)   NULL,
  name                VARCHAR(500)  NOT NULL,
  facility_name       VARCHAR(500)  NULL,
  address             VARCHAR(500)  NULL,
  city                VARCHAR(100)  NULL,
  state               CHAR(2)       NULL,
  zip                 VARCHAR(10)   NULL,
  phone               VARCHAR(20)   NULL,
  website             VARCHAR(2000) NULL,   -- set by admin / pipeline CLI; used to discover cms-hpt.txt
  hospital_type       VARCHAR(120)  NULL,
  ownership_raw       VARCHAR(120)  NULL,
  tax_status          ENUM('nonprofit','for_profit','government','unknown') NOT NULL DEFAULT 'unknown',
  emergency_services  TINYINT(1)    NULL,
  mrf_url             VARCHAR(2000) NULL,
  mrf_format          ENUM('json','csv_tall','csv_wide','unknown') NULL,
  mrf_last_fetched    DATETIME      NULL,
  mrf_etag            VARCHAR(255)  NULL,
  mrf_last_modified   VARCHAR(100)  NULL,
  fap_url             VARCHAR(2000) NULL,
  is_active           TINYINT(1)    NOT NULL DEFAULT 1,
  source_updated_at   DATE          NULL,
  created_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_provider_cms (cms_facility_id),
  UNIQUE KEY uq_provider_npi (npi),
  KEY ix_provider_state_city (state, city),
  FULLTEXT KEY ft_provider_name (name, facility_name, city)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS hospital_price_records (
  id                CHAR(36)      NOT NULL PRIMARY KEY,
  provider_id       CHAR(36)      NOT NULL,
  code              VARCHAR(20)   NOT NULL,
  code_type         ENUM('hcpcs','cpt','icd','drg','ms_drg','rev_code','ndc','other') NOT NULL DEFAULT 'other',
  description       VARCHAR(500)  NULL,
  setting           ENUM('inpatient','outpatient','both','unknown') NOT NULL DEFAULT 'unknown',
  gross_charge      DECIMAL(12,2) NULL,
  cash_price        DECIMAL(12,2) NULL,
  min_rate          DECIMAL(12,2) NULL,
  max_rate          DECIMAL(12,2) NULL,
  median_rate       DECIMAL(12,2) NULL,
  payer_count       INT           NOT NULL DEFAULT 0,
  effective_date    DATE          NULL,
  mrf_version       VARCHAR(50)   NULL,
  fetched_at        DATETIME      NOT NULL,
  created_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_price (provider_id, code, code_type, setting),
  KEY ix_price_code (code),
  CONSTRAINT fk_price_provider FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS financial_assistance_policies (
  id                       CHAR(36)      NOT NULL PRIMARY KEY,
  provider_id              CHAR(36)      NOT NULL,
  fap_url                  VARCHAR(2000) NULL,
  income_threshold_fpl     DECIMAL(6,2)  NULL,   -- 300.00 = discounts up to 300% FPL
  free_care_threshold_fpl  DECIMAL(6,2)  NULL,   -- 200.00 = free care up to 200% FPL
  application_url          VARCHAR(2000) NULL,
  application_phone        VARCHAR(20)   NULL,
  allows_retroactive       TINYINT(1)    NULL,
  required_docs            JSON          NULL,
  effective_date           DATE          NULL,
  fetched_at               DATETIME      NULL,
  created_at               DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at               DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_fap_provider (provider_id),
  CONSTRAINT fk_fap_provider FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ── Reference: HHS poverty guidelines (ASPE API) ─────────────────────────────
CREATE TABLE IF NOT EXISTS fpl_guidelines (
  year            SMALLINT      NOT NULL,
  region          ENUM('us','ak','hi') NOT NULL,   -- us = 48 contiguous states + DC
  household_size  TINYINT       NOT NULL,          -- 1..8 (larger sizes derive from the per-person increment)
  amount          DECIMAL(10,2) NOT NULL,
  source_url      VARCHAR(500)  NOT NULL,
  fetched_at      DATETIME      NOT NULL,
  PRIMARY KEY (year, region, household_size),
  CONSTRAINT ck_fpl_size CHECK (household_size BETWEEN 1 AND 8)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ── Reference: Medicare Physician Fee Schedule national amounts (benchmark only) ─
CREATE TABLE IF NOT EXISTS mpfs_rates (
  code                VARCHAR(10)   NOT NULL,
  modifier            VARCHAR(4)    NOT NULL DEFAULT '',
  description         VARCHAR(200)  NULL,
  status_code         CHAR(1)       NULL,
  nonfacility_amount  DECIMAL(10,2) NULL,
  facility_amount     DECIMAL(10,2) NULL,
  conversion_factor   DECIMAL(8,4)  NOT NULL,
  year                SMALLINT      NOT NULL,
  quarter             CHAR(1)       NOT NULL,
  fetched_at          DATETIME      NOT NULL,
  PRIMARY KEY (code, modifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ── Pipeline bookkeeping ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS data_sources (
  name             VARCHAR(60)   NOT NULL PRIMARY KEY,
  source_url       VARCHAR(2000) NULL,
  etag             VARCHAR(255)  NULL,
  last_modified    VARCHAR(100)  NULL,
  content_hash     CHAR(64)      NULL,
  last_checked_at  DATETIME      NULL,
  last_changed_at  DATETIME      NULL,
  status           ENUM('ok','error','never') NOT NULL DEFAULT 'never',
  error            VARCHAR(1000) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS ingest_runs (
  id             BIGINT        NOT NULL AUTO_INCREMENT PRIMARY KEY,
  source         VARCHAR(60)   NOT NULL,
  started_at     DATETIME      NOT NULL,
  finished_at    DATETIME      NULL,
  status         ENUM('running','ok','skipped','error') NOT NULL DEFAULT 'running',
  rows_upserted  INT           NOT NULL DEFAULT 0,
  message        VARCHAR(1000) NULL,
  KEY ix_ingest_source (source, started_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ── Cases and everything that hangs off a case ───────────────────────────────
CREATE TABLE IF NOT EXISTS cases (
  id                 CHAR(36)      NOT NULL PRIMARY KEY,
  user_id            CHAR(36)      NOT NULL,
  title              VARCHAR(255)  NOT NULL,
  provider_id        CHAR(36)      NULL,
  provider_name      VARCHAR(255)  NULL,
  status             ENUM('draft','active','awaiting_response','resolved','closed') NOT NULL DEFAULT 'draft',
  bill_date          DATE          NULL,
  initial_bill_date  DATE          NULL,   -- starts the 120-day PPDR clock
  service_type       VARCHAR(100)  NULL,
  insurer_name       VARCHAR(255)  NULL,
  original_balance   DECIMAL(10,2) NULL,
  current_balance    DECIMAL(10,2) NULL,
  final_balance      DECIMAL(10,2) NULL,
  verified_savings   DECIMAL(10,2) NULL,
  potential_savings  DECIMAL(10,2) NULL,
  notes              TEXT          NULL,
  last_analyzed_at   DATETIME      NULL,
  created_at         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY ix_cases_user (user_id, status, updated_at),
  CONSTRAINT fk_case_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_case_provider FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Metadata only. Page images and OCR text never leave the phone (ADR-002).
CREATE TABLE IF NOT EXISTS documents (
  id               CHAR(36)     NOT NULL PRIMARY KEY,
  case_id          CHAR(36)     NOT NULL,
  type             ENUM('bill','eob','gfe','other') NOT NULL,
  source           ENUM('camera','pdf','photos') NOT NULL,
  page_count       INT          NOT NULL DEFAULT 1,
  ocr_confidence   DECIMAL(5,4) NULL,
  sha256           CHAR(64)     NULL,
  created_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_docs_case (case_id),
  CONSTRAINT fk_doc_case FOREIGN KEY (case_id) REFERENCES cases(id) ON DELETE CASCADE,
  CONSTRAINT ck_doc_pages CHECK (page_count BETWEEN 1 AND 200)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS bills (
  id                      CHAR(36)      NOT NULL PRIMARY KEY,
  case_id                 CHAR(36)      NOT NULL,
  document_id             CHAR(36)      NULL,
  provider_name           VARCHAR(255)  NULL,
  provider_npi            VARCHAR(20)   NULL,
  account_number          VARCHAR(100)  NULL,
  bill_date               DATE          NULL,
  service_date_start      DATE          NULL,
  service_date_end        DATE          NULL,
  insurer_name            VARCHAR(255)  NULL,
  member_id_redacted      VARCHAR(50)   NULL,   -- last 4 only
  total_charges           DECIMAL(10,2) NULL,
  insurance_payment       DECIMAL(10,2) NULL,
  adjustments             DECIMAL(10,2) NULL,
  previous_payments       DECIMAL(10,2) NULL,
  patient_responsibility  DECIMAL(10,2) NULL,
  current_balance         DECIMAL(10,2) NULL,
  is_itemized             TINYINT(1)    NOT NULL DEFAULT 0,
  raw_ocr_confidence      DECIMAL(5,4)  NULL,
  created_at              DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_bill_case (case_id),             -- 1:1 — resubmitting replaces the bill
  CONSTRAINT fk_bill_case FOREIGN KEY (case_id) REFERENCES cases(id) ON DELETE CASCADE,
  CONSTRAINT fk_bill_doc FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS bill_line_items (
  id               CHAR(36)      NOT NULL PRIMARY KEY,
  bill_id          CHAR(36)      NOT NULL,
  line_number      INT           NOT NULL,
  code             VARCHAR(20)   NULL,
  description      VARCHAR(500)  NOT NULL,
  date_of_service  DATE          NULL,
  quantity         DECIMAL(8,3)  NOT NULL DEFAULT 1.000,
  unit_price       DECIMAL(10,2) NULL,
  total_amount     DECIMAL(10,2) NOT NULL,
  adjustment       DECIMAL(10,2) NULL,
  is_user_edited   TINYINT(1)    NOT NULL DEFAULT 0,
  ocr_confidence   DECIMAL(5,4)  NULL,
  created_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_bli_bill (bill_id, line_number),
  CONSTRAINT fk_bli_bill FOREIGN KEY (bill_id) REFERENCES bills(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS eobs (
  id                      CHAR(36)      NOT NULL PRIMARY KEY,
  case_id                 CHAR(36)      NOT NULL,
  document_id             CHAR(36)      NULL,
  claim_number            VARCHAR(100)  NULL,
  eob_date                DATE          NULL,
  insurer_name            VARCHAR(255)  NULL,
  member_id_redacted      VARCHAR(50)   NULL,
  service_date_start      DATE          NULL,
  service_date_end        DATE          NULL,
  provider_name           VARCHAR(255)  NULL,
  network_status          ENUM('in','out','unknown') NOT NULL DEFAULT 'unknown',
  billed_amount           DECIMAL(10,2) NULL,
  allowed_amount          DECIMAL(10,2) NULL,
  insurer_payment         DECIMAL(10,2) NULL,
  deductible_applied      DECIMAL(10,2) NULL,
  copay                   DECIMAL(10,2) NULL,
  coinsurance             DECIMAL(10,2) NULL,
  patient_responsibility  DECIMAL(10,2) NULL,
  created_at              DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_eob_case (case_id),
  CONSTRAINT fk_eob_case FOREIGN KEY (case_id) REFERENCES cases(id) ON DELETE CASCADE,
  CONSTRAINT fk_eob_doc FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS eob_line_items (
  id                      CHAR(36)      NOT NULL PRIMARY KEY,
  eob_id                  CHAR(36)      NOT NULL,
  line_number             INT           NOT NULL,
  code                    VARCHAR(20)   NULL,
  description             VARCHAR(500)  NULL,
  date_of_service         DATE          NULL,
  billed_amount           DECIMAL(10,2) NULL,
  allowed_amount          DECIMAL(10,2) NULL,
  insurer_paid            DECIMAL(10,2) NULL,
  patient_responsibility  DECIMAL(10,2) NULL,
  network_status          ENUM('in','out','unknown') NOT NULL DEFAULT 'unknown',
  created_at              DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_eli_eob (eob_id, line_number),
  CONSTRAINT fk_eli_eob FOREIGN KEY (eob_id) REFERENCES eobs(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS good_faith_estimates (
  id              CHAR(36)      NOT NULL PRIMARY KEY,
  case_id         CHAR(36)      NOT NULL,
  provider_name   VARCHAR(255)  NULL,
  estimate_date   DATE          NULL,
  total_estimate  DECIMAL(10,2) NOT NULL,
  created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_gfe_case (case_id),
  CONSTRAINT fk_gfe_case FOREIGN KEY (case_id) REFERENCES cases(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS findings (
  id                  CHAR(36)      NOT NULL PRIMARY KEY,
  case_id             CHAR(36)      NOT NULL,
  type                ENUM('duplicate_charge','bill_eob_mismatch','arithmetic_error','quantity_anomaly',
                           'service_date_mismatch','price_above_cash_price','price_above_negotiated_rate',
                           'medicare_benchmark','financial_assistance_eligible','no_surprises_possible',
                           'gfe_dispute_eligible','paid_amount_mismatch','balance_mismatch',
                           'itemized_bill_missing','informational') NOT NULL,
  severity            ENUM('strong','likely','possible','informational') NOT NULL,
  confidence          ENUM('high','medium','low') NOT NULL,
  title               VARCHAR(500)  NOT NULL,
  explanation         TEXT          NOT NULL,
  what_you_can_do     VARCHAR(600)  NULL,
  counter_case        VARCHAR(600)  NULL,   -- "this could be legitimate if…" — required on strong findings
  amount_flagged      DECIMAL(10,2) NULL,
  amount_reference    DECIMAL(10,2) NULL,
  amount_difference   DECIMAL(10,2) NULL,
  recommended_action  VARCHAR(60)   NULL,
  deadline_date       DATE          NULL,
  sort_order          INT           NOT NULL DEFAULT 0,
  llm_explained       TINYINT(1)    NOT NULL DEFAULT 0,
  status              ENUM('open','dismissed','fixed','partially_fixed','denied','wrong') NOT NULL DEFAULT 'open',
  dismissed_at        DATETIME      NULL,
  created_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY ix_findings_case (case_id, sort_order),
  CONSTRAINT fk_finding_case FOREIGN KEY (case_id) REFERENCES cases(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS finding_evidence (
  id           CHAR(36)      NOT NULL PRIMARY KEY,
  finding_id   CHAR(36)      NOT NULL,
  source_type  ENUM('bill_line_item','bill_header','eob','eob_line_item','gfe','hospital_price_record',
                    'cms_rule','cms_data','manual') NOT NULL,
  source_ref   VARCHAR(100)  NULL,
  label        VARCHAR(500)  NOT NULL,   -- "Bill · line 3"
  value        VARCHAR(500)  NULL,       -- "03/15  71046  Chest X-Ray 2 Views  $420.00"
  url          VARCHAR(2000) NULL,
  sort_order   INT           NOT NULL DEFAULT 0,
  created_at   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_evidence_finding (finding_id, sort_order),
  CONSTRAINT fk_evidence_finding FOREIGN KEY (finding_id) REFERENCES findings(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS letters (
  id              CHAR(36)     NOT NULL PRIMARY KEY,
  case_id         CHAR(36)     NOT NULL,
  finding_id      CHAR(36)     NULL,
  type            ENUM('itemized_bill_request','duplicate_dispute','eob_mismatch_dispute','cash_price_adjustment',
                       'financial_assistance','gfe_dispute','insurance_appeal','collections_dispute',
                       'payment_plan_request','nsa_dispute') NOT NULL,
  recipient_name  VARCHAR(255) NULL,
  recipient_type  ENUM('provider','insurer','collections','other') NOT NULL DEFAULT 'provider',
  subject         VARCHAR(300) NULL,
  content         MEDIUMTEXT   NOT NULL,
  version         INT          NOT NULL DEFAULT 1,
  is_fallback     TINYINT(1)   NOT NULL DEFAULT 0,
  sent_at         DATETIME     NULL,
  created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY ix_letters_case (case_id, created_at),
  CONSTRAINT fk_letter_case FOREIGN KEY (case_id) REFERENCES cases(id) ON DELETE CASCADE,
  CONSTRAINT fk_letter_finding FOREIGN KEY (finding_id) REFERENCES findings(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS phone_scripts (
  id           CHAR(36)     NOT NULL PRIMARY KEY,
  case_id      CHAR(36)     NOT NULL,
  finding_id   CHAR(36)     NULL,
  call_target  ENUM('provider_billing','insurer','collections') NOT NULL,
  issue_type   VARCHAR(60)  NOT NULL,
  content      JSON         NOT NULL,   -- { openingStatement, branches[], doNotSay[], postCallChecklist[] }
  is_fallback  TINYINT(1)   NOT NULL DEFAULT 0,
  created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_scripts_case (case_id, created_at),
  CONSTRAINT fk_script_case FOREIGN KEY (case_id) REFERENCES cases(id) ON DELETE CASCADE,
  CONSTRAINT fk_script_finding FOREIGN KEY (finding_id) REFERENCES findings(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS deadlines (
  id            CHAR(36)     NOT NULL PRIMARY KEY,
  case_id       CHAR(36)     NOT NULL,
  type          ENUM('ppdr_120day','insurance_appeal','follow_up','fa_application','custom') NOT NULL,
  label         VARCHAR(255) NOT NULL,
  due_date      DATE         NOT NULL,
  is_completed  TINYINT(1)   NOT NULL DEFAULT 0,
  completed_at  DATETIME     NULL,
  notify_days   JSON         NULL,   -- e.g. [14, 7, 1]
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_deadlines_case (case_id, due_date),
  CONSTRAINT fk_deadline_case FOREIGN KEY (case_id) REFERENCES cases(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS case_events (
  id           CHAR(36)     NOT NULL PRIMARY KEY,
  case_id      CHAR(36)     NOT NULL,
  type         ENUM('case_created','document_added','analysis_run','finding_added','letter_generated','letter_sent',
                    'script_generated','response_received','balance_updated','case_resolved','note_added',
                    'deadline_set','reminder_sent','custom') NOT NULL,
  label        VARCHAR(500) NOT NULL,
  metadata     JSON         NULL,
  is_user_log  TINYINT(1)   NOT NULL DEFAULT 0,
  occurred_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_events_case (case_id, occurred_at),
  CONSTRAINT fk_event_case FOREIGN KEY (case_id) REFERENCES cases(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS outcomes (
  id                CHAR(36)      NOT NULL PRIMARY KEY,
  case_id           CHAR(36)      NOT NULL,
  resolution        ENUM('full_reduction','partial_reduction','denied','financial_assistance','payment_plan','no_change','other') NOT NULL,
  original_balance  DECIMAL(10,2) NULL,
  final_balance     DECIMAL(10,2) NULL,
  verified_savings  DECIMAL(10,2) GENERATED ALWAYS AS (IFNULL(original_balance,0) - IFNULL(final_balance,0)) STORED,
  notes             TEXT          NULL,
  resolved_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_outcome_case (case_id),
  CONSTRAINT fk_outcome_case FOREIGN KEY (case_id) REFERENCES cases(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Background jobs (analysis / letters / scripts). State lives in MySQL so any PM2
-- worker or server can serve the status poll, and a crash can't lose a job silently.
CREATE TABLE IF NOT EXISTS jobs (
  id           CHAR(36)     NOT NULL PRIMARY KEY,
  user_id      CHAR(36)     NOT NULL,
  case_id      CHAR(36)     NULL,
  type         ENUM('analysis','letter','script') NOT NULL,
  status       ENUM('queued','running','complete','failed') NOT NULL DEFAULT 'queued',
  progress     DECIMAL(4,3) NOT NULL DEFAULT 0.000,
  steps        JSON         NULL,
  payload      JSON         NULL,
  result_type  VARCHAR(30)  NULL,
  result_id    CHAR(36)     NULL,
  error_code   VARCHAR(60)  NULL,
  created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  started_at   DATETIME     NULL,
  updated_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  finished_at  DATETIME     NULL,
  KEY ix_jobs_case (case_id, type, created_at),
  KEY ix_jobs_status (status, updated_at),
  CONSTRAINT fk_job_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_job_case FOREIGN KEY (case_id) REFERENCES cases(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS idempotency_keys (
  id             BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id        CHAR(36)     NOT NULL,
  idem_key       VARCHAR(64)  NOT NULL,
  request_hash   CHAR(64)     NOT NULL,
  status_code    SMALLINT     NULL,       -- NULL while in flight
  response_body  JSON         NULL,
  created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_idem (user_id, idem_key),
  KEY ix_idem_created (created_at),
  CONSTRAINT fk_idem_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ── Housekeeping (requires event_scheduler=ON — deploy/setup-server.sh sets it) ──
CREATE EVENT IF NOT EXISTS ev_purge_idempotency
  ON SCHEDULE EVERY 1 HOUR
  DO DELETE FROM idempotency_keys WHERE created_at < UTC_TIMESTAMP() - INTERVAL 24 HOUR;

CREATE EVENT IF NOT EXISTS ev_purge_refresh_tokens
  ON SCHEDULE EVERY 1 DAY
  DO DELETE FROM refresh_tokens WHERE expires_at < UTC_TIMESTAMP() - INTERVAL 7 DAY;

CREATE EVENT IF NOT EXISTS ev_purge_reset_codes
  ON SCHEDULE EVERY 1 HOUR
  DO DELETE FROM password_reset_codes WHERE expires_at < UTC_TIMESTAMP() - INTERVAL 1 DAY;

CREATE EVENT IF NOT EXISTS ev_purge_jobs
  ON SCHEDULE EVERY 1 DAY
  DO DELETE FROM jobs WHERE finished_at IS NOT NULL AND finished_at < UTC_TIMESTAMP() - INTERVAL 30 DAY;

CREATE EVENT IF NOT EXISTS ev_purge_ingest_runs
  ON SCHEDULE EVERY 1 DAY
  DO DELETE FROM ingest_runs WHERE started_at < UTC_TIMESTAMP() - INTERVAL 180 DAY;
