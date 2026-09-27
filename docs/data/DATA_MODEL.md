# BillFixer — Data Model

> DELETE BEFORE SUBMISSION

---

## Design Principles

- All monetary values: `DECIMAL(10,2)` — never FLOAT
- All dates: `DATETIME UTC` — convert to local in app
- All IDs: `UUID` (char(36))
- Soft deletes with `deleted_at` where data may need recovery
- Hard deletes for sensitive medical data (per privacy policy)

---

## Entity Relationship Overview

```
User
 └── Case (1:many)
      ├── Document (1:many)
      │    └── DocumentPage (1:many)
      │         └── OCRBlock (1:many)
      ├── Bill (1:1)
      │    └── BillLineItem (1:many)
      ├── EOB (0:1)
      │    └── EOBLineItem (1:many)
      ├── GoodFaithEstimate (0:1)
      ├── Finding (1:many)
      │    └── FindingEvidence (1:many)
      ├── Letter (1:many)
      ├── PhoneScript (1:many)
      ├── CaseEvent (1:many)
      ├── Deadline (1:many)
      └── Outcome (0:1)

Provider (hospital/facility)
 └── HospitalPriceRecord (1:many)
 └── FinancialAssistancePolicy (0:1)

Subscription
 └── User (1:1)
```

---

## Users Table

```sql
CREATE TABLE users (
  id              CHAR(36)        PRIMARY KEY,
  email           VARCHAR(255)    UNIQUE,
  apple_id        VARCHAR(255)    UNIQUE,
  display_name    VARCHAR(255),
  created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at      DATETIME,
  last_active_at  DATETIME
);
```

---

## Subscriptions Table

```sql
CREATE TABLE subscriptions (
  id                    CHAR(36)      PRIMARY KEY,
  user_id               CHAR(36)      NOT NULL REFERENCES users(id),
  status                ENUM('free','active','expired','in_grace','paused','revoked') NOT NULL DEFAULT 'free',
  product_id            VARCHAR(100),  -- billfixer.monthly / billfixer.annual
  original_transaction_id VARCHAR(255),
  latest_receipt        TEXT,
  expires_at            DATETIME,
  grace_period_expires  DATETIME,
  created_at            DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at            DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

---

## Cases Table

```sql
CREATE TABLE cases (
  id                  CHAR(36)        PRIMARY KEY,
  user_id             CHAR(36)        NOT NULL REFERENCES users(id),
  title               VARCHAR(255)    NOT NULL,
  provider_id         CHAR(36)        REFERENCES providers(id),
  status              ENUM('draft','active','awaiting_response','resolved','closed') NOT NULL DEFAULT 'draft',
  bill_date           DATE,
  service_type        VARCHAR(100),
  insurer_name        VARCHAR(255),
  original_balance    DECIMAL(10,2),
  current_balance     DECIMAL(10,2),
  final_balance       DECIMAL(10,2),
  verified_savings    DECIMAL(10,2),
  initial_bill_date   DATE,           -- for GFE/PPDR deadline calculation
  notes               TEXT,
  created_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at          DATETIME
);
```

---

## Documents Table

```sql
CREATE TABLE documents (
  id                  CHAR(36)      PRIMARY KEY,
  case_id             CHAR(36)      NOT NULL REFERENCES cases(id),
  type                ENUM('bill','eob','gfe','other') NOT NULL,
  source              ENUM('camera','pdf','photos') NOT NULL,
  page_count          INT           NOT NULL DEFAULT 1,
  r2_prefix           VARCHAR(500), -- storage key prefix
  processing_status   ENUM('pending','processing','complete','failed') NOT NULL DEFAULT 'pending',
  ocr_completed_at    DATETIME,
  expires_at          DATETIME,     -- auto-delete date
  sha256              CHAR(64),
  created_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at          DATETIME
);
```

---

## Bills Table

```sql
CREATE TABLE bills (
  id                      CHAR(36)      PRIMARY KEY,
  document_id             CHAR(36)      NOT NULL REFERENCES documents(id),
  case_id                 CHAR(36)      NOT NULL REFERENCES cases(id),
  provider_name           VARCHAR(255),
  provider_npi            VARCHAR(20),
  account_number          VARCHAR(100),
  bill_date               DATE,
  service_date_start      DATE,
  service_date_end        DATE,
  insurer_name            VARCHAR(255),
  member_id_redacted      VARCHAR(50),  -- last 4 only
  total_charges           DECIMAL(10,2),
  insurance_payment       DECIMAL(10,2),
  adjustments             DECIMAL(10,2),
  previous_payments       DECIMAL(10,2),
  patient_responsibility  DECIMAL(10,2),
  current_balance         DECIMAL(10,2),
  is_itemized             BOOLEAN       NOT NULL DEFAULT FALSE,
  raw_ocr_confidence      DECIMAL(5,4), -- 0.0000 to 1.0000
  created_at              DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

---

## Bill Line Items Table

```sql
CREATE TABLE bill_line_items (
  id               CHAR(36)       PRIMARY KEY,
  bill_id          CHAR(36)       NOT NULL REFERENCES bills(id),
  line_number      INT,
  code             VARCHAR(20),   -- CPT/HCPCS style (display only)
  description      VARCHAR(500),
  date_of_service  DATE,
  quantity         DECIMAL(8,3),
  unit_price       DECIMAL(10,2),
  total_amount     DECIMAL(10,2),
  adjustment       DECIMAL(10,2),
  is_user_edited   BOOLEAN        NOT NULL DEFAULT FALSE,
  ocr_confidence   DECIMAL(5,4),
  created_at       DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

---

## EOBs Table

```sql
CREATE TABLE eobs (
  id                      CHAR(36)      PRIMARY KEY,
  document_id             CHAR(36)      NOT NULL REFERENCES documents(id),
  case_id                 CHAR(36)      NOT NULL REFERENCES cases(id),
  claim_number            VARCHAR(100),
  insurer_name            VARCHAR(255),
  member_id_redacted      VARCHAR(50),
  service_date_start      DATE,
  service_date_end        DATE,
  provider_name           VARCHAR(255),
  billed_amount           DECIMAL(10,2),
  allowed_amount          DECIMAL(10,2),
  insurer_payment         DECIMAL(10,2),
  deductible_applied      DECIMAL(10,2),
  copay                   DECIMAL(10,2),
  coinsurance             DECIMAL(10,2),
  patient_responsibility  DECIMAL(10,2),
  created_at              DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

---

## Findings Table

```sql
CREATE TABLE findings (
  id                  CHAR(36)       PRIMARY KEY,
  case_id             CHAR(36)       NOT NULL REFERENCES cases(id),
  type                ENUM(
                        'duplicate_charge',
                        'bill_eob_mismatch',
                        'arithmetic_error',
                        'quantity_anomaly',
                        'service_date_mismatch',
                        'price_above_cash_price',
                        'price_above_negotiated_rate',
                        'medicare_benchmark',
                        'financial_assistance_eligible',
                        'no_surprises_possible',
                        'gfe_dispute_eligible',
                        'paid_amount_mismatch',
                        'balance_mismatch',
                        'informational'
                      ) NOT NULL,
  severity            ENUM('strong','likely','possible','informational') NOT NULL,
  confidence          ENUM('high','medium','low') NOT NULL,
  title               VARCHAR(500)   NOT NULL,
  explanation         TEXT           NOT NULL,
  amount_flagged      DECIMAL(10,2),
  amount_reference    DECIMAL(10,2),
  amount_difference   DECIMAL(10,2),
  recommended_action  VARCHAR(100),
  status              ENUM('open','dismissed','fixed','partially_fixed','denied','wrong') DEFAULT 'open',
  dismissed_at        DATETIME,
  created_at          DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

---

## Finding Evidence Table

```sql
CREATE TABLE finding_evidence (
  id           CHAR(36)     PRIMARY KEY,
  finding_id   CHAR(36)     NOT NULL REFERENCES findings(id),
  source_type  ENUM('bill_line_item','eob_line_item','hospital_price_record','cms_rule','cms_data','manual') NOT NULL,
  source_id    CHAR(36),
  label        VARCHAR(500) NOT NULL, -- Human-readable: "Bill page 2, line 14"
  value        VARCHAR(500),          -- The cited value or text
  url          VARCHAR(2000),         -- Source URL if applicable
  created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

---

## Letters Table

```sql
CREATE TABLE letters (
  id              CHAR(36)       PRIMARY KEY,
  case_id         CHAR(36)       NOT NULL REFERENCES cases(id),
  finding_id      CHAR(36)       REFERENCES findings(id),
  type            ENUM(
                    'itemized_bill_request',
                    'duplicate_dispute',
                    'eob_mismatch_dispute',
                    'cash_price_adjustment',
                    'financial_assistance',
                    'gfe_dispute',
                    'insurance_appeal',
                    'collections_dispute',
                    'payment_plan_request'
                  ) NOT NULL,
  recipient_name  VARCHAR(255),
  recipient_type  ENUM('provider','insurer','collections','other'),
  content         MEDIUMTEXT     NOT NULL,
  version         INT            NOT NULL DEFAULT 1,
  sent_at         DATETIME,
  created_at      DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

---

## Deadlines Table

```sql
CREATE TABLE deadlines (
  id             CHAR(36)      PRIMARY KEY,
  case_id        CHAR(36)      NOT NULL REFERENCES cases(id),
  type           ENUM('ppdr_120day','insurance_appeal','follow_up','fa_application','custom') NOT NULL,
  label          VARCHAR(255)  NOT NULL,
  due_date       DATE          NOT NULL,
  is_completed   BOOLEAN       NOT NULL DEFAULT FALSE,
  completed_at   DATETIME,
  notify_days    JSON,          -- [1, 7, 14] days before
  created_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

---

## Providers (Hospital Directory)

```sql
CREATE TABLE providers (
  id                  CHAR(36)     PRIMARY KEY,
  npi                 VARCHAR(20)  UNIQUE,
  name                VARCHAR(500) NOT NULL,
  facility_name       VARCHAR(500),
  address             VARCHAR(500),
  city                VARCHAR(100),
  state               CHAR(2),
  zip                 VARCHAR(10),
  phone               VARCHAR(20),
  website             VARCHAR(2000),
  tax_status          ENUM('nonprofit','for_profit','government','unknown') DEFAULT 'unknown',
  mrf_url             VARCHAR(2000),
  mrf_last_fetched    DATETIME,
  mrf_format          ENUM('json','csv_tall','csv_wide','unknown'),
  fap_url             VARCHAR(2000),
  cms_id              VARCHAR(50),
  is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

---

## Hospital Price Records

```sql
CREATE TABLE hospital_price_records (
  id                  CHAR(36)      PRIMARY KEY,
  provider_id         CHAR(36)      NOT NULL REFERENCES providers(id),
  code                VARCHAR(20),
  code_type           ENUM('hcpcs','icd','drg','ms_drg','rev_code','ndc','other'),
  description         VARCHAR(500),
  payer_name          VARCHAR(255),
  plan_name           VARCHAR(255),
  gross_charge        DECIMAL(12,2),
  cash_price          DECIMAL(12,2),
  negotiated_rate     DECIMAL(12,2),
  min_rate            DECIMAL(12,2),
  max_rate            DECIMAL(12,2),
  median_rate         DECIMAL(12,2),
  rate_type           ENUM('percent','flat') DEFAULT 'flat',
  effective_date      DATE,
  mrf_version         VARCHAR(50),
  fetched_at          DATETIME      NOT NULL,
  created_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

---

## Financial Assistance Policies

```sql
CREATE TABLE financial_assistance_policies (
  id                      CHAR(36)      PRIMARY KEY,
  provider_id             CHAR(36)      NOT NULL REFERENCES providers(id),
  fap_url                 VARCHAR(2000),
  income_threshold_fpl    DECIMAL(5,2), -- e.g. 300.00 = 300% FPL
  free_care_threshold_fpl DECIMAL(5,2),
  application_url         VARCHAR(2000),
  application_phone       VARCHAR(20),
  allows_retroactive      BOOLEAN,
  required_docs           JSON,         -- Array of required document names
  effective_date          DATE,
  fetched_at              DATETIME,
  raw_text                TEXT,         -- Extracted policy text for LLM processing
  created_at              DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at              DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

---

## Case Events (Timeline)

```sql
CREATE TABLE case_events (
  id           CHAR(36)      PRIMARY KEY,
  case_id      CHAR(36)      NOT NULL REFERENCES cases(id),
  type         ENUM('document_added','analysis_run','finding_added','letter_generated','letter_sent','response_received','balance_updated','case_resolved','note_added','deadline_set','reminder_sent','custom') NOT NULL,
  label        VARCHAR(500)  NOT NULL,
  metadata     JSON,
  is_user_log  BOOLEAN       NOT NULL DEFAULT FALSE,
  occurred_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

---

## Outcomes Table

```sql
CREATE TABLE outcomes (
  id                  CHAR(36)      PRIMARY KEY,
  case_id             CHAR(36)      NOT NULL REFERENCES cases(id) UNIQUE,
  resolution          ENUM('full_reduction','partial_reduction','denied','financial_assistance','payment_plan','no_change','other'),
  original_balance    DECIMAL(10,2),
  final_balance       DECIMAL(10,2),
  verified_savings    DECIMAL(10,2) GENERATED ALWAYS AS (original_balance - final_balance) STORED,
  notes               TEXT,
  resolved_at         DATETIME,
  created_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

---

## iOS SwiftData Local Models (Cached for Offline)

```swift
// Lightweight local cache — not the source of truth
@Model class LocalCase {
    var id: UUID
    var title: String
    var status: String
    var originalBalance: Decimal?
    var currentBalance: Decimal?
    var nextDeadline: Date?
    var findingCount: Int
    var lastSyncedAt: Date
}

@Model class LocalFinding {
    var id: UUID
    var caseId: UUID
    var type: String
    var severity: String
    var title: String
    var explanation: String
    var amountFlagged: Decimal?
    var isRead: Bool
}

@Model class LocalDeadline {
    var id: UUID
    var caseId: UUID
    var label: String
    var dueDate: Date
    var isCompleted: Bool
    var type: String
}
```
