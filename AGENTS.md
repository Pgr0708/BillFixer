# BillFixer — Agent Instructions

> ⚠️ DELETE THIS ENTIRE /docs FOLDER BEFORE APP STORE SUBMISSION. These files are for development guidance only.

---

## What Is Bill Fixer?

Bill Fixer is a **U.S.-market consumer iOS app** that turns confusing medical bills and Explanation of Benefits (EOB) documents into evidence-backed action plans. It identifies billing discrepancies with deterministic logic, compares hospital-published pricing (CMS MRF), detects applicable consumer-protection rules (No Surprises Act, GFE, FAP/§501r), and generates dispute letters, phone scripts, and financial-assistance communications — all without acting as a legal representative or making unsupported fraud claims.

---

## Core Principle (Never Violate)

> **The LLM explains and writes. Deterministic engines analyze. The LLM does NOT independently judge legality or determine overcharges.**

```
Raw Bill/EOB Image
      ↓
Vision OCR (on-device, Apple framework)
      ↓
Structured Data Extraction
      ↓
Manual OCR Correction UI (user verifies)
      ↓
Deterministic Checks (no LLM — pure logic)
      ↓
Hospital Price Lookup (CMS MRF API)
      ↓
EOB Reconciliation Engine (deterministic math)
      ↓
Rights Engine (NSA, GFE, FAP checks)
      ↓
Evidence Bundle Assembly
      ↓
LLM (structured JSON prompt — backend only)
      ↓
Validated JSON Response
      ↓
iOS UI Rendering
      ↓
Letter / Script / PDF Export
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| iOS Client | Swift 6, SwiftUI, Swift Concurrency |
| OCR | Apple Vision framework (on-device) |
| Local Persistence | SwiftData |
| Secrets | Keychain |
| Networking | URLSession + async/await |
| Subscriptions | StoreKit 2 |
| Backend API | Node.js + Express |
| Database | MySQL |
| Document Storage | Cloudflare R2 |
| Queue / Workers | Redis + Bull (background jobs) |
| AI/LLM | Backend-only — GPT-4o or Claude 3.5 via server |
| Infrastructure | Hostinger VPS |

---

## Architecture Rules

1. **MVVM** — Views render state only. Zero business logic in Views.
2. All network calls through `APIClient` service layer only.
3. LLM is **NEVER** called from iOS. Always via backend endpoint.
4. API secrets in **Keychain only**. Never source code, Info.plist, UserDefaults.
5. Use `async/await` and structured concurrency throughout.
6. Services must be **protocol-backed** and **dependency-injected**.
7. All monetary values use `Decimal`. Never `Double` or `Float`.
8. Avoid unnecessary third-party dependencies — prefer Apple frameworks.
9. Every new feature needs a unit test for core business logic.

---

## Privacy Absolute Rules

- Never log raw document content.
- Never log patient names, DOBs, insurance IDs, diagnosis codes.
- Never include sensitive data in analytics events or crash reports.
- Always perform OCR on-device (Vision framework).
- Delete temporary processing files after use.
- Redact PII before sending to LLM.
- Never send raw medical documents to any third-party API.

---

## Reference Files

| Topic | File |
|---|---|
| Product vision | docs/product/PRODUCT.md |
| Feature requirements | docs/product/REQUIREMENTS.md |
| MVP scope | docs/product/MVP.md |
| UX flows | docs/ux/UX_FLOWS.md |
| Design system | docs/ux/DESIGN_SYSTEM.md |
| Screen specs | docs/ux/SCREENS.md |
| Architecture | docs/architecture/ARCHITECTURE.md |
| Data model | docs/data/DATA_MODEL.md |
| API spec | docs/api/API_SPEC.md |
| Bill analysis logic | docs/analysis/BILL_ANALYSIS.md |
| AI pipeline | docs/ai/AI_PIPELINE.md |
| Privacy | docs/privacy/PRIVACY.md |
| Security | docs/privacy/SECURITY.md |
| Legal | docs/legal/LEGAL.md |
| Subscriptions | docs/infra/SUBSCRIPTIONS.md |
| Infrastructure | docs/infra/INFRASTRUCTURE.md |
| Testing | docs/testing/TESTING.md |
| Analytics | docs/growth/ANALYTICS.md |
| App Store | docs/growth/APP_STORE.md |
| Current state | docs/CURRENT_STATE.md |
| Architecture decisions | docs/decisions/ |

---

> Delete this file and the entire /docs folder before App Store submission.
