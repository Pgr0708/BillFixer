# BillFixer — Legal & Compliance

> DELETE BEFORE SUBMISSION

---

## Core Legal Positioning

Bill Fixer is a **consumer financial information tool**, not:
- A law firm or attorney
- A healthcare provider
- A medical billing consultant (regulated)
- A claims adjuster
- A HIPAA Business Associate

The app provides **information and tools** to help consumers exercise their existing rights.
It does not provide legal, medical, or financial advice.

---

## Required Disclaimers

### In-App (every analysis result)
> "Bill Fixer provides information to help you understand your bill and take action. This is not legal or financial advice. Findings reflect potential issues for you to investigate — not confirmed billing errors. Always verify with your provider, insurer, and a qualified professional if needed."

### Letter Footer (every generated letter)
> "This letter was prepared using Bill Fixer, a consumer tool for understanding medical bills. It does not constitute legal advice."

### Financial Assistance (every FAP screen)
> "Eligibility is estimated and determined solely by the hospital. Bill Fixer does not guarantee approval or any specific outcome."

### GFE / NSA Finding
> "Based on information you provided, you may be eligible for the federal Patient-Provider Dispute Resolution process under the No Surprises Act. Eligibility depends on the specific facts of your situation. Contact the U.S. Department of Health and Human Services or a qualified professional for guidance."

---

## No Surprises Act (NSA) Compliance

The NSA (42 USC 300gg-111) protects patients from surprise bills.
Key provisions to reference accurately:

| Provision | Detail to Cite |
|---|---|
| Emergency care protection | OON providers at in-network facilities may not balance bill for emergency care |
| Ancillary services | OON anesthesiologists, radiologists, pathologists at in-network facilities protected |
| PPDR threshold | $400+ above GFE triggers patient-provider dispute resolution |
| PPDR deadline | 120 days from initial bill receipt |
| PPDR fee | $25 filing fee (2024) |
| Regulatory source | 45 CFR Part 149, Subpart F |

**Never say:** "The No Surprises Act means you don't owe this."
**Always say:** "Based on [X], you may have rights under the No Surprises Act. Here's what to ask."

---

## IRS §501(r) & Financial Assistance

Nonprofit hospitals (501(c)(3)) are required to:
- Have a written Financial Assistance Policy (FAP)
- Limit charges to FAP-eligible patients
- Provide "amounts generally billed" (AGB) calculation
- Not engage in extraordinary collection actions (ECA) before applying FAP

Key figures to cite accurately:
- §501(r)(4): FAP requirement
- §501(r)(5): charge limitation
- §501(r)(6): billing and collections requirements

**Never guarantee** FAP approval. Always frame as "you may be eligible."

---

## CMS Price Transparency

**Hospital Price Transparency Rule** (effective Jan 1, 2021; enforcement strengthened 2022):
- Hospitals must publish MRF in machine-readable format
- Must include: gross charge, cash/discounted price, payer-specific negotiated rates, min/max rates
- Penalty for non-compliance: up to $300/day for small hospitals, $5,500/day for large hospitals

**Safe citing language:**
> "According to [Hospital Name]'s published price transparency data (required by CMS effective January 2021), the cash price for this service is listed as $X."

Never characterize the difference between bill and published price as "illegal" or "fraud" — the rule requires disclosure, not that all patients be charged the published rate.

---

## App Store Guidelines Compliance

### 3.2.1 — Services
Bill Fixer does not broker professional services.
It generates documents for the USER to review, edit, and use independently.
Legal review section: N/A (no lawyer matching or referral).

### 5.1.2 — User Generated Content
Documents uploaded by users are not shared publicly.
Documents are user-owned, user-controlled, user-deletable.

### 5.2.1 — Intellectual Property
All letter templates are original.
No reproduction of copyrighted medical coding databases.
CPT codes shown are reference codes for user context — no AMA license required for display (codes are used by hospitals in billing and are referenced by CMS publicly).

---

## Prohibited Marketing Claims

The following claims must NEVER appear in App Store marketing, ads, or in-app copy:

| Prohibited | Why |
|---|---|
| "80% of medical bills contain errors" | Unsubstantiated statistic |
| "Guaranteed to save you money" | Cannot guarantee outcomes |
| "AI detects fraud in your bill" | Implies legal determination |
| "HIPAA compliant app" | Implies BA relationship |
| "We'll fight your hospital for you" | Implies legal representation |
| "Proven results" | Requires substantiation |
| "Your bill is wrong" | Definitive claim without basis |

---

## MVP.md — Scope Guardrails

See docs/product/MVP.md for exact feature scope and what is explicitly OUT of scope for v1.

---

## Insurance Appeal Note

Bill Fixer can generate insurance appeal letters but:
- We do NOT advise on medical necessity appeals (clinical determination)
- We only assist with administrative/billing appeals
- Every appeal letter includes the disclaimer above
- Appeal deadlines are user-entered — we cannot verify against insurer systems

---

## Collections Protections (FDCPA)

When a case is in collections phase:
- Show FDCPA debt validation rights (30-day validation window)
- Show cease communication letter option
- Note that billing original creditor ≠ debt collector — different rules apply
- Always caveat: rules vary by state, verify with consumer protection attorney

---

## Regulatory Monitoring

The following rules may change and must be monitored annually:

| Rule | Regulator | Review Frequency |
|---|---|---|
| No Surprises Act PPDR rules | CCIIO/CMS | Annual |
| CMS Price Transparency Rule | CMS | Annual |
| MPFS rates | CMS | Annual (Jan 1) |
| §501(r) regulations | IRS/CMS | Annual |
| CCPA/CPRA | California AG | Annual |
| State balance billing laws | State-specific | Quarterly |
