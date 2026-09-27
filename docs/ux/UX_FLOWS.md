# BillFixer — UX Flows

> DELETE BEFORE SUBMISSION

---

## Tab Bar Navigation

```
Tab 1: Home          — Dashboard, active cases, quick stats
Tab 2: Cases         — Case list, case detail
Tab 3: Scan (Center) — Bill capture entry point (elevated FAB style)
Tab 4: Scripts       — Phone scripts and letter templates
Tab 5: Settings      — Account, subscription, privacy
```

---

## Flow 1: First Launch / Onboarding

```
App Launch
    ↓
Splash Screen (animated logo, 2s)
    ↓
Onboarding Page 1: "See the full picture"
  — Illustration + headline + subtitle
  — Skip button (top right)
    ↓
Onboarding Page 2: "Evidence, not guesses"
    ↓
Onboarding Page 3: "Your step-by-step plan"
    ↓
Sign Up / Sign In (or Continue with Apple)
    ↓
Optional: Notification Permission Request
    ↓
Home Screen
```

**States:**
- Splash: logo animates in, gradient background pulses
- Onboarding: page indicator dots, swipe-enabled, skip available
- Auth: Apple Sign In + Email/Password
- Permission: custom pre-permission prompt before system dialog

---

## Flow 2: Scan New Bill (Core Flow)

```
Home / Scan Tab Tap
    ↓
New Case Setup (optional: name the case, pre-fills provider if known)
    ↓
Bill Capture Screen
  ├── Camera (default tab)
  ├── Photo Library
  └── PDF Import

  [Camera Active]
      ↓
  Viewfinder with animated guides
      ↓
  User captures page(s)
  — Page thumbnails appear in bottom panel
  — Retake / Reorder / Delete available
      ↓
  "Add another page?" prompt or Continue
    ↓
Processing Indicator (Vision OCR, on-device)
    ↓
OCR Review Screen
  — Form: Provider, Date, Total, Patient Responsibility, Insurer
  — Line items list (editable)
  — Low confidence fields highlighted amber
  — "Something look wrong? Tap to fix"
    ↓
"Do you have an EOB?" Prompt
  ├── Yes → EOB Capture (same flow as bill capture)
  └── Skip → Continue without EOB (reduced confidence analysis)
    ↓
EOB OCR Review (if uploaded)
    ↓
Analysis Running Screen
  — Animated step checklist (see DESIGN_SYSTEM.md)
  — Minimum display: 2.5s for perceived quality
    ↓
Findings Screen (see Flow 3)
```

**Error States:**
- OCR fails on a page → "We couldn't read this page clearly. Retake?"
- PDF encrypted → "This PDF is password-protected. Try printing to PDF first."
- Poor image quality → Quality indicator in viewfinder, warning before OCR
- No bill found in image → "We didn't detect a bill. Adjust the frame and try again."

---

## Flow 3: Reviewing Findings

```
Findings Screen
    ↓
Summary Header:
  — Case name + status
  — "We found [N] things worth checking"
  — Potential savings range (or lock if free)
    ↓
Finding Cards (staggered reveal)
  — Sorted: Strong → Likely → Possible → Informational
    ↓
Tap Finding Card:
    ├── Expands in-place (matchedGeometry)
    │   — Full explanation
    │   — Evidence with document thumbnail
    │   — Applicable rule or source
    │   — Confidence explanation
    │   └── Recommended action CTA
    ↓
"Recommended First Action" pinned card (top)
    ↓
User selects action → Flow 4 (Generate Communication)
```

**States:**
- No findings: "Good news — we didn't find any obvious issues." + green checkmark animation
- Free tier: findings 2+ blurred with paywall prompt
- Loading: skeleton cards with shimmer

---

## Flow 4: Generate Communication

```
User taps action on finding card
    ↓
Action Selection Sheet (if multiple applicable):
  — "Request itemized bill"
  — "Dispute EOB mismatch"
  — "Dispute duplicate charge"
  — "Ask for self-pay adjustment"
  — "Apply for financial assistance"
  — "GFE dispute"
    ↓
Letter Preview Screen
  — Pre-filled letter with extracted data
  — Serif font, document-style layout
  — "Review before sending" disclaimer
    ↓
Edit Mode:
  — Tap any paragraph to edit inline
  — Blue edit indicators on editable paragraphs
    ↓
Actions:
  ├── Copy to clipboard
  ├── Share (AirDrop, Mail, Messages)
  ├── Export as PDF (PDFKit)
  └── Save to Case (default)
    ↓
"Mark as sent?" prompt after sharing
  → Logs to case timeline
  → Sets follow-up reminder (configurable)
```

---

## Flow 5: Phone Script

```
Case → Phone Script (or Scripts Tab)
    ↓
Script Setup:
  — Which issue are you calling about? (picker)
  — Who are you calling? (Billing / Insurer / Collections)
    ↓
Script Screen:
  — Opening statement
  — Decision tree navigation
  — "What did they say?" prompts
    ↓
Response branches:
  ├── "Bill is correct" → What to say
  ├── "Can't negotiate" → Transfer request
  ├── "Send documents" → Document list
  ├── "Offering discount" → Counter-offer
  ├── "Threatening collections" → Rights language
  └── "Agreed to reduce" → Confirmation steps
    ↓
Post-call:
  — "Update your case" prompt
  — Log outcome
  — Set follow-up if needed
```

---

## Flow 6: Financial Assistance

```
Finding: "You may qualify for financial assistance"
    ↓
Financial Assistance Screen:
  — Hospital name + FAP status (nonprofit/for-profit)
  — Income threshold table (FPL percentages)
  — "Are you potentially eligible?" estimator:
      — Household size picker
      — Approximate annual income slider/input
      → Eligibility estimate shown
  — Required documents checklist
  — Application link / PDF download
    ↓
Generate FAP Letter → Flow 4
    ↓
"Set a reminder to follow up?"
```

---

## Flow 7: Case Management

```
Cases Tab
    ↓
Case List:
  — Active / Awaiting Response / Resolved / Closed
  — Sort: Recent / Deadline / Amount
    ↓
Case Detail Screen:
  ┌── Summary (original balance, current balance, savings)
  ├── Documents (bill, EOB, GFE thumbnails)
  ├── Findings (mini cards, tap to expand)
  ├── Letters (list of generated letters, tap to view)
  ├── Timeline (chronological events log)
  ├── Deadlines (color-coded deadline list)
  └── Notes (free text notes)
    ↓
Update Balance:
  — "Balance was reduced" → Enter new amount → Savings calculated
    ↓
Mark Resolved:
  — Select outcome per finding
  — Enter final balance
  — Case moves to Resolved
```

---

## Flow 8: Subscription

```
Free user encounters locked feature:
    ↓
Paywall Sheet:
  — Gold "PREMIUM" badge
  — Feature highlights (animated in)
  — Monthly / Annual toggle
  — "Start Premium" CTA
  — "Restore Purchases" link
    ↓
StoreKit 2 purchase flow (native Apple UI)
    ↓
Success:
  — Confetti / celebration animation
  — "You're all set!" confirmation
  — Returns to previous screen with feature unlocked
    ↓
Failure:
  — Error message + retry option
```

---

## Flow 9: Settings

```
Settings Screen:
  ├── Account
  │   ├── Profile (name, email)
  │   ├── Subscription status + manage
  │   └── Sign out
  ├── Notifications
  │   ├── Deadline reminders toggle
  │   ├── Follow-up reminders toggle
  │   └── Marketing toggle
  ├── Privacy
  │   ├── Data stored overview
  │   ├── Auto-delete rules
  │   ├── Delete all cases
  │   └── Delete account
  ├── About
  │   ├── Privacy Policy (Safari sheet)
  │   ├── Terms of Service
  │   └── App version
  └── Support
      ├── Contact support
      ├── Report a problem
      └── Rate the app
```

---

## Edge Cases & Error States

| Scenario | Handling |
|---|---|
| No internet during analysis | Queue for analysis when online, show offline indicator |
| Analysis timeout | Retry option + partial results if available |
| Very faint bill scan | Quality warning in viewfinder before capture |
| Bill in non-English | Language detection → "We work best with English bills" |
| Very large PDF (>50MB) | Size error before upload begins |
| Duplicate case (same bill) | Detect similar amounts/dates → "Looks similar to [Case X]. Add to existing?" |
| Hospital not found in directory | Manual search + "Skip price comparison" option |
| GFE deadline already passed | Show expired state clearly, explain options |
| Collections stage detected | Special collections sub-flow with rights information |
| Subscription lapsed mid-case | Blur new findings, keep existing ones accessible |
