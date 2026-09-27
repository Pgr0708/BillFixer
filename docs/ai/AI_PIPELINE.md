# BillFixer — AI Pipeline

> DELETE BEFORE SUBMISSION

---

## Principle

The AI/LLM layer is a **writer**, not an **analyzer**.
- Deterministic code does all the math and logic.
- The LLM writes the human-readable explanations and documents.
- The LLM never sees raw medical documents — only structured evidence bundles.

---

## LLM Selection

| Task | Preferred Model | Fallback |
|---|---|---|
| Finding explanation | GPT-4o | Claude 3.5 Sonnet |
| Letter generation | GPT-4o | Claude 3.5 Sonnet |
| Phone script generation | GPT-4o | Claude 3.5 Sonnet |
| FAP summary extraction | Claude 3.5 Haiku | GPT-4o-mini |

Decision: Model selected per-task based on quality + cost. Backend abstracts model selection.

---

## Data Flow: What the LLM Receives

### 1. Finding Explanation Prompt

```json
System: "You are a medical billing analyst. Explain the following finding in clear, 
         patient-friendly language. Do not claim fraud. Do not guarantee outcomes. 
         Reference specific evidence. Keep explanation under 150 words."

User: {
  "findingType": "bill_eob_mismatch",
  "severity": "strong",
  "billAmount": "690.00",
  "eobAmount": "540.00",
  "difference": "150.00",
  "billSource": "Bill page 1, 'Amount Due: $690.00'",
  "eobSource": "EOB dated 2024-11-14, Claim #8821-X, 'Your Responsibility: $540.00'",
  "providerName": "Memorial Hospital"
}
```

### 2. Letter Generation Prompt

```json
System: "You are a medical billing advocate. Write a professional, polite dispute letter 
         based only on the evidence provided. Do not claim fraud or illegal activity. 
         Do not guarantee outcomes. Use [PLACEHOLDER] for values the user must fill in."

User: {
  "letterType": "eob_mismatch_dispute",
  "patientName": "[PATIENT NAME]",
  "accountNumber": "ACC-88211",
  "providerName": "Memorial Hospital Billing Dept",
  "billDate": "2024-11-20",
  "billAmount": "690.00",
  "eobClaimNumber": "8821-X",
  "eobDate": "2024-11-14",
  "eobPatientResponsibility": "540.00",
  "difference": "150.00",
  "requestedAction": "Correct balance to match EOB patient responsibility of $540.00"
}
```

### 3. Phone Script Prompt

```json
System: "Generate a phone script for a patient calling their hospital billing department. 
         Include an opening statement, responses to common pushbacks, and confirmation steps. 
         Keep each response under 3 sentences. Do not threaten legal action."

User: {
  "callTarget": "provider_billing",
  "issueType": "eob_mismatch",
  "accountNumber": "ACC-88211",
  "keyFacts": [
    "EOB shows $540.00, bill shows $690.00",
    "Difference of $150.00",
    "EOB claim number 8821-X dated Nov 14 2024"
  ]
}
```

---

## LLM Response Schema (Required)

All LLM responses must be valid JSON matching a defined schema.
The backend validates before returning to iOS. No free-form strings accepted.

### Finding Explanation Schema

```json
{
  "$schema": "BillFixer/FindingExplanation/v1",
  "title": "string (max 80 chars)",
  "shortExplanation": "string (max 150 chars)",
  "fullExplanation": "string (max 400 chars)",
  "whatThisMeans": "string (max 200 chars)",
  "whatYouCanDo": "string (max 200 chars)",
  "confidenceNote": "string (max 100 chars)"
}
```

### Letter Schema

```json
{
  "$schema": "BillFixer/Letter/v1",
  "date": "[DATE]",
  "recipientName": "string",
  "subject": "string",
  "body": "string (multi-paragraph, \n separated)",
  "closing": "string",
  "senderPlaceholder": "[YOUR NAME]",
  "placeholders": ["[DATE]", "[YOUR NAME]", "[PHONE NUMBER]"],
  "disclaimer": "string"
}
```

### Phone Script Schema

```json
{
  "$schema": "BillFixer/PhoneScript/v1",
  "openingStatement": "string",
  "branches": [
    {
      "trigger": "string (what they say)",
      "response": "string (what you say)",
      "followUp": "string?",
      "childBranches": []
    }
  ],
  "doNotSay": ["string"],
  "postCallChecklist": ["string"]
}
```

---

## Backend AI Worker

```
1. Receive job from Bull queue (jobType, payload)
2. Load evidence bundle from database
3. Build system + user prompt from templates
4. Call LLM API with:
   - temperature: 0.3 (low creativity, high consistency)
   - max_tokens: 1000 (finding) / 2000 (letter) / 2500 (script)
   - response_format: { type: "json_object" }
5. Receive response
6. Parse JSON
7. Validate against schema
8. Run prohibited-phrase filter
9. Validate amounts match evidence bundle
10. If validation fails: retry with correction prompt (max 2x)
11. If still fails: log error, return safe fallback
12. Store result in database
13. Notify iOS via webhook/push
```

---

## PII Redaction (Before LLM)

The following fields are redacted before any data is sent to an LLM:

| Field | Handling |
|---|---|
| Patient full name | Replaced with "[PATIENT]" |
| Patient DOB | Removed |
| Patient address | Removed |
| Insurance member ID | Last 4 only |
| SSN (if present) | Fully removed |
| Account number | Kept (needed for letter) |
| Claim number | Kept (needed for letter) |
| Provider NPI | Kept |
| Diagnosis codes | Removed (not needed for billing analysis) |
| Procedure codes | Kept (needed for price lookup) |

---

## Cost Control

| Operation | Estimated Cost |
|---|---|
| Finding explanation (4 findings) | ~$0.02 |
| One letter | ~$0.04 |
| Phone script | ~$0.05 |
| FAP summary extraction | ~$0.01 |
| Full analysis (typical case) | ~$0.08–$0.12 total |

Budget: Premium subscription covers ~50 full analyses per year per user at target pricing.

---

## AI Model Fallback

```
Primary: GPT-4o via Azure OpenAI (SOC 2 compliant endpoint)
Fallback: Claude 3.5 Sonnet via Anthropic API
Timeout: 30 seconds per LLM call
Retry: 2 times with exponential backoff before fallback
Circuit breaker: if >20% requests fail in 5 min, switch to fallback
```

---

## Prohibited Content Filter

Before returning any LLM response to iOS, run:

```javascript
const PROHIBITED_PATTERNS = [
  /illegal(ly)?/i,
  /fraud(ulent)?/i,
  /you definitely/i,
  /guaranteed (to )?save/i,
  /will save \$[\d,]+/i,
  /criminal/i,
  /sue/i,
  /lawsuit/i,
  /attorney/i,
];

function validateContent(text) {
  for (const pattern of PROHIBITED_PATTERNS) {
    if (pattern.test(text)) {
      return { valid: false, reason: `Prohibited pattern: ${pattern}` };
    }
  }
  return { valid: true };
}
```

If any prohibited pattern is found, the response is discarded and a safe fallback template is used.
