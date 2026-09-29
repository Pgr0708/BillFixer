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

---
---

# PART II — V2 SCREEN SET (24 SCREENS)

> Added Sep 28, 2026. Screens 1–12 above are unchanged in *purpose*; this part restates
> each with its assigned background scene and typographic persona, and adds the 12 screens
> the original spec didn't cover. Built out in `docs/Claude outputs/v2/BillFixer-Screens.html`.

**Per-screen contract.** Every screen declares four things before layout is written:

```
SCENE    — background from the Background Registry (DESIGN_SYSTEM.md Part II)
TYPE     — display face + body face from the Typographic Personas table
MOTION   — the one ambient animation that defines this screen
SURFACE  — .card | .glass | .glass-d (which container content lives in)
```

---

## Screen index

| # | Screen | Scene | Display type | Surface |
|---|---|---|---|---|
| 01 | Splash | Aurora Orbit | Bricolage Grotesque | — |
| 02 | Onboarding · See the full picture | Topographic Mint | Outfit | — |
| 03 | Onboarding · Evidence, not guesses | Gold Constellation | Fraunces | — |
| 04 | Onboarding · Your action plan | Ray Burst Lilac | Sora | — |
| 05 | Sign In | Dusk Skyline | Bricolage Grotesque | `.glass-d` |
| 06 | Home · Dashboard | Daylight Mesh | Sora | `.glass` + `.card` |
| 07 | Add Your Document (sheet) | Scrim Bokeh | Manrope | opaque sheet |
| 08 | Bill Capture · Camera | Viewfinder Grain | Space Grotesk | glass bottom panel |
| 09 | Review Your Document | Ivory Paper Stock | Source Serif 4 | `.card` |
| 10 | Extracted Information | Blueprint Grid | Space Grotesk | `.card` |
| 11 | Analyzing Your Bill | Deep Orbit Navy | Bricolage Grotesque | `.glass-d` |
| 12 | Analysis Complete | Radiant Burst | Sora | `.card` |
| 13 | Your Findings | Severity Strata | Archivo | `.card` |
| 14 | Finding Detail · Strong | Crimson Dawn Hatch | Archivo | `.card` |
| 15 | Dispute Letter | Linen & Seal | Libre Baskerville | paper card |
| 16 | Phone Script | Waveform Indigo | Archivo | `.glass-d` |
| 17 | My Cases | Isometric Slate | Manrope | `.card` |
| 18 | Case Timeline | Spine Glow | Manrope | `.card` |
| 19 | Your Rights May Apply | Guilloché Engraving | Newsreader | `.card` |
| 20 | Financial Assistance | Sunrise Ladder | Calistoga | `.card` |
| 21 | Bill Fixer Premium | Obsidian Gold Dust | Fraunces | outlined tiers |
| 22 | Settings | Graphite Rings | Manrope | `.card` |
| 23 | Empty State · No Cases | Cloud Drift Sky | Calistoga | — |
| 24 | Case Resolved | Emerald Aurora | Calistoga + Sora | `.glass-d` |

---

## SCREEN 13: Your Findings

**SCENE** Severity Strata · **TYPE** Archivo / Inter · **MOTION** stagger 70ms · **SURFACE** `.card`

Background bands are keyed to the severity tiers themselves: navy hero at the top, then
crimson, amber, and blue strata descending. Scrolling through the list literally moves you
down the severity gradient.

- **Header** (on navy) — back chevron, `5 found` pill, `Your Findings` 29pt Archivo 800, provider + date.
- **Recommended First Step** — gold 1.5pt border + `goldGlow`. Star glyph, `RECOMMENDED FIRST STEP`
  10px mono tracking .14em, action title, 2-line rationale, gold CTA (46pt tall, not 54 — it's a
  suggestion, not the primary action of the screen).
- **Finding cards** — 4pt left border in severity color. Row 1: severity pill (filled) + confidence
  pill (tinted). Then title / explanation / two amount tiles side by side / `Evidence · N sources`
  disclosure in teal.
- **Free tier** — card 2 renders at `blur(5px) opacity(.75)` with a centered unlock overlay
  (gold lock disc, "Unlock 4 more findings", navy pill). Card 3 is a skeleton at `blur(6px)`.
  Never blur card 1 — the user must get real value before the wall.

---

## SCREEN 14: Finding Detail · Strong

**SCENE** Crimson Dawn Hatch · **TYPE** Archivo / Playfair for evidence · **MOTION** springGentle expand

- **Nav** back / `Strong Finding` pill / overflow menu.
- **Hero** 56pt duplicate-document icon tile, title 24pt Archivo 800, amount 30pt mono in `critical`.
- **Plain-language paragraph** with the CPT code set in mono inline.
- **Evidence card** — three quotes, each a 3pt left rule in its source color
  (teal = bill, crimson = the duplicate, navy = EOB). Quote text is **Playfair Display 15pt**:
  it must read as *transcribed*, not as UI copy.
- **Why this matters** — `criticalSurface` block, one short paragraph.
- **The counter-case** — `infoSurface` block explaining when this finding might be legitimate.
  This is required on every strong finding. We flag; we do not accuse.
- **Actions** primary `Generate Dispute Letter`, secondary `Not an issue — dismiss`.

---

## SCREEN 15: Dispute Letter

**SCENE** Linen & Seal · **TYPE** Libre Baskerville 12.5pt / 1.78 · **MOTION** tap-to-edit rails

- **Nav** back / `Dispute Letter` + `EOB MISMATCH · DRAFT` mono subtitle / `Edit`.
- **3-step chip row** Template → Review → Send.
- **Letter body** on `#FEFDFA` paper card, 8pt radius (paper, not UI), 26px padding.
  Date block → Re: line (bold) → salutation → body paragraphs → signature in Playfair italic.
- **Editable paragraphs** carry a transparent 3pt left rule that turns `info` blue and gains a
  5% tint when tapped. The active paragraph in the mock is the duplicate-charge claim.
- **Disclaimer** hairline-separated, 10.5pt, `textDisabled`: *"Bill Fixer drafts letters from your
  documents — it is not legal advice or representation."*
- **Bottom bar** Copy (navy) + Share (teal), over a gradient fade of the linen field.

---

## SCREEN 16: Phone Script

**SCENE** Waveform Indigo · **TYPE** Archivo / Inter, script in Playfair · **MOTION** bar pulse

- **Nav** back / `Phone Script` / `Billing` context pill.
- **Call card** (`.glass-d`) avatar disc with pulsing phone glyph, provider name, mono number
  and hours, green call button.
- **`STEP 1 · OPENING`** mono label, then the script on a **white** card — maximum contrast,
  because the user is reading this aloud under stress. Script text is Playfair 15.5pt / 1.66.
  A 36×3 gradient tab sits on the card's top edge.
- **Tone chips** below a hairline: `Calm` / `Specific` / `No accusation`.
- **Branch list** `WHAT DID THEY SAY?` → four `.glass-d` rows, lettered A–D. Row D
  ("going to collections") carries a crimson border — it routes to the rights sub-flow.

---

## SCREEN 17: My Cases

**SCENE** Isometric Slate · **TYPE** Manrope 800 / Inter · **MOTION** chip reflow

- **Header** avatar disc + `My Cases` 27pt + teal `+` tile.
- **Search** white pill, 16pt glyph, placeholder "Search provider, amount, code…".
- **Filter chips** wrap to a second line before any label truncates (`chip-collection-reflow`).
  Counts sit inside each chip as a de-emphasized bold.
- **Case cards** provider 16.5pt 800 / status pill · service + date · `CURRENT BALANCE` mono label
  with 25pt amount, right-aligned `POTENTIAL` or `SAVED` in success green · progress bar ·
  deadline row with clock glyph in amber when < 7 days.
- **Tab bar** Cases active, badge `7` on the tab (unresolved findings across all cases).

---

## SCREEN 18: Case Timeline

**SCENE** Spine Glow · **TYPE** Manrope / JetBrains Mono · **MOTION** rail fill

- **Nav** back / provider / overflow. **Tab chips** Summary · Docs · Findings · Letters · **Timeline**.
- **Event rows** 36pt rounded-square node + 2pt connector rail. Node color encodes event class:
  teal gradient = ingest, navy = system, neutral = provider, violet = outbound, green = outcome.
- Each row: title 14.5pt 700 → `MAR 15, 2026 · 10:24 AM` mono 10.5pt tracking .04em → optional payload
  (severity chips, tracking number in mono, quoted provider response in a bordered white block).
- **Final row** balance change: strikethrough old amount → new amount 20pt → delta pill.
- Rail gradient runs teal → `#CBD5E4`, so completed history reads warmer than pending.

---

## SCREEN 19: Your Rights May Apply

**SCENE** Guilloché Engraving · **TYPE** Newsreader 600 / Inter · **MOTION** arc rotate 26s

The guilloché (rotated-ellipse banknote engraving) signals *certificate*, not *courtroom*.

- **Header** on deep teal: back / `4 may apply` pill / shield mark / title 27pt Newsreader /
  the disclaimer line — **"We flag what to check — we don't practice law."**
- **Right cards** 42pt tinted icon tile + title + likelihood pill (`Likely` / `Check` / `Always` /
  `120 days`) + 2-line explanation + `SOURCE · 45 CFR §149.410` in mono 9.5pt.
- Covered: No Surprises Act, §501(r) financial assistance, right to an itemized bill, GFE dispute.
- A deadline-bearing right shows `WINDOW CLOSES JUL 13, 2026` in amber mono.

---

## SCREEN 20: Financial Assistance

**SCENE** Sunrise Ladder · **TYPE** Calistoga / Inter · **MOTION** slider track

Warmest screen in the app by design — this is where a user is most likely to feel shame.

- **Header** `§501(r) nonprofit` pill, helping-hand illustration, `You may qualify for help` 27pt Calistoga.
- **Estimator card** household size stepper (− 3 +) and income slider with a gold track and
  20pt thumb; `$0` / `$120K` mono bounds.
- **Result card** green gradient, animated check disc, `Likely eligible` 18pt Calistoga, plain-English
  explanation with **188% of the Federal Poverty Level** bolded, then two tiles: `YOUR FPL` / `FULL RELIEF UNDER`.
- **Document checklist** green ticks for confirmed, gray circles for outstanding.
- **CTA** gold `Draft my assistance letter`.

---

## SCREEN 21: Bill Fixer Premium

**SCENE** Obsidian Gold Dust · **TYPE** Fraunces 600 / Inter · **MOTION** shimmer 2.6s, rise 9–13s

- **Dismiss** ✕ at 30pt, `rgba(255,255,255,.1)` — present but quiet.
- **Badge** outlined pill, gold star, `BILL FIXER PREMIUM` mono tracking .22em, with a
  `.shine` sweep layer at 24% opacity.
- **Headline** 31pt Fraunces, three lines max. Subline 14pt at 55% white.
- **Features** 2-column grid, 8 rows, teal 3pt checkmarks, staggered 70ms.
- **Tiers** Annual selected (gold 1.5pt border, 7% gold fill, `SAVE 37%` pill notched onto the
  top edge, `$5.00 / month, billed yearly` as the real comparison). Monthly is a quiet outline.
- **CTA** gold gradient with `goldGlow`. Below: auto-renew line, Restore Purchases, Privacy, Terms.

---

## SCREEN 22: Settings

**SCENE** Graphite Rings · **TYPE** Manrope 800 / Inter · **MOTION** drift

- **Account card** 52pt initial disc, name 16.5pt, email, gold `Premium` pill.
- **Groups** each preceded by a mono 9.5pt tracking .18em label: SUBSCRIPTION · NOTIFICATIONS ·
  PRIVACY. Rows are 19pt glyph + 15pt label + control, hairline-separated inside one card.
- **Toggles** 48×29 pill, `success` when on, `#DDE3EC` when off.
- **Privacy explainer** teal gradient card: *"Scans are read with Apple Vision on this phone.
  Names and IDs are stripped before anything reaches our servers."*
- **Destructive group** its own card with a crimson-tinted border, separated by a 14pt gap
  from everything above (`destructive-nav-separation`). Sign out + Delete account & all data.

---

## SCREEN 23: Empty State · No Cases

**SCENE** Cloud Drift Sky · **TYPE** Calistoga / Inter · **MOTION** drift 17s ×5

- Header keeps `My Cases` + `+` so the empty state is a *state*, not a different screen.
- **Illustration** isometric folder with a tilted document, two sparkles, contact-shadow ellipse,
  `float 6s`.
- `No cases yet` 26pt Calistoga, then one honest sentence about what happens next.
- **One** primary CTA — `Scan Your First Bill`. No secondary action competing with it.
- Trust line below: shield glyph + *"Nothing leaves your phone unredacted."*

---

## SCREEN 24: Case Resolved

**SCENE** Emerald Aurora · **TYPE** Calistoga + Sora · **MOTION** ring expand 0.6s, draw 0.9s

- **Check mark** 132pt: pulsing outer ring, glass mid-ring, solid `success` disc, 6pt checkmark
  path drawn over 0.9s.
- `Case resolved` 31pt Calistoga, then a factual sentence naming what the provider actually did.
- **Savings card** (`.glass-d`) `YOU SAVED` mono label, `$892` at 52pt Sora 800, and below a
  hairline: struck-through original → arrow → final balance.
- **Stat row** three glass tiles: days to resolve · letters sent · lifetime saved.
- **Actions** white `Archive this case`, ghost `Share how it went`. Sharing is opt-in and last.

---

## Free vs Premium gating

| Screen | Free | Premium |
|---|---|---|
| 12 Results | Count + severity split visible; savings figure shown | Everything |
| 13 Findings | Finding 1 in full; 2+ blurred behind unlock | All findings |
| 14 Detail | Only for the unlocked finding | All |
| 15 Letter | Locked | All templates |
| 16 Script | Opening statement only | Full branch tree |
| 19 Rights | Visible — never gated | Visible |
| 20 Assistance | Estimator visible, letter locked | Everything |

Rights and financial assistance are **never** paywalled. Gating the one screen that
reaches people who cannot pay is the one thing this product must not do.
