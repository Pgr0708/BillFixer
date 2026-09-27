# BillFixer — Bill Analysis Logic

> DELETE BEFORE SUBMISSION

---

## Overview

The analysis pipeline has two distinct stages:

1. **Deterministic Checks** — Pure math and logic. No LLM. High confidence.
2. **LLM-Assisted Generation** — Explanations, letters, scripts. Uses evidence assembled by deterministic stage.

LLM is NEVER used for:
- Determining if a charge is an error
- Calculating mathematical discrepancies
- Comparing amounts

LLM IS used for:
- Writing plain-English explanations of findings
- Generating dispute letters and phone scripts
- Answering follow-up questions about a finding

---

## Stage 1: Deterministic Analysis

### Check 1: Arithmetic Verification

```
Purpose: Verify internal bill math is correct.
Input: Bill header + line items
Method:
  1. sum_line_items = SUM(bill_line_items.total_amount)
  2. expected_balance = sum_line_items + fees - adjustments - insurance_payment - other_payments
  3. If |expected_balance - bill.current_balance| > 0.01:
       Create finding: type=arithmetic_error, severity=strong, confidence=high
       evidence: computed sum vs stated balance
       difference: expected - actual

Example:
  Line items total: $3,480.00
  Insurance payment: -$2,100.00
  Contractual adjustment: -$840.00
  Expected balance: $540.00
  Stated balance: $690.00
  → Finding: "Bill math doesn't add up. The stated balance is $150.00 more than expected."
```

### Check 2: Duplicate Line Item Detection

```
Purpose: Flag same charge appearing multiple times on same date.
Input: bill_line_items
Method:
  Group by: (date_of_service, code, total_amount)
  If any group has count > 1: finding for each duplicate pair

  If code is null (no CPT code on bill):
  Group by: (date_of_service, description_normalized, total_amount)
  description_normalized = lowercase, strip punctuation, collapse whitespace

  Severity mapping:
    code + date + amount match: strong, confidence=high
    description + date + amount match: likely, confidence=medium
    description + amount match (different dates, same week): possible, confidence=low

Evidence:
  line_number_a, line_number_b, matching fields
```

### Check 3: EOB vs Bill Patient Responsibility

```
Purpose: Bill should not exceed EOB patient responsibility.
Input: bill.patient_responsibility, eob.patient_responsibility
Precondition: EOB must be for same claim period
Method:
  If bill.patient_responsibility > eob.patient_responsibility + 0.01:
    diff = bill.patient_responsibility - eob.patient_responsibility
    finding: type=bill_eob_mismatch, severity=strong, confidence=high
    evidence: bill source (page/line), eob source (section/line), claim_number
    amounts: bill.patient_responsibility, eob.patient_responsibility, diff

  Tolerance: $0.01 (rounding)
  Note: If insurer hasn't paid yet, EOB may not be final. Label this.
```

### Check 4: EOB Math Reconciliation

```
Purpose: Verify EOB internal math.
Input: EOB fields
Method:
  expected_patient_resp = eob.allowed_amount - eob.insurer_payment
  tolerance = $1.00 (EOBs commonly round)
  If |expected_patient_resp - eob.patient_responsibility| > tolerance:
    finding: type=paid_amount_mismatch, severity=likely, confidence=medium
    evidence: formula shown, computed vs stated
```

### Check 5: Service Date Consistency

```
Purpose: Bill and EOB service dates should match.
Input: bill.service_date_start/end, eob.service_date_start/end
Method:
  If bill dates and EOB dates do not overlap at all:
    finding: type=service_date_mismatch, severity=likely, confidence=medium
    note: "This may mean the EOB is for a different service."
  If bill dates are a subset of EOB dates: no finding (common)
  If bill dates are wider than EOB dates:
    finding: type=service_date_mismatch, severity=possible, confidence=low
```

### Check 6: Quantity Anomaly

```
Purpose: Flag unusual quantities for typically-single-instance procedures.
Input: bill_line_items, internal reference table
Method:
  Reference table: list of CPT/service types where qty > 1 is unusual per encounter
  (E.g.: anesthesia base units, surgical procedures, initial consults)
  NOT flagged: injections, infusions, therapy minutes, durable medical equipment
  If line_item.quantity > 1 AND code in unusual_quantity_reference:
    finding: type=quantity_anomaly, severity=possible, confidence=low
    note: "Quantity of X for this type of service may need verification."
```

---

## Stage 2: Pricing Intelligence

### Hospital Price Lookup Flow

```
1. Extract provider NPI from bill (or match by name)
2. Look up provider in hospital directory
3. Fetch cached MRF data if available (or trigger background fetch)
4. For each line item with a code:
   a. Look up code in hospital_price_records for this provider
   b. Compare bill.unit_price vs:
      - hospital cash_price
      - min/max negotiated range
      - gross charge

Findings:
  If bill_amount > cash_price:
    type=price_above_cash_price, severity=strong, confidence=high
    evidence: MRF source URL, effective date, cash price amount

  If bill_amount > max_negotiated_rate:
    type=price_above_negotiated_rate, severity=likely, confidence=medium
    evidence: MRF source, rate range

  If bill_amount is between min and max:
    type=informational (benchmark reference only)
    no action recommended (within normal range)
```

### Medicare Benchmark

```
Input: line item code
Source: CMS Physician Fee Schedule (MPFS) 2026 data
Method:
  Fetch Medicare national rate for code (facility rate)
  Display as: reference benchmark
  NEVER as: "correct price" or "maximum allowed"
  Finding type: informational only
  Label: "Medicare pays approximately $X for this service. This is a reference point only."
```

---

## Stage 3: Rights Engine

### No Surprises Act Screen

```
Trigger: Any of the following in bill data:
  - Out-of-network indicator on EOB
  - Provider specialty codes known to be commonly OON (anesthesia, radiology, ER)
  - Bill from emergency department
  - Facility is in-network but individual provider is OON

Finding type: no_surprises_possible
Severity: possible
Confidence: medium (user must confirm details)
Content: Explains NSA, what it covers, how to check eligibility, CFPB complaint link
Recommended action: Contact insurer to confirm NSA applies
```

### GFE Dispute Eligibility

```
Precondition: User uploaded a Good Faith Estimate
Method:
  diff = bill.current_balance - gfe.total
  If diff >= 400.00:
    days_since_bill = today - bill.initial_date
    ppdr_deadline = bill.initial_date + 120 days
    
    finding: type=gfe_dispute_eligible, severity=strong, confidence=high
    amounts: bill_amount, gfe_amount, diff
    deadline: ppdr_deadline
    urgency:
      < 14 days: urgent flag
      > 120 days: expired flag
    
    recommended_action: "Initiate Patient-Provider Dispute Resolution"
    evidence: GFE document, bill document, diff amount, rule citation (45 CFR 149.620)
```

### Financial Assistance Eligibility

```
Trigger: Provider identified as 501(c)(3) nonprofit

Method:
  1. Fetch provider.fap data
  2. If user provides household_size and approx_income:
     estimate_fpl_pct = (income / fpl_threshold[household_size]) * 100
     If estimate_fpl_pct < fap.income_threshold_fpl:
       finding: type=financial_assistance_eligible, severity=possible
       content: FAP thresholds, required docs, application link
       note: "This is an estimate — hospital determines actual eligibility"
  
  3. If user does not provide income:
     Still show FAP finding as possible (with prompt to check eligibility)
  
  Required: Always show FAP finding for nonprofit hospitals regardless of income.
  Reason: User may not know they're entitled to apply.
```

---

## Stage 4: Evidence Bundle Assembly

Before calling LLM, assemble:

```json
{
  "case": {
    "caseId": "uuid",
    "providerName": "string",
    "billDate": "date",
    "serviceType": "string"
  },
  "bill": {
    "totalCharges": "decimal",
    "patientResponsibility": "decimal",
    "lineItemCount": 12,
    "isItemized": true
  },
  "eob": {
    "present": true,
    "claimNumber": "string",
    "patientResponsibility": "decimal"
  },
  "findings": [
    {
      "type": "bill_eob_mismatch",
      "severity": "strong",
      "amountFlagged": "150.00",
      "amountReference": "540.00",
      "difference": "150.00",
      "evidence": ["Bill page 1: Patient Balance $690", "EOB section 2: Your responsibility $540.00"]
    }
  ],
  "pricingData": {
    "hospitalName": "string",
    "cashPrice": "decimal?",
    "negotiatedRange": "string?"
  },
  "rightsFlags": {
    "nsaPossible": false,
    "gfeEligible": false,
    "fapAvailable": true,
    "fapThreshold": 300
  }
}
```

---

## Stage 5: LLM Prompting Rules

### System Prompt Requirements

```
You are a medical billing analyst assistant. You help patients understand
their medical bills and take action. You do NOT provide legal advice.
You do NOT guarantee outcomes. You do NOT claim errors are fraud.
Every claim you make must be grounded in the evidence provided.

Prohibited phrases:
- "This is illegal"
- "This is fraud"
- "You were overcharged illegally"
- "You will save $X"
- "You definitely don't owe this"

Required for each finding explanation:
- Reference the specific evidence
- State confidence level
- Describe what it might mean
- Describe what the user can do
- Maintain neutral, factual tone
```

### Letter Generation Rules

```
Letters must:
- Be polite and professional
- Reference specific account number, date, claim number
- Reference specific discrepancy (amount)
- Cite evidence (EOB date, claim number, hospital's own published price)
- Request a specific action
- Not accuse anyone of wrongdoing
- Include appropriate closing

Letters must NOT:
- Threaten legal action
- Claim fraud
- Guarantee outcomes
- Use aggressive language
- Make claims unsupported by the evidence bundle
```

### Validation After LLM Response

```
Backend validation before returning to iOS:
1. Check response is valid JSON matching expected schema
2. Check no prohibited phrases present (regex + keyword filter)
3. Check all claimed amounts match evidence bundle (±$0.01)
4. Check letter contains required fields (account number placeholder, date, etc.)
5. If validation fails: retry with correction prompt (max 2 retries)
6. If still fails: return safe fallback response
```
