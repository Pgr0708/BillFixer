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

---
---

# PART II — V2 NAVIGATION MAP

> Added Sep 28, 2026. Flows 1–9 above still define behaviour. This part maps them onto the
> 24 built screens and adds the scene-transition rules that come with the V2 scenic system.

---

## Screen graph — splash to every terminal state

```
                              ┌─────────────┐
                              │ 01 SPLASH   │  2.0s, cross-fade
                              └──────┬──────┘
                    new user ────────┴──────── returning
                        │                          │
            ┌───────────▼──────────┐               │
            │ 02 → 03 → 04         │               │
            │ Onboarding (swipe)   │               │
            └───────────┬──────────┘               │
                        │                          │
                 ┌──────▼──────┐                   │
                 │ 05 SIGN IN  │                   │
                 └──────┬──────┘                   │
                        │                          │
                        └────────┬─────────────────┘
                                 │
                        ┌────────▼────────┐
           ┌───────────►│  06 HOME        │◄────────────┐
           │            └────────┬────────┘             │
           │                     │ Scan tab / CTA       │
           │            ┌────────▼────────┐             │
           │            │ 07 ADD DOCUMENT │ sheet       │
           │            └────────┬────────┘             │
           │           ┌─────────┼─────────┐            │
           │       camera     photos      pdf           │
           │           └─────────┼─────────┘            │
           │            ┌────────▼────────┐             │
           │            │ 08 CAMERA       │             │
           │            └────────┬────────┘             │
           │            ┌────────▼────────┐             │
           │            │ 09 DOC REVIEW   │             │
           │            └────────┬────────┘             │
           │            ┌────────▼────────┐             │
           │            │ 10 OCR EDIT     │             │
           │            └────────┬────────┘             │
           │                 "Have an EOB?"             │
           │              ┌──────┴──────┐               │
           │            yes            skip             │
           │              │              │              │
           │         (08→09→10          │              │
           │          again for EOB)     │              │
           │              └──────┬───────┘              │
           │            ┌────────▼────────┐             │
           │            │ 11 ANALYSIS     │ min 2.5s    │
           │            └────────┬────────┘             │
           │            ┌────────▼────────┐             │
           │            │ 12 RESULTS      │             │
           │            └────────┬────────┘             │
           │            ┌────────▼────────┐             │
           │            │ 13 FINDINGS     │◄──── 21 PAYWALL (on unlock)
           │            └────────┬────────┘
           │            ┌────────▼────────┐
           │            │ 14 DETAIL       │
           │            └────────┬────────┘
           │        ┌────────────┼────────────┬──────────────┐
           │   ┌────▼────┐  ┌────▼────┐  ┌────▼────┐   ┌─────▼─────┐
           │   │15 LETTER│  │16 SCRIPT│  │19 RIGHTS│   │20 ASSIST  │
           │   └────┬────┘  └────┬────┘  └────┬────┘   └─────┬─────┘
           │        └────────────┴────────────┴──────────────┘
           │                     │ logged to case
           │            ┌────────▼────────┐
           │            │ 18 TIMELINE     │
           │            └────────┬────────┘
           │            ┌────────▼────────┐
           │            │ 24 RESOLVED     │
           │            └────────┬────────┘
           └──────────────────────┘

  Tab bar (persistent on 06, 17, 22, 23):
  [ Home 06 ] [ Cases 17 ] [ (Scan) 07 ] [ Scripts 16 ] [ Settings 22 ]
                  │
                  └── empty → 23 EMPTY STATE
```

---

## Scene transition rules

Because every screen owns a background, transitions now have to reconcile two scenes.
Three rules keep it from feeling like a slideshow:

**1. Forward navigation cross-fades the background, slides the content.**
The scene layer cross-fades over 0.35s while content slides horizontally over 0.25s.
The background always settles *before* the content does — the room changes, then you arrive.

**2. Value-tier transitions run dark→light or light→dark deliberately.**

| Transition | Direction | Why |
|---|---|---|
| 10 → 11 Analysis | light → dark | Work is happening; attention narrows |
| 11 → 12 Results | dark → light | Relief; the answer is here |
| 13 → 21 Paywall | light → obsidian | A deliberate mode change, not a nag |
| 18 → 24 Resolved | light → emerald | Earned, celebratory |

**3. Modal sheets never change the scene.** 07 (Add Document) blurs and scrims the scene
underneath it rather than replacing it, so the user keeps their place.

---

## Flow 2a: Capture, expanded (V2)

```
06 Home · Scan CTA or center tab
   └── haptic: medium
        ▼
07 Add Your Document  (sheet, .presentationDetents([.medium]))
   ├── Take a Photo      → 08
   ├── Import from Photos → 09 (skip camera)
   └── Import PDF        → 09 (skip camera)
   └── inline hint: "Adding both bill and EOB unlocks reconciliation"
        ▼
08 Bill Capture
   ├── edge detection → green rect + "Document detected · sharp"
   ├── capture → screen flash + haptic.medium, thumbnail appends
   ├── page thumbnails: tap to select, long-press to delete
   └── Done (N) → 09
        ▼
09 Review Your Document
   ├── page carousel, low-confidence regions outlined in crimson
   ├── OCR badge: "OCR 96%"
   └── Continue → 10
        ▼
10 Extracted Information
   ├── fields grouped: header / financial / line items
   ├── low-confidence field: amber 4pt rail + "⚠ Check this" + confidence bar
   ├── duplicate line pre-highlighted in crimson (deterministic check, pre-LLM)
   └── Run Analysis → "Have an EOB?" → yes: loop 08–10 · skip: → 11
        ▼
11 Analyzing (steps complete sequentially, haptic.light each) → 12
```

**Error states**, unchanged in logic, now scene-aware:

| Error | Where | Treatment |
|---|---|---|
| Page unreadable | 08 | Bracket color → crimson, toast "We couldn't read this page clearly. Retake?" |
| Encrypted PDF | 07 | Sheet stays open, inline error under the PDF row |
| Poor quality | 08 | Detection chip → amber "Low contrast — try more light" |
| No bill detected | 08 | Brackets stop pulsing, hint returns |
| Offline | 11 | Step 4 (hospital prices) shows an offline chip; other steps still complete |

---

## Flow 3a: Findings, expanded (V2)

```
12 Analysis Complete
   ├── donut counts up 0→5 over 1.4s, haptic.success on settle
   ├── severity chips stagger in 70ms apart
   ├── savings card shimmers once
   └── View All Findings → 13
        ▼
13 Your Findings
   ├── Recommended First Step pinned above the list (gold)
   ├── cards sorted Strong → Likely → Possible → Informational
   ├── swipe right → dismiss "Not an issue"
   ├── swipe left  → generate letter
   ├── FREE: card 1 full, cards 2+ blurred → 21
   └── tap card → 14
        ▼
14 Finding Detail
   ├── evidence block always cites document + page + line
   ├── counter-case block is mandatory on Strong findings
   └── Generate Dispute Letter → 15
```

---

## Flow 10 (new): Rights and assistance

Reachable from 12 (`Rights` quick action), 14 (rights-type finding), and 16 branch D.

```
12 / 14 / 16-D
   ▼
19 Your Rights May Apply
   ├── No Surprises Act        → 15 letter (NSA template)
   ├── §501(r) assistance      → 20
   ├── Itemized bill right     → 15 letter (itemization request)
   └── GFE dispute             → 15 letter (GFE template) + deadline → 18
        ▼
20 Financial Assistance
   ├── household size + income → FPL estimate
   ├── document checklist
   └── Draft my assistance letter → 15
        ▼
"Set a reminder to follow up?" → writes a deadline event to 18
```

**Never gated.** 19 and 20 are fully available on the free tier. See the gating table in
`SCREENS.md` Part II.

---

## Flow 11 (new): Resolution

```
18 Case Timeline
   ├── "Balance was reduced" → enter new amount → savings computed
   ├── provider response logged (quoted, with date)
   └── Mark Resolved
        ├── select outcome per finding
        ├── enter final balance
        ▼
24 Case Resolved
   ├── checkmark draw 0.9s + haptic.success
   ├── savings counts up
   ├── Archive this case → 17 (Resolved filter)
   └── Share how it went → share sheet (opt-in, never prompted twice)
```

---

## Tab bar behaviour

| Tab | Screen | Badge | Notes |
|---|---|---|---|
| Home | 06 | — | Scroll position preserved on return |
| Cases | 17 / 23 | Unresolved finding count | 23 replaces 17 when the list is empty |
| Scan | 07 | — | Elevated FAB; presents a sheet, never pushes |
| Scripts | 16 | — | Opens the script picker when no case is in context |
| Settings | 22 | — | — |

Center tab presents a **sheet**, not a tab switch — the scan flow is a task, not a
destination, and it must be dismissible back to wherever the user was
(`modal-vs-navigation`).

---

## Accessibility checkpoints per flow

- **Capture (08)** — detection state announced via `aria-live`/`UIAccessibility.post`, never
  color-only; capture button is 78pt.
- **Findings (13)** — severity conveyed by pill *label* + icon + color, never color alone.
- **Blurred paywall cards (13)** — hidden from the accessibility tree entirely; the unlock
  overlay is the only focusable element in that region.
- **Timeline (18)** — each node has a text alternative naming the event class.
- **All scenes** — background SVGs are `aria-hidden="true"`; they carry no information.
- **Reduced motion** — every flow completes identically with all animation disabled.
