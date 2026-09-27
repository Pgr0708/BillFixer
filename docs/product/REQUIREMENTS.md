# BillFixer — Feature Requirements

> DELETE BEFORE SUBMISSION

---

## Requirement Format

Each requirement uses this format:
- **ID:** Unique code
- **Title:** Short name
- **Description:** What it does
- **Acceptance Criteria:** Specific, testable conditions
- **Priority:** P0 (MVP must-have) / P1 (launch window) / P2 (post-launch)

---

## CAPTURE — Bill & Document Upload

### CAP-001 — Camera Bill Scan
**Priority:** P0
**Description:** User can scan a medical bill using device camera.
**Acceptance Criteria:**
- Camera opens in portrait and landscape
- User can capture multiple pages
- Pages are displayed as thumbnails in order
- User can retake any page
- User can reorder pages
- User can delete pages
- Minimum 1 page required to proceed
- Processing indicator shown while preparing scan
- Captured images are not saved to photo library by default

### CAP-002 — PDF Import
**Priority:** P0
**Description:** User can import a PDF bill from Files app or share sheet.
**Acceptance Criteria:**
- Accepts PDF files
- Supports multi-page PDFs
- Encrypted PDFs show an error with explanation
- File size limit: 50MB with a clear error if exceeded
- Import from Files, Mail, and other apps via share sheet

### CAP-003 — Photo Library Import
**Priority:** P0
**Description:** User can select existing photos of a bill.
**Acceptance Criteria:**
- Multi-photo selection supported
- Photos can be reordered after selection

### CAP-004 — EOB Upload
**Priority:** P0
**Description:** User can upload an Explanation of Benefits document alongside a bill.
**Acceptance Criteria:**
- Same capture methods as bill (camera, PDF, photos)
- EOB is linked to the current case
- EOB upload is optional but strongly recommended (app explains why)
- User can skip EOB and add it later

### CAP-005 — Good Faith Estimate Upload
**Priority:** P1
**Description:** User can upload a GFE for comparison.
**Acceptance Criteria:**
- GFE linked to case
- GFE date captured
- GFE total captured for NSA dispute eligibility check

---

## OCR — Text Extraction

### OCR-001 — On-Device Vision OCR
**Priority:** P0
**Description:** Apple Vision framework extracts text from bill images on-device.
**Acceptance Criteria:**
- Uses Vision's VNRecognizeTextRequest
- Uses .accurate recognition level
- Returns text blocks with confidence scores and bounding boxes
- OCR completes without network connection
- Processing time < 5 seconds per page on iPhone 12 or newer

### OCR-002 — OCR Review Screen
**Priority:** P0
**Description:** User reviews and corrects extracted data before analysis.
**Acceptance Criteria:**
- Shows key extracted fields in a form: Provider, Date, Total Amount, Patient Responsibility, Insurance, Line Items
- Each field shows the OCR'd value
- Each field has an edit button
- Low-confidence fields are visually highlighted (amber/orange indicator)
- User can tap any line item to edit it
- Tapping a field highlights it on the document image
- User can add line items manually
- User can remove incorrectly detected line items
- "Continue" button only enabled when required fields are present: Provider, Date, at least 1 line item

### OCR-003 — Line Item Extraction
**Priority:** P0
**Description:** Individual line items extracted from bill with code, description, quantity, amount.
**Acceptance Criteria:**
- Extracts: code (CPT/HCPCS-style), description, date of service, quantity, unit price, total, adjustments
- Groups multi-page line items correctly
- Handles both itemized and summary bills
- Flags when a bill appears to be a summary (not itemized) and prompts to request itemized bill

---

## ANALYSIS — Deterministic Checks

### ANL-001 — Duplicate Line Item Detection
**Priority:** P0
**Description:** Detects when the same charge appears more than once.
**Acceptance Criteria:**
- Flags when: same date + same code + same amount appear 2+ times
- Flags when: same description + same amount on same date (for bills without codes)
- Confidence: **High** when all three match, **Medium** when two match
- Shows both line item references in evidence

### ANL-002 — Bill vs. EOB Patient Responsibility Check
**Priority:** P0
**Description:** Compares bill's patient balance with EOB's stated patient responsibility.
**Acceptance Criteria:**
- If bill.patientResponsibility > eob.patientResponsibility: flag as **Strong** finding
- Difference amount shown
- Both source references shown (bill page/line, EOB page/section)
- Tolerance: $0.01

### ANL-003 — Arithmetic Verification
**Priority:** P0
**Description:** Verifies internal bill math is correct.
**Acceptance Criteria:**
- Checks: sum(line items) = subtotal
- Checks: subtotal + fees - adjustments - payments = balance
- Tolerance: $0.01
- Flags arithmetic errors as **Strong** findings

### ANL-004 — Service Date Mismatch
**Priority:** P0
**Description:** Checks that bill service dates match EOB service dates.
**Acceptance Criteria:**
- If bill date range does not match EOB date range: flag as **Likely** finding
- Provider on bill matches provider on EOB (name match or NPI match)

### ANL-005 — Quantity Anomaly Detection
**Priority:** P1
**Description:** Flags unusual quantities for common services.
**Acceptance Criteria:**
- Flags quantity > 1 for procedures typically performed once per encounter
- Labels as **Possible** (not error — needs verification)
- Does not flag multi-unit services (injections, minutes-based therapy, etc.)

### ANL-006 — Paid + Patient Balance Reconciliation
**Priority:** P0
**Description:** Verifies EOB math: paid + deductible + copay + coinsurance ≈ allowed amount.
**Acceptance Criteria:**
- Tolerance: $1.00 (due to rounding in EOBs)
- Flags mismatch as **Likely** finding
- Shows formula and actual vs. expected values

---

## PRICING — Hospital Price Intelligence

### PRC-001 — Hospital Identification
**Priority:** P0
**Description:** Identifies hospital from bill for MRF lookup.
**Acceptance Criteria:**
- Matches hospital name from bill to hospital directory (NPI/name lookup)
- Shows matched hospital with address for user confirmation
- User can manually search if auto-match fails
- User can skip price comparison if hospital not found

### PRC-002 — CMS MRF Price Lookup
**Priority:** P1
**Description:** Fetches hospital's published CMS price transparency data.
**Acceptance Criteria:**
- Looks up hospital's current MRF URL from directory
- Fetches and caches relevant records (not entire file)
- Compares bill line items with published prices
- Shows: cash price, negotiated rate range (min/max/median), payer-specific rate if available
- Labels comparison as **Informational** not error unless bill > published cash price

### PRC-003 — Medicare Benchmark Reference
**Priority:** P1
**Description:** Shows Medicare national payment amount as a reference benchmark.
**Acceptance Criteria:**
- Fetches CMS Medicare Physician Fee Schedule data
- Shows Medicare rate labeled as **Reference Benchmark — Not a Price Ceiling**
- Never presents Medicare rate as the "correct" price
- Shows 2026 rate year

### PRC-004 — Cash Price Comparison
**Priority:** P1
**Description:** Compares bill amount with hospital's published discounted cash price.
**Acceptance Criteria:**
- If bill amount > hospital published cash price: flag as **Strong** finding
- Finding includes: bill amount, cash price, source (hospital MRF), effective date
- Recommended action: "Ask for self-pay/cash price adjustment"

---

## RIGHTS — Consumer Protection Checks

### RGT-001 — No Surprises Act Screening
**Priority:** P1
**Description:** Checks if bill may involve a NSA situation.
**Acceptance Criteria:**
- Checks for: out-of-network provider at in-network facility, emergency care, certain ancillary services
- If positive: shows NSA explanation and next steps
- Does not guarantee NSA applies — labels as **Possible** requiring verification

### RGT-002 — Good Faith Estimate Dispute Check
**Priority:** P1
**Description:** Checks eligibility for patient-provider dispute resolution (PPDR).
**Acceptance Criteria:**
- If bill > GFE by $400+: flag as **Strong** finding
- Shows: bill amount, GFE amount, difference, $400 threshold
- Calculates 120-day deadline from initial bill date
- Shows deadline prominently
- If deadline is < 14 days away: shows urgent warning

### RGT-003 — Financial Assistance Detection
**Priority:** P0
**Description:** Detects if user may qualify for hospital financial assistance.
**Acceptance Criteria:**
- Checks if hospital is a tax-exempt nonprofit (501(c)(3)) using hospital directory
- Fetches hospital's Financial Assistance Policy URL if available
- Extracts: income thresholds, FPL percentage, required documents, application URL
- Shows eligibility estimate based on user-entered household size and income
- Clearly states: estimate only — hospital determines actual eligibility

### RGT-004 — Charity Care / Sliding Scale Detection
**Priority:** P1
**Description:** Identifies if hospital offers charity care beyond FAP.
**Acceptance Criteria:**
- Shows charity care availability from hospital data
- Links to application if URL available

---

## ACTIONS — Communications

### ACT-001 — Itemized Bill Request Letter
**Priority:** P0
**Description:** Generates a letter requesting an itemized bill.
**Acceptance Criteria:**
- Uses patient name, provider name, account number, date of service from extracted data
- Formal business letter format
- User can review and edit before exporting
- Does not make accusations

### ACT-002 — EOB/Bill Mismatch Dispute Letter
**Priority:** P0
**Description:** Generates a letter disputing a bill that exceeds EOB patient responsibility.
**Acceptance Criteria:**
- References specific EOB: claim number, date, patient responsibility amount
- References specific bill: account number, date, billed amount
- Requests correction to match EOB
- Cites CMS patient rights language (without legal claims)

### ACT-003 — Duplicate Charge Dispute Letter
**Priority:** P0
**Description:** Generates a letter disputing duplicate charges.
**Acceptance Criteria:**
- Identifies specific duplicate line items by description, date, amount
- Requests removal of duplicate(s)
- Does not claim fraud

### ACT-004 — Self-Pay Price Adjustment Request
**Priority:** P1
**Description:** Generates a letter requesting cash/self-pay discount.
**Acceptance Criteria:**
- References hospital's published cash price from MRF
- Requests adjustment to published cash price
- Includes source date of MRF data

### ACT-005 — Financial Assistance Application Letter
**Priority:** P0
**Description:** Generates a hardship/financial assistance cover letter.
**Acceptance Criteria:**
- References hospital's stated FAP income thresholds
- States household size and approximate income
- Requests application instructions if URL not available
- Includes application deadline if known

### ACT-006 — Phone Script Generator
**Priority:** P0
**Description:** Generates a branching phone script for calling billing department.
**Acceptance Criteria:**
- Opening statement (account number, reason for call)
- Branch: "Bill is correct" → what to say
- Branch: "We can't negotiate" → what to say
- Branch: "Send documentation" → what to ask
- Branch: "Offer 10% off" → counter-offer language
- Branch: "Threatening collections" → how to respond
- Branch: "Agreed to reduce" → confirmation steps
- What NOT to say (avoid escalating language)

### ACT-007 — Evidence Pack PDF Export
**Priority:** P1
**Description:** Exports a complete dispute packet as a PDF.
**Acceptance Criteria:**
- Cover page: patient name (redacted option), case summary, date
- Bill summary table
- EOB summary table
- Flagged line items with evidence
- Price source data
- Applicable rules/rights
- Dispute letter(s)
- Checklist of next steps
- Timeline
- Generated with PDFKit on device

---

## CASES — Case Management

### CSE-001 — Case Creation
**Priority:** P0
**Description:** Every bill analysis creates a named case.
**Acceptance Criteria:**
- Auto-named: "Provider Name — Service Type — Date"
- User can rename case
- Case stores: all documents, all findings, all letters, all events, all deadlines

### CSE-002 — Case Dashboard
**Priority:** P0
**Description:** Overview of all cases with status and key stats.
**Acceptance Criteria:**
- Shows: case name, status, original balance, current balance, open findings count, next deadline
- Status badges: Active, Awaiting Response, Resolved, Closed
- Sorted by: most recent activity (default), can sort by deadline

### CSE-003 — Deadline Tracker
**Priority:** P0
**Description:** Tracks all deadlines associated with a case.
**Acceptance Criteria:**
- PPDR 120-day deadline (from initial bill date)
- Insurance appeal deadlines (user-entered)
- Follow-up reminders (user-set)
- Financial assistance application deadline (if known)
- Overdue deadlines shown in red
- Upcoming deadlines (< 14 days) shown in amber

### CSE-004 — Push Notifications for Deadlines
**Priority:** P0
**Description:** Sends push notifications for approaching deadlines and follow-up reminders.
**Acceptance Criteria:**
- Requests notification permission during onboarding
- Notification 14 days before deadline
- Notification 7 days before deadline
- Notification 1 day before deadline
- Follow-up reminder notifications
- User can disable individual case notifications

### CSE-005 — Outcome Tracking
**Priority:** P0
**Description:** User can record the resolution of each finding and the case overall.
**Acceptance Criteria:**
- Per-finding: Fixed / Partially Fixed / Denied / Still Waiting / Wrong Flag
- Per-case: original balance, final balance (user-entered), savings calculated automatically
- Resolution notes (free text)
- Resolution date
- App never claims savings until user confirms them

### CSE-006 — Case Timeline
**Priority:** P1
**Description:** Chronological event log for each case.
**Acceptance Criteria:**
- Shows: document uploaded, analysis run, letter generated, letter sent (user-logged), response received (user-logged), balance updated
- User can add manual events
- Timeline entries show date and description

---

## SUBSCRIPTION — Payments

### SUB-001 — Free Tier
**Priority:** P0
**Acceptance Criteria:**
- Can scan a bill
- Sees basic explanation (total, provider, date)
- Sees 1 finding (blurred/locked remaining)
- Sees paywall explaining premium benefits
- Cannot generate letters
- Cannot export PDF
- Cannot track cases beyond 1

### SUB-002 — Premium Monthly/Annual
**Priority:** P0
**Acceptance Criteria:**
- Unlimited bill and EOB scans
- All findings unlocked
- All letter types
- Phone scripts
- PDF export
- Unlimited active cases
- Deadline notifications
- Case history + savings tracking
- Hospital price comparison

### SUB-003 — Restore Purchases
**Priority:** P0
**Acceptance Criteria:**
- Restore Purchases button on paywall and settings
- Restores across devices under same Apple ID

### SUB-004 — Server-Side Entitlement Validation
**Priority:** P0
**Acceptance Criteria:**
- Backend validates App Store receipt / subscription status via App Store Server API
- API endpoints check subscription status server-side
- Device-reported premium status is NOT trusted alone

---

## PRIVACY & DATA

### PRV-001 — Account Deletion
**Priority:** P0
**Acceptance Criteria:**
- Settings > Delete Account
- Deletes: user account, all cases, all documents (R2), all findings, all letters
- Confirmation dialog before deletion
- Completes within 24 hours
- Confirmation email sent

### PRV-002 — Individual Case Deletion
**Priority:** P0
**Acceptance Criteria:**
- Delete case and all associated documents/findings/letters
- Immediate

### PRV-003 — Auto-Deletion Policy
**Priority:** P1
**Acceptance Criteria:**
- Closed cases: documents auto-deleted after 90 days (configurable by user)
- User notified before auto-deletion
- User can extend retention

### PRV-004 — Privacy Dashboard
**Priority:** P1
**Acceptance Criteria:**
- Shows: what data is stored, why, how long
- Links to Privacy Policy
- Shows last analysis date
- Shows storage used
