# BillFixer — MVP Scope

> DELETE BEFORE SUBMISSION
> This file defines the EXACT scope for v1.0 App Store submission.
> Anything not listed here is explicitly OUT of scope for MVP.

---

## MVP Goal

Validate the core value loop:
**Scan bill → Analyze → Find something actionable → Take action**

The minimum viable loop that justifies a subscription.

---

## MVP Features (IN)

### Capture
- [x] Camera scan (multi-page)
- [x] PDF import
- [x] Photo library import
- [x] EOB upload (same methods)
- [x] On-device OCR (Vision)
- [x] OCR review / correction screen

### Analysis
- [x] Bill arithmetic verification
- [x] Duplicate line item detection (code + description based)
- [x] EOB vs bill patient responsibility comparison
- [x] EOB internal math check
- [x] Service date consistency check
- [x] Financial assistance detection (nonprofit hospitals)
- [x] Basic quantity anomaly flag

### Pricing Intelligence (simplified for MVP)
- [x] Hospital name matching → provider directory
- [x] Cash price lookup (from pre-indexed MRF cache, not real-time)
- [x] "Price is X% above hospital's published cash price" finding
- [ ] ~~Real-time MRF fetch~~ — POST-MVP

### Rights
- [x] NSA screening (basic — flag if OON indicator present)
- [x] Financial assistance eligibility estimate
- [ ] ~~GFE dispute eligibility~~ — P1, POST-MVP (requires GFE upload + date logic)

### Communications
- [x] Itemized bill request letter
- [x] EOB mismatch dispute letter
- [x] Duplicate charge dispute letter
- [x] Financial assistance application letter
- [x] Phone script (for billing department)
- [ ] ~~Insurance appeal letter~~ — POST-MVP
- [ ] ~~Collections dispute letter~~ — POST-MVP

### Export
- [x] Copy letter to clipboard
- [x] Share via iOS share sheet
- [ ] ~~PDF evidence pack export~~ — P1, POST-MVP (PDFKit complexity)

### Case Management
- [x] Case creation (auto-named)
- [x] Case list (basic)
- [x] Case status (active / resolved / closed)
- [x] Outcome recording (final balance)
- [x] Timeline (auto-logged events)
- [ ] ~~Deadline push notifications~~ — P1, POST-MVP
- [ ] ~~Manual deadline creation~~ — POST-MVP

### Subscription
- [x] Free tier (1 finding preview, 1 active case)
- [x] Monthly premium
- [x] Annual premium
- [x] Paywall with feature list
- [x] Restore purchases
- [x] Server-side receipt validation

### Auth
- [x] Apple Sign In
- [x] Email/password (optional for MVP — can simplify to Apple only)
- [x] JWT + refresh token

### Settings
- [x] Account (profile, sign out)
- [x] Delete account
- [x] Delete individual case
- [x] Privacy Policy link
- [x] Terms of Service link

### Onboarding
- [x] 3-screen onboarding
- [x] Notification permission prompt (even if notifications are POST-MVP — collect permission now)

---

## Explicitly OUT of Scope for v1.0

| Feature | Why Deferred |
|---|---|
| GFE dispute / PPDR | Requires GFE date + 120-day window logic + PPDR fee handling — substantial scope |
| PDF evidence pack | PDFKit multi-page layout complexity — add in v1.1 |
| Push notifications | Backend scheduler needed — deferred to v1.1 |
| Real-time MRF fetch | MRF files are large (GB+) — pre-index in bulk, real-time for v1.2 |
| Insurance appeal letters | Clinical determination scope risk — add in v1.2 |
| Collections dispute | FDCPA details require careful legal review — v1.2 |
| Family plan | Subscription infrastructure complexity — v2.0 |
| Web app | iOS first — web v2.0 |
| B2B (employers, advocates) | Different sales motion — v3.0 |
| State-specific rules | 50-state research required — rolling additions |
| Claims submission | Requires payer integration — out of scope entirely |
| Direct insurer API | Regulation + partnership complexity — not planned |
| Provider portal | B2B — not planned for consumer version |

---

## MVP Success Criteria

The MVP is successful when:

1. **Core loop works end-to-end** — 90%+ of test bills analyzed successfully
2. **OCR accuracy** — Key financial fields (total, patient responsibility, balance) extracted correctly in 85%+ of tests
3. **False-positive rate** — < 10% of "Strong" findings marked Wrong by beta testers
4. **Crash rate** — < 0.5% crash rate in TestFlight
5. **Subscription visible** — Paywall shown correctly, purchase flow works end-to-end

---

## v1.1 Targets (Next Release)

1. PDF evidence pack export
2. Push notification deadline reminders
3. GFE dispute eligibility
4. NSA screening improvements (OON detection from EOB codes)
5. Real-time hospital MRF lookup improvements

---

## v1.2 Targets

1. Insurance appeal letters
2. Collections rights information
3. Auto-categorization of bill type (ER, surgical, outpatient, etc.)
4. Multi-EOB (multiple claims for one case)
5. State-specific balance billing rules (initial states: CA, TX, NY, FL)
