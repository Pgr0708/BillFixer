# BillFixer — Testing Strategy

> DELETE BEFORE SUBMISSION

---

## iOS Testing

### Unit Tests

Every non-trivial service and domain model must have unit tests.

**Priority targets:**
- `BillArithmeticChecker` — all arithmetic verification logic
- `DuplicateLineItemDetector` — duplicate detection
- `EOBReconciliationEngine` — EOB vs bill comparison
- `RightsEngine` — NSA, GFE, FAP eligibility checks
- `APIClient` — request building, response decoding, error mapping
- `SubscriptionService` — tier determination
- `OCRParser` — structured data extraction from OCR output
- `DataRedactionService` — PII redaction before LLM

**Coverage target:** ≥ 80% on Domain/ and Services/ layers

### UI Tests (XCUITest)

Priority flows to automate:

| Flow | Key Assertions |
|---|---|
| Onboarding | 3 pages complete, reaches home |
| Bill import (PDF) | File selected, OCR review shown |
| OCR review | Can edit field, can add line item |
| Analysis loading | Steps shown, completion reached |
| Findings display | Cards visible, finding count matches |
| Letter generation | Letter content shown |
| Paywall | Shown for locked features, can dismiss |
| Restore purchases | Button triggers flow |
| Case creation | Case appears in list |
| Case deletion | Case removed from list |
| Account deletion | Confirmation shown |

### Snapshot Tests

Snapshot tests for all design system components:
- All button variants and states
- Finding card (all severity levels)
- Case card (all status states)
- Empty states
- Paywall

Library: swift-snapshot-testing

---

## Backend Testing

### Unit Tests (Jest)

| Module | Coverage Target |
|---|---|
| Analysis workers | 90% |
| Letter generation | 80% |
| LLM output validation | 95% |
| PII redaction | 95% |
| Hospital price comparison logic | 90% |
| Rights engine | 90% |
| Subscription webhook handler | 85% |

### Integration Tests

| Test | What it covers |
|---|---|
| Bill submission → Analysis complete | Full pipeline end-to-end |
| Letter generation → Prohibited phrase filter | Safety validation |
| Upload → R2 storage → Presigned URL | Document pipeline |
| Subscription purchase → Entitlement update | Subscription flow |
| Account deletion → Hard delete verified | Data deletion |

### API Tests (Supertest)

All endpoints tested for:
- 200/201/202 happy path
- 400 missing required fields
- 401 missing auth
- 402 subscription required
- 403 accessing other user's resource
- 404 not found
- 422 validation errors
- 429 rate limit

---

## Analysis Quality Testing

### Test Bill Dataset

Maintain a set of anonymized/synthetic test bills:

| File | Type | Expected Findings |
|---|---|---|
| test_bill_01_duplicate.jpg | Itemized bill with duplicate charge | 1 Strong: duplicate |
| test_bill_02_math_error.pdf | Bill with wrong math | 1 Strong: arithmetic |
| test_bill_03_eob_mismatch.jpg + eob | Bill + EOB with $150 mismatch | 1 Strong: EOB mismatch |
| test_bill_04_clean.pdf | Bill with no issues | 0 findings |
| test_bill_05_quantity.jpg | Bill with quantity anomaly | 1 Possible: quantity |
| test_bill_06_summary_only.pdf | Summary bill (not itemized) | Informational: request itemized |
| test_bill_07_poor_ocr.jpg | Low quality image | OCR warning triggered |

### False Positive Rate Monitoring

Track per finding type:
- How often do users mark a finding as "Wrong"?
- Target: < 5% false-positive rate for Strong/Likely findings

---

## Accessibility Testing

- Run Accessibility Inspector on every screen
- Test with VoiceOver enabled (all interactive elements must be reachable and labeled)
- Test with Display & Text Size > Larger Text (largest accessibility size)
- Test with Increase Contrast enabled
- Test with Reduce Motion enabled

---

## Performance Testing

| Metric | Target |
|---|---|
| App cold launch → Home screen | < 2.5 seconds |
| Camera → OCR complete | < 5 seconds (single page) |
| Analysis job (backend) | < 45 seconds |
| Letter generation (backend) | < 20 seconds |
| API response (cached) | < 300ms |
| API response (DB query) | < 1000ms |
| PDF export | < 3 seconds |

---

## Security Testing

Before launch:
- Run OWASP Mobile Top 10 checklist
- Verify no secrets in binary (grep for keys in .ipa)
- Verify SSL certificate pinning works
- Verify Keychain isolation (other apps cannot read)
- Verify no sensitive data in logs
- Pentest API endpoints for injection, auth bypass, IDOR

---

## Beta Testing Plan

### TestFlight Phases

**Phase 1 (Internal — 10 testers)**
- Team members
- All major devices (iPhone 15, 14, SE, 12)
- iOS 18.0, 17.0
- Goal: Major bugs, crash-free

**Phase 2 (External Beta — 50–100 testers)**
- Healthcare workers, patients, personal finance enthusiasts
- Real medical bills (with consent)
- Goal: OCR accuracy, finding relevance, false-positive rate

**Phase 3 (Public Beta — unlimited)**
- TestFlight public link
- Monitor conversion from free → premium
- Tune paywall copy and trigger points

---

## Crash Monitoring

Tool: Xcode Organizer + Firebase Crashlytics
- Target: < 0.1% crash-free session rate (99.9%+ crash-free)
- Alert on any new crash type with > 5 occurrences
- Weekly crash report review
