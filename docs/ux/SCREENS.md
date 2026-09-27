# BillFixer — Screen Specifications

> DELETE BEFORE SUBMISSION
> These specs are written to be used directly with Claude/AI design generation.
> Each screen includes: purpose, layout sections, exact components, interaction details, and design notes.

---

## GLOBAL DESIGN RULES

- Background: `BFColor.background` (#F5F6FA) in light, `#0D1117` in dark
- Safe area: always respected
- Bottom tab bar: persists on all main screens, hidden on full-screen modals
- Navigation: large titles on Home, Cases, Settings. Inline on sub-screens
- All monetary values: dollar sign, 2 decimal places, Decimal type
- All dates: user locale format

---

## SCREEN 1: Splash Screen

**Purpose:** Brand moment, initialization

**Layout:**
- Full-screen hero gradient (brand #0F2B5B → brandLight #1A3F82 → accent #00B4A0, top-left to bottom-right)
- Center: App logo ("B" icon mark) — scales from 0.5 to 1.0 with springBounce animation on appear
- Below logo: "Bill Fixer" in BricolageGrotesque-Bold, 42pt, white
- Below name: "Medical Bill Help" in SF Pro, 17pt, white.opacity(0.7)
- Bottom 20%: subtle animated particles (floating dots, very low opacity, white)
- Loading indicator: thin teal line at very bottom that fills left-to-right

**Duration:** 2 seconds, then transitions to onboarding (new user) or home (returning)
**Transition:** Cross-fade to next screen

---

## SCREEN 2: Onboarding (3 pages)

**Purpose:** Communicate value, build trust

**Layout (all pages):**
- Page progress dots: centered, 8pt dots, 4pt gap, teal = active
- Skip button: top right, ghost style, "Skip" in teal
- Illustration: upper 55% of screen (full-width, no padding)
- Title: BricolageGrotesque-Bold, 32pt, textPrimary, left-aligned, 24pt horizontal padding
- Subtitle: SF Pro, 17pt, textSecondary, left-aligned, same padding
- CTA button: bottom 15%, "Continue" primary style, 80% width, centered

**Page 1: "See the full picture"**
- Illustration: Medical document with highlighted lines in teal
- Title: "See the full picture"
- Subtitle: "Upload your bill and EOB. Bill Fixer reads them so you don't have to decode medical jargon alone."

**Page 2: "Evidence, not guesses"**
- Illustration: Document with connecting lines to evidence sources (MRF, EOB, math check)
- Title: "Evidence, not guesses"
- Subtitle: "Every finding we show you comes with a source. Bill page 2, line 14. Your EOB. Your hospital's own prices."

**Page 3: "Your action plan"**
- Illustration: Letter + phone + checkmark → savings counter
- Title: "Your action plan"
- Subtitle: "Dispute letters, phone scripts, and deadline tracking — everything you need to take action."
- CTA: "Get Started" (not "Continue")

---

## SCREEN 3: Home (Dashboard)

**Purpose:** Hub for all activity, entry point for new scans

**Layout (top → bottom):**

### Hero Section (top 38% of screen, gradient background)
- Background: hero gradient (brand → brandLight), applies to status bar too
- Top left: "Good morning, [Name]" — SF Pro 15pt, white.opacity(0.8)
- Top left below: "Sep 27, 2026" — SF Pro 13pt, white.opacity(0.6)
- Top right: notification bell icon, white
- Center-left: "Your Bills" — BricolageGrotesque-Bold, 36pt, white
- Below: "Active cases · 3 findings · $X potential" — 15pt, white.opacity(0.8)
- Bottom of hero: Quick Stats Row (3 equal columns, glass card):
  - [Total Saved] [Bills Analyzed] [Open Findings]
  - Each: value (BricolageGrotesque-SemiBold, 22pt, white) + label (12pt, white.opacity(0.7))

### Active Cases (horizontal scroll, below hero)
- Section header: "Active Cases" + "See All →"
- Horizontal scroll of BFCaseCard (width = 280pt, height = 140pt)
- Glass card style with thin gradient border
- If no cases: "No active cases" + "Scan your first bill" button

### Scan CTA Card
- Large card (full width minus 32pt padding, height ~120pt)
- Background: teal gradient (accent → accentLight)
- Left: camera.fill icon (40pt, white), title "Scan a New Bill", subtitle "Upload your bill and EOB"
- Right: chevron.right (20pt, white)
- Haptic on tap: medium
- Launches Flow 2 (Bill Capture)

### Recent Findings
- Section header: "Recent Findings" + "View All →"
- Vertical list of 3 compact finding cards
- Compact version: no evidence section, just severity badge + title + amount

### Tips Card (rotating)
- Title: "Did you know?"
- Tip text (rotates every session)
- Teal left accent border

---

## SCREEN 4: Bill Capture

**Purpose:** Multi-page document capture

**Layout:**
- Full screen (no tab bar, no navigation bar — custom UI only)
- Top bar (translucent):
  - Left: "✕ Cancel" (ghost)
  - Center: Progress stepper (Bill → EOB → Review)
  - Right: Flash toggle icon + "1/N" page counter
- Main area: Camera viewfinder (full screen)
  - Corner bracket guides (4 corners, animated subtle pulse)
  - Guides are teal colored, 40pt arm length
  - Document detected: green animated rectangle overlay
  - Quality indicator: confidence bars in bottom right
  - "Position bill within frame" fades out after 3 seconds

- Bottom panel (glass card, 220pt height, attached to bottom):
  - Horizontal scroll of page thumbnails (90 × 120pt each)
  - "Retake" button below selected thumbnail
  - Large capture button: 80pt diameter circle, white border (4pt), white inner circle (60pt), center
  - Left of capture: "Import" button (document.text icon + "Import")
  - Right of capture: "Continue" → active once ≥1 page captured, teal

**Page thumbnail:**
- Image preview with shadow
- Page number badge (top right, navy circle with white number)
- Delete button (top right of thumbnail on long-press)

---

## SCREEN 5: OCR Review

**Purpose:** Let user verify extracted data, fix errors

**Layout:**
- Navigation: "Review Bill" (inline), "Done" (teal, right)
- Progress stepper visible (step 2 of 4)

**Top section (40% height):**
- Document image carousel (tapped field scrolls to highlight on document)
- Thumbnail strip at bottom of image section

**Bottom section (scrollable form):**
Card 1: Header Fields
  - Provider name (editable, text field style)
  - Bill date (date picker style)
  - Account number (editable)
  - Service dates (from → to)
  
Card 2: Financial Summary
  - Total Charges
  - Insurance Payment
  - Patient Responsibility ← highlighted if low confidence (amber)
  - Current Balance ← highlighted if low confidence

Card 3: Line Items (expandable)
  - Each item: code | description | qty | amount
  - "Low confidence" amber badge on items OCR wasn't sure about
  - "+ Add Item" button at bottom
  - "Something missing? Add it here"

Low confidence indicator:
  - Amber left border on the field
  - Small "⚠ Check this" label
  - Tap to focus and fix

---

## SCREEN 6: Analysis Loading

**Purpose:** Processing indicator, set expectations

**Layout:**
- Full screen, navy gradient background
- Top center: BillFixer logo mark (subtle pulse animation, 3s loop)
- Center: "Analyzing your bill..." — BricolageGrotesque-SemiBold, 24pt, white
- Below: Step list, left-aligned, 32pt from left edge:
  - Step row: [Spinner / Checkmark] [Label]
  - Spinner: circular loading, teal
  - Checkmark: animated path draw, teal, then shrinks to solid circle
  - Steps:
    1. "Reading your bill..."
    2. "Checking the math..."
    3. "Comparing with your EOB..." (only if EOB provided)
    4. "Looking up hospital prices..."
    5. "Checking your rights..."
    6. "Building your action plan..."
  - Each step completes with haptic (light) and checkmark animation

**Animation:**
- Steps appear sequentially (not all at once)
- Each step label fades in as previous completes
- Subtle particle background (floating dots, very low opacity)

---

## SCREEN 7: Findings

**Purpose:** Present analysis results, drive action

**Layout:**
- Navigation: "Your Findings" (large title), "[X] Found" right badge

**Summary Card (top, full width):**
- Background: gradient (brand → brandMuted)
- "We found [N] things worth checking"
- Potential savings: "[LOCK ICON + blurred if free] or "Up to $[X]" if premium"
- Case name + status badge

**Recommended First Action Card:**
- Gold border (1.5pt), gold glow shadow
- "⭐ Recommended First Step" label (11pt, gold)
- Action title (bold)
- Action description
- CTA button (primary, full width)

**Finding Cards (vertical list, staggered animation):**

Each card:
```
┌─────────────────────────────────────┐
│ [🔴/🟠/🔵/⚪ Severity] [Confidence] │  ← badges
│                                     │
│ Finding title                       │  ← headline font
│ Short explanation (2 lines max)     │  ← body font
│                                     │
│ Bill: $690.00    EOB: $540.00       │  ← Decimal, monospace
│ Difference: $150.00                 │  ← colored (red if over)
│                                     │
│ ▾ Evidence (tap to expand)         │
│   Bill page 1: "Amount Due $690"   │  ← New York serif, teal block
│   EOB Claim #8821-X: "Resp $540"  │
│                                     │
│ [✉ Generate Dispute Letter]        │  ← primary action button
└─────────────────────────────────────┘
```

Free tier: cards 2+ blurred with "Unlock to see all findings" overlay

---

## SCREEN 8: Letter Preview

**Purpose:** Review, edit, and send generated letter

**Layout:**
- Navigation: "Dispute Letter" (inline)
- Toolbar (bottom bar):
  - Edit | Copy | Share | PDF Export (icons + labels)

**Letter content:**
- White card, full width, scrollable
- Font: New York Medium, 15pt (document-like feel)
- Line height: 1.6
- Editable paragraphs show blue left accent border on tap

**Footer:**
- Gray disclaimer text (13pt)
- "Review this letter before sending. This is not legal advice."

---

## SCREEN 9: Cases List

**Purpose:** Manage all cases

**Layout:**
- Large title: "Cases"
- Filter bar (horizontal scroll): All / Active / Awaiting / Resolved / Closed
- Search bar (expandable)
- BFCaseCard list (full-width cards)

**Empty state:**
- Illustration: Friendly folder with sparkle
- Title: "No cases yet"
- Subtitle: "Scan your first bill to get started"
- CTA: "Scan a Bill" (primary button)

---

## SCREEN 10: Case Detail

**Purpose:** Deep dive into one case

**Layout (tab-based within screen):**
Top: Case header card
  - Provider name + service type
  - Status badge (color-coded)
  - Original: $X → Current: $X (with right-pointing arrow)
  - Verified savings: [green] "$X saved" (if confirmed)

Segmented control / tabs (below header):
  - Summary | Documents | Findings | Letters | Timeline

**Summary Tab:**
- Outstanding balance card (large number)
- Progress toward resolution
- Next deadline (prominent if approaching)
- Recommended action

**Documents Tab:**
- Bill thumbnail + "View" button
- EOB thumbnail + "View" button
- "Add Document" button

**Findings Tab:**
- Compact finding cards (same as Findings screen, but condensed)

**Letters Tab:**
- List of generated letters with type, date, sent status
- "Generate New Letter" button

**Timeline Tab:**
- Chronological event list
- Events: document added, letter generated, letter sent, balance updated, etc.
- User can add manual note events

---

## SCREEN 11: Paywall

**Purpose:** Convert free users to premium

**Layout:**
- Full-screen modal (no dismiss unless user taps X)
- X dismiss button (top right, only if user already has seen it once)
- Background: dark navy (#0D1117) with subtle particle animation

Top:
- Gold shimmer badge: "BILL FIXER PREMIUM" (shimmer animation loops)
- Headline: BricolageGrotesque-Bold, 28pt, white: "Take back control of your medical bills"
- Subline: 15pt, white.opacity(0.7): "Unlock full analysis, letters, and case tracking"

Feature list (center, staggered appear animation):
- ✓ All findings, unlocked
- ✓ Professional dispute letters
- ✓ Phone scripts with responses
- ✓ Hospital price comparison
- ✓ Financial assistance detection
- ✓ PDF evidence export
- ✓ Unlimited cases
- ✓ Deadline reminders

Each row: teal checkmark + white label, stagger 0.05s each

Pricing toggle:
- Monthly | Annual (toggle control, pill style)
- Annual selected by default
- Annual: "$59.99/year — Save 37%" (gold highlight on savings text)
- Monthly: "$7.99/month"

CTA:
- "Start Premium" — gold gradient button, large, full width minus 32pt padding
- Subtle gold glow shadow
- Below: "Cancel anytime · Auto-renews · Manage in Settings"
- "Restore Purchases" link (gray, smaller)
- Privacy · Terms links (smallest gray text)

---

## SCREEN 12: Settings

**Layout:**
- Large title: "Settings"
- Standard grouped list style (but custom styled: white cards, 14pt rounded radius)

**Sections:**
1. Account — Profile, Subscription Status, Sign Out
2. Notifications — Deadline reminders, Follow-ups
3. Privacy — Auto-delete rules, Delete all data, Delete account
4. About — Privacy Policy, Terms, Version
5. Support — Contact, Report, Rate

Account card (top):
- Full name + email
- Subscription status badge (Premium Annual / Free)
- "Manage Subscription" button (if premium)
