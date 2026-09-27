# BillFixer — Product Definition

> DELETE BEFORE SUBMISSION

---

## One-Sentence Vision

Bill Fixer turns a confusing medical bill + EOB into an evidence-backed action plan: what looks wrong, why, what rule or price source supports it, what to ask for, exactly what to send, and what deadline to follow.

---

## Market Opportunity

- **$220 billion+** in U.S. medical debt (2024 KFF analysis)
- **36%** of U.S. households carry medical debt
- **21%** have a past-due medical bill
- **23%** are paying a medical bill over time
- Hospital billing is systemically complex — EOBs, itemized bills, MRFs, and GFEs are legally mandated but nearly unreadable by consumers
- Existing competitors (Goodbill, Resolve, mediloop, IQBill, BillFighter, Barely Legible, Overturn) prove demand but none combine deterministic analysis + evidence-grounded findings + case management in one polished consumer app

---

## Target User

**Primary:** U.S. adult who received an unexpected or confusing hospital/facility bill

**Scenarios:**
- ER visit with out-of-network surprise charges
- Post-surgery bill that doesn't match the EOB
- Self-pay patient who doesn't know the cash price
- Patient who received a bill after it was supposed to be covered
- Insured patient whose claim was denied
- Low-income patient who may qualify for financial assistance
- Patient going to collections and doesn't know their rights

**Not our user (yet):**
- Providers or insurers (B2B is Phase 2+)
- Patients outside the U.S.
- Patients disputing clinical decisions (medical necessity)

---

## The Core Promise

Upload your bill and EOB → Bill Fixer delivers:

1. A clear human-readable explanation of the bill
2. Potential discrepancies with evidence for each
3. A recommended first action
4. A ready-to-send dispute letter or financial assistance request
5. A phone script for calling billing
6. A deadline tracker and follow-up reminders
7. A full case history tracking original vs. final balance

---

## Product Boundaries (What We Do NOT Do)

| We DO | We DO NOT |
|---|---|
| Analyze bills and EOBs | Provide legal advice |
| Identify potential discrepancies | Provide medical advice |
| Compare hospital-published prices | Guarantee savings |
| Generate dispute letters | Negotiate with providers |
| Generate financial-assistance letters | Make payments |
| Generate phone scripts | Submit claims |
| Track case deadlines | Represent users |
| Show rights/rules that may apply | Determine medical necessity |
| Track resolution and savings | Access provider/insurer systems |

---

## Key Differentiators

### 1. Evidence-Grounded Findings (not just AI hallucinations)
Every finding cites its exact evidence: document page, line item, data source, rule name. No claim without proof.

### 2. EOB Reconciliation Engine (deterministic, not AI)
Mathematical comparison of bill vs. EOB patient responsibility. If bill > EOB, that's a high-confidence flag — no LLM needed.

### 3. Hospital-Specific Pricing (not just Medicare average)
Uses the hospital's own CMS-published MRF data: cash prices, negotiated rates, rate ranges. Shows hospital's own published prices, not just national averages.

### 4. Rights Engine (law-aware, not letter-aware)
Checks No Surprises Act, Good Faith Estimate dispute eligibility, §501(r) financial assistance, and GFE/PPDR deadlines with specific dollar thresholds and day counts.

### 5. Case Management (not just a one-off scan)
Bills resolve over weeks or months. Bill Fixer tracks every step: letters sent, responses received, deadlines, follow-ups, final outcome.

### 6. Confidence + Evidence System
Every finding is labeled: **Strong** (documentary proof), **Likely** (strong indication), **Possible** (worth investigating), **Informational** (benchmark only). Users always know how certain we are.

---

## Competitive Landscape

| Competitor | Weakness to Exploit |
|---|---|
| Goodbill | Human-dependent, expensive, not self-service |
| Resolve | High-dollar concierge only, not mass market |
| mediloop | Flat-fee, no ongoing case management |
| IQBill | Generic AI letters, no evidence grounding |
| BillFighter | Collections-oriented, less analysis depth |
| Barely Legible | Good OCR, limited rights engine |
| Overturn | Privacy-first but limited analysis |

**Our moat:** Evidence engine + Deterministic billing math + Hospital-specific pricing + Rights/action engine + Case management. No single competitor has all five.

---

## Revenue Model

| Product | Price |
|---|---|
| Free tier | Scan + basic explanation + 1 finding preview |
| Monthly premium | $7.99/month |
| Annual premium | $59.99/year (~$5/month) |
| Family tier (future) | $11.99/month (up to 6 household members) |

**Subscription value (not just letters):**
- Unlimited bill + EOB scans
- Full analysis with all findings
- Pricing intelligence
- Financial assistance detection
- All letter types
- Phone scripts
- PDF evidence pack export
- Unlimited active cases
- Deadline reminders
- Case history + savings tracking
- Priority analysis queue

---

## Success Metrics (KPIs)

| KPI | Target |
|---|---|
| Activation | % who successfully scan + analyze a bill |
| Analysis completion | % who complete OCR review |
| Action rate | % who generate a letter or script |
| Resolution rate | % who report some resolution |
| Verified savings rate | % of resolved cases with reduced balance |
| False-positive rate | % of flagged findings marked "Wrong" by user |
| Subscription conversion | Free → paid |
| Month-2 retention | Returning subscribers |
| NPS | Net Promoter Score |

---

## Positioning Statement

> "Bill Fixer — Your medical bill, decoded."
>
> Upload your bill and EOB. Bill Fixer checks the math, reconciles your insurance explanation, compares your hospital's published prices, and tells you exactly what to ask for — with evidence, letters, and a step-by-step plan.
>
> No negotiation. No handling your money. Just evidence, letters, and a plan.

---

## Marketing Language Rules

### Use:
- "Potential billing discrepancy"
- "Compares with your EOB"
- "Based on your hospital's published prices"
- "May qualify for financial assistance"
- "Evidence-backed findings"

### Never Use:
- "80% of medical bills contain errors" (unsubstantiated)
- "Guaranteed savings"
- "Illegal overcharge"
- "AI detects fraud"
- "Proven to save money" (until self-measured)
