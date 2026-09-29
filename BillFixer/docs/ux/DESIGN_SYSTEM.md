# BillFixer — Design System

> ⚠️ DELETE BEFORE SUBMISSION
> This file is the **primary design specification** for Claude and all design generation tools.
> Every UI element, animation, color, font, haptic, and component is defined here.

---

## Design Philosophy

**Calm Authority.** Bill Fixer exists in a moment of stress — unexpected medical debt, confusing paperwork, feeling powerless. The design must feel like a knowledgeable, calm advisor: reassuring, clear, trustworthy, never alarming. It should feel premium enough that users trust it with sensitive data, but human enough that it doesn't feel like a cold medical system.

**Keywords:** Calm · Trustworthy · Clinical-but-warm · Premium · Precise · Spacious · Evidence-grounded

**Anti-keywords:** Cold · Corporate · Alarming · Gamified · Neon · Cheap · Busy · Generic

---

## Color Palette

### Primary Brand Colors

```swift
// Base — Deep Navy Blue (primary interactive)
BFColor.brand = Color(hex: "#0F2B5B")
BFColor.brandLight = Color(hex: "#1A3F82")
BFColor.brandMuted = Color(hex: "#2D5BA6")

// Accent — Soft Teal (action, positive, progress)
BFColor.accent = Color(hex: "#00B4A0")
BFColor.accentLight = Color(hex: "#00D4BC")
BFColor.accentMuted = Color(hex: "#80E9E0")

// Gold — Warm Gold (premium, highlight, important)
BFColor.gold = Color(hex: "#E8A422")
BFColor.goldLight = Color(hex: "#F5C35C")
BFColor.goldMuted = Color(hex: "#FCEBC0")
```

### Semantic Colors

```swift
// Success / Resolved
BFColor.success = Color(hex: "#1DB86A")
BFColor.successSurface = Color(hex: "#E8F9F0")

// Warning / Possible Issue
BFColor.warning = Color(hex: "#F5A623")
BFColor.warningSurface = Color(hex: "#FEF6E4")

// Critical / Strong Finding
BFColor.critical = Color(hex: "#E53E3E")
BFColor.criticalSurface = Color(hex: "#FFF0F0")

// Info / Informational Benchmark
BFColor.info = Color(hex: "#3182CE")
BFColor.infoSurface = Color(hex: "#EBF8FF")

// Neutral
BFColor.neutral = Color(hex: "#718096")
BFColor.neutralSurface = Color(hex: "#F7F8FA")
```

### Background System (Dark Mode aware)

```swift
// Light Mode
BFColor.background = Color(hex: "#F5F6FA")
BFColor.surface = Color.white
BFColor.surfaceElevated = Color(hex: "#FFFFFF")
BFColor.surfaceOverlay = Color(hex: "#F0F2F8")

// Dark Mode
BFColor.backgroundDark = Color(hex: "#0D1117")
BFColor.surfaceDark = Color(hex: "#161B22")
BFColor.surfaceElevatedDark = Color(hex: "#21262D")
BFColor.surfaceOverlayDark = Color(hex: "#30363D")
```

### Text Colors

```swift
BFColor.textPrimary = Color(hex: "#1A202C")
BFColor.textSecondary = Color(hex: "#4A5568")
BFColor.textTertiary = Color(hex: "#718096")
BFColor.textDisabled = Color(hex: "#A0AEC0")
BFColor.textInverse = Color.white
BFColor.textBrand = Color(hex: "#0F2B5B")
BFColor.textAccent = Color(hex: "#00B4A0")
```

### Gradient Definitions

```swift
// Hero gradient — used on home screen, splash
BFGradient.hero = LinearGradient(
    colors: [Color(hex: "#0F2B5B"), Color(hex: "#1A3F82"), Color(hex: "#00B4A0")],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

// Card gradient — elevated surface
BFGradient.card = LinearGradient(
    colors: [Color.white, Color(hex: "#F8FAFF")],
    startPoint: .top,
    endPoint: .bottom
)

// Premium gradient — paywall, premium badges
BFGradient.premium = LinearGradient(
    colors: [Color(hex: "#E8A422"), Color(hex: "#F5C35C"), Color(hex: "#E8A422")],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

// Success gradient — resolved cases
BFGradient.success = LinearGradient(
    colors: [Color(hex: "#1DB86A"), Color(hex: "#00D4BC")],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

// Danger gradient — critical findings
BFGradient.danger = LinearGradient(
    colors: [Color(hex: "#E53E3E"), Color(hex: "#F5A623")],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

// Glassmorphism surface (for overlays, sheets)
BFGradient.glass = LinearGradient(
    colors: [
        Color.white.opacity(0.25),
        Color.white.opacity(0.10)
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
```

---

## Typography

### Font Families

Bill Fixer uses **3 font families** in combination:

```swift
// 1. SF Pro Display / SF Pro Text — Apple system font
//    Used for: all body text, UI labels, numbers
//    Reason: Legibility, Dynamic Type, accessibility

// 2. "New York" (Apple serif) — SF Pro's serif companion
//    Used for: Large hero numbers (bill amounts), evidence quotes
//    Reason: Authoritative, document-like, premium feel

// 3. Bricolage Grotesque (Google Fonts / via custom font)
//    Used for: App logo, screen titles, marketing copy, paywall
//    Reason: Modern, confident, distinctive brand voice
//    Import: via UIFont registration + SwiftUI Font extension
```

### Type Scale

```swift
// Display — App name, hero amounts, splash
BFFont.display = Font.custom("BricolageGrotesque-Bold", size: 48)
BFFont.displayLarge = Font.custom("BricolageGrotesque-Bold", size: 56)

// Title — Screen headers
BFFont.titleXL = Font.custom("BricolageGrotesque-SemiBold", size: 32)
BFFont.title1 = Font.custom("BricolageGrotesque-SemiBold", size: 28)
BFFont.title2 = Font.custom("BricolageGrotesque-Medium", size: 22)
BFFont.title3 = Font.custom("BricolageGrotesque-Medium", size: 20)

// Headline — Card titles, section headers
BFFont.headline = Font.system(size: 17, weight: .semibold, design: .default)
BFFont.headlineSmall = Font.system(size: 15, weight: .semibold)

// Body — Content text
BFFont.body = Font.system(size: 17, weight: .regular)
BFFont.bodyMedium = Font.system(size: 17, weight: .medium)
BFFont.bodySmall = Font.system(size: 15, weight: .regular)

// Caption — Labels, metadata, secondary info
BFFont.caption = Font.system(size: 13, weight: .regular)
BFFont.captionMedium = Font.system(size: 13, weight: .medium)
BFFont.captionSmall = Font.system(size: 11, weight: .regular)

// Mono — Codes, account numbers, amounts
BFFont.mono = Font.system(size: 15, weight: .medium, design: .monospaced)
BFFont.monoSmall = Font.system(size: 13, weight: .regular, design: .monospaced)

// Evidence quote — cited text from documents
BFFont.evidence = Font.custom("NewYorkMedium-Regular", size: 15)
BFFont.evidenceLarge = Font.custom("NewYorkMedium-Regular", size: 18)

// Money — Bill amounts, savings
BFFont.money = Font.custom("NewYorkLarge-Bold", size: 36)
BFFont.moneySmall = Font.custom("NewYorkMedium-SemiBold", size: 22)
```

### Dynamic Type Support
All fonts must support Dynamic Type scaling. Use `.scaledFont()` wrappers where custom fonts are used.

---

## Spacing System

All spacing uses a **4pt base grid**.

```swift
BFSpacing.xxs = 4    // Tight inline
BFSpacing.xs  = 8    // List item padding, icon gap
BFSpacing.sm  = 12   // Small component internal padding
BFSpacing.md  = 16   // Standard card padding, section gap
BFSpacing.lg  = 20   // Large card internal padding
BFSpacing.xl  = 24   // Section spacing
BFSpacing.xxl = 32   // Major section breaks
BFSpacing.xxxl = 48  // Screen top padding, hero sections
BFSpacing.huge = 64  // Full-page hero spacing
```

---

## Corner Radius

```swift
BFRadius.xs  = 6    // Tags, small badges
BFRadius.sm  = 10   // Input fields, small cards
BFRadius.md  = 14   // Standard cards
BFRadius.lg  = 20   // Large cards, sheets, bottom panels
BFRadius.xl  = 28   // Full pills, major containers
BFRadius.full = 9999 // Pills, FABs, circular elements
```

---

## Shadows

```swift
// Subtle — light cards
BFShadow.subtle: y=1, blur=3, opacity=0.06, color=.black

// Card — standard elevated cards
BFShadow.card: y=2, blur=8, opacity=0.08, color=.black
BFShadow.card: y=4, blur=16, opacity=0.05, color=.black (second layer)

// Float — floating elements, FABs
BFShadow.float: y=4, blur=20, opacity=0.15, color=.black
BFShadow.float: y=8, blur=40, opacity=0.08, color=.black (second layer)

// Glow — accent elements (teal glow)
BFShadow.glow: y=0, blur=16, opacity=0.4, color=BFColor.accent

// Gold glow — premium elements
BFShadow.goldGlow: y=0, blur=20, opacity=0.3, color=BFColor.gold
```

---

## Glassmorphism Style

Used on: bottom sheets, modals, overlay cards, premium paywall

```swift
struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(BFGradient.glass)
            .overlay(
                RoundedRectangle(cornerRadius: BFRadius.lg)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: BFRadius.lg))
    }
}
```

---

## Animation System

### Timing Curves

```swift
BFAnimation.quick        = Animation.easeOut(duration: 0.15)
BFAnimation.standard     = Animation.easeInOut(duration: 0.25)
BFAnimation.smooth       = Animation.easeInOut(duration: 0.35)
BFAnimation.slow         = Animation.easeInOut(duration: 0.5)
BFAnimation.springSnappy = Animation.spring(response: 0.3, dampingFraction: 0.7)
BFAnimation.springBounce = Animation.spring(response: 0.4, dampingFraction: 0.6)
BFAnimation.springGentle = Animation.spring(response: 0.5, dampingFraction: 0.8)
```

### Screen Transitions
```swift
// Tab switches: asymmetric slide
// Sheet presentations: standard .sheet with custom detents
// Full-screen covers: vertical slide
// Card expansions: matched geometry effect
// Finding reveals: staggered scale + fade
```

### Micro-Animations (Required List)

| Trigger | Animation | Detail |
|---|---|---|
| Button tap | Scale 0.96 → 1.0 | springSnappy, 0.3s |
| Card appear | Y+20 → 0 + opacity 0→1 | staggered by index × 0.05s |
| Tab switch | Horizontal slide | 0.25s easeInOut |
| Finding card expand | matchedGeometry scale | springGentle |
| Checkbox toggle | Scale pulse + checkmark draw | springSnappy |
| Premium badge | Shimmer gradient animation | 2s loop |
| Amount reveal | Count-up number | 0.8s easeOut |
| Scan processing | Circular progress + pulsing ring | continuous |
| OCR confidence bar | Width animation from 0 | 0.5s easeOut |
| Success state | Checkmark path draw + ring expand | 0.6s |
| Loading skeleton | Shimmer left→right | 1.5s loop |
| Notification badge | Scale bounce | springBounce |
| Sheet drag | Interactive spring tracking | native |
| Pull to refresh | Custom rotating logo | continuous |
| Error shake | Horizontal oscillation | 4 cycles, 0.4s |

### Parallax Effects
- Home screen hero card: subtle parallax on scroll (0.3x scroll ratio)
- Document scanner overlay: guides float slightly with device motion

### Reduce Motion Support
All animations must check `@Environment(\.accessibilityReduceMotion)` and use simple opacity transitions instead.

---

## Haptic System

```swift
// Selection haptics (UIImpactFeedbackGenerator)
BFHaptic.light()      // Tab selection, minor toggles
BFHaptic.medium()     // Button taps, card selections
BFHaptic.heavy()      // Primary actions, submit

// Notification haptics (UINotificationFeedbackGenerator)
BFHaptic.success()    // Analysis complete, case resolved
BFHaptic.warning()    // Finding flagged, deadline approaching
BFHaptic.error()      // Scan failed, upload error

// Selection feedback (UISelectionFeedbackGenerator)
BFHaptic.selection()  // Picker changes, list item highlights

// Custom sequences
BFHaptic.scanComplete():
  // medium → 0.1s delay → success → 0.2s delay → light

BFHaptic.findingRevealed():
  // Series: light × (finding_count) at 0.08s intervals, then medium

BFHaptic.letterGenerated():
  // heavy → 0.15s → success
```

**Haptic Rules:**
- Never fire haptics during animations in progress (wait for completion)
- Never fire haptics on background threads
- All haptics must respect iOS silence switch
- No haptics during tutorial/onboarding overlays

---

## Component Library

### BFButton

```swift
// Variants
BFButton.Style.primary    // Filled, accent color, white text
BFButton.Style.secondary  // Outlined, brand color, brand text
BFButton.Style.ghost      // No border, accent text
BFButton.Style.destructive // Red fill or red ghost
BFButton.Style.premium    // Gold gradient, white text, gold glow shadow

// Sizes
BFButton.Size.small  // Height 36, horizontal padding 16
BFButton.Size.medium // Height 48, horizontal padding 24 (default)
BFButton.Size.large  // Height 56, horizontal padding 32, full width

// States
// .normal, .loading (spinner replaces label), .disabled (0.4 opacity)

// Press behavior
// Scale to 0.96 on press, spring back on release
// Medium haptic on tap

// Loading state
// Label fades, ProgressView appears inline
```

### BFFindingCard

This is the most important component in the app.

```swift
// Structure
// ┌─────────────────────────────────────┐
// │ [Severity Badge]    [Confidence]    │
// │                                     │
// │ Finding Title                       │
// │ Short explanation                   │
// │                                     │
// │ [$Amount]  [vs. $EOBAmount]         │
// │                                     │
// │ ▼ Evidence (expandable)             │
// │   "Bill page 2, line 14"           │
// │   "EOB section 3: $1,734.62"       │
// │                                     │
// │ [Recommended Action Button]         │
// └─────────────────────────────────────┘

// Severity colors
// Strong:      red left border (4pt) + critical surface background
// Likely:      orange left border + warning surface
// Possible:    blue left border + info surface
// Informational: gray left border + neutral surface

// Confidence badge
// High:   solid teal pill
// Medium: outlined amber pill
// Low:    gray outlined pill

// Evidence section
// Collapsed by default
// Tap to expand with spring animation
// Evidence text uses BFFont.evidence (New York serif)
// Document preview thumbnail if image available

// Animations
// Card slides in from bottom (Y+30 → 0) with stagger
// Evidence expands with matchedGeometry
// Amount displays count-up animation
```

### BFCaseCard

```swift
// Structure
// ┌─────────────────────────────────────┐
// │ Provider name           [Status]   │
// │ Service type · Date                │
// │                                     │
// │ Original: $3,480  →  Current: $X  │
// │ [Progress bar if in negotiation]    │
// │                                     │
// │ [Findings: 4]  [⏰ Deadline: 3d]   │
// └─────────────────────────────────────┘

// Status badge colors
// Active:           blue
// Awaiting Response: amber
// Resolved:         green
// Closed:           gray

// Savings display
// If savings > 0: bright green amount with up-arrow icon
// Animated progress bar showing progress to resolution
```

### BFDocumentThumbnail

```swift
// Shows page preview with overlay
// Processing state: skeleton shimmer
// Ready state: image + page number badge
// Low-confidence OCR: amber overlay warning
// Tap: full-screen preview with OCR overlay
```

### BFMoneyDisplay

```swift
// Large amount display with count-up animation
// Dollar sign in smaller weight, amount in BFFont.money
// Positive/negative delta with colored arrow
// Blur reveal animation for subscription paywall
```

### BFProgressStepper

```swift
// Horizontal step indicator for capture flow
// Steps: Bill → EOB → Review → Analysis
// Active step: filled circle + active color
// Completed step: checkmark circle + teal
// Upcoming: outlined circle + gray
// Connecting line animates fill on progress
```

### BFStatusBadge

```swift
// Pill shaped, various colors
// Has optional icon prefix
// Sizes: compact (11pt), standard (13pt)
// With pulse animation for "Processing" state
```

### BFEmptyState

```swift
// Centered illustration + title + subtitle + CTA button
// Illustrations: custom SF Symbol compositions
// Gentle float animation on illustration
// Used for: empty case list, no findings, no documents
```

### BFGlassCard

```swift
// Glassmorphism container
// Used in: bottom sheets, modals, premium paywall overlay
// ultraThinMaterial + gradient overlay + border stroke
```

### BFSectionHeader

```swift
// Section title (left) + optional action link (right)
// Title: BFFont.headline, textSecondary color
// All caps, letter-spacing 0.5
```

---

## Tab Bar Design

**5 Tabs:**

```
[🏠 Home]  [📋 Cases]  [📄 Scan]  [💬 Scripts]  [⚙️ Settings]
```

Design:
- Center tab (Scan) is elevated: floating circular button, teal fill, camera icon, white
- Center tab has subtle upward shadow/glow
- Active tabs: teal icon + teal label (11pt, medium)
- Inactive tabs: gray icon + gray label
- Tab bar: ultra-thin material blur background
- Top border: 0.5pt separator
- Badge on Cases tab for unresolved findings count

---

## Navigation Design

### Large Titles
- Home, Cases, Settings screens use `.navigationBarTitleDisplayMode(.large)`
- Large title: BFFont.titleXL

### Top Navigation Style
- Transparent on hero screens
- White/material on content screens
- Back button uses custom chevron, teal color

### Bottom Sheets
- Custom `.presentationDetents([.medium, .large])`
- `.presentationDragIndicator(.visible)`
- Glass card background
- Handle: rounded pill, 4pt × 36pt

---

## Screen-Specific Design Details

### Home Screen (Dashboard)
**Background:** hero gradient (brand → brandLight → accent) on top 40% of screen
**Layout:**
1. Greeting + date (top, white text on gradient)
2. **Active Cases** horizontal scroll — glass cards with frosted appearance
3. **Quick Stats** row: Total Saved, Bills Analyzed, Active Cases
4. **Start New Scan** — large teal CTA card with camera illustration
5. **Recent Findings** — vertical list of recent finding cards
6. **Tips** — rotating contextual tips card

**Animations:**
- Stats count up on appear
- Cards stagger in from bottom
- Greeting fades in with slight upward slide

---

### Scan Screen (Bill Capture)
**Layout:**
- Full-screen camera viewfinder
- Translucent top bar with close + flash + batch indicator
- Animated scanning guide overlay (corner brackets animate)
- Bottom panel (glass): page thumbnails + capture button + import button
- Capture button: large circle (80pt), white border, white center
- Shutter animation: screen flash + haptic

**Viewfinder Overlay:**
- Corner bracket guides pulse subtly
- "Position bill within frame" text fades out after 3s
- Edge detection highlight (green rectangle) when bill detected

---

### Analysis Loading Screen
**Background:** gradient (brand → brandMuted)
**Elements:**
- Bill Fixer logo (animated, subtle pulse)
- Step-by-step progress with animated checkmarks:
  - ✓ Reading your bill...
  - ✓ Checking the math...
  - ✓ Comparing with your EOB...
  - ✓ Looking up hospital prices...
  - ✓ Checking your rights...
  - ✓ Assembling your findings...
- Subtle animated particle background (floating dots, very low opacity)
- Duration: real processing time + minimum 2.5s for visual satisfaction

---

### Findings Screen
**Header:**
- Case name + status badge
- Summary: "We found 4 things worth checking"
- Potential savings range (blurred if free tier)

**Finding Cards:**
- Sorted: Strong → Likely → Possible → Informational
- Staggered card reveal animation
- Swipe right: "Not an issue" dismiss
- Swipe left: "Generate letter" shortcut

**Recommended First Action:**
- Pinned at top in a gold-bordered card
- Clear action title + explanation
- Primary CTA button

---

### Letter Screen
**Layout:**
- Preview of generated letter (scrollable, serif font)
- Toolbar: Edit / Copy / Share / Export PDF
- Disclaimer at bottom
- User can tap any paragraph to edit

---

### Paywall Screen
**Background:** dark navy gradient with subtle particle animation
**Layout:**
1. Gold "BILL FIXER PREMIUM" badge (shimmer animation)
2. Headline: "Take back control of your medical bills"
3. Feature list with animated checkmarks appearing sequentially
4. Pricing toggle: Monthly ↔ Annual (annual shows savings %)
5. Primary CTA: "Start Premium" (gold gradient button, gold glow)
6. "Restore Purchase" + Privacy/Terms links
7. Money-back satisfaction note

**Feature list icons:** Custom SF Symbol compositions with teal fill

---

## Image Generation Specifications

For Claude/AI image generation to include in the UI:

### App Icon
- Style: Clean, modern, minimal
- Background: deep navy blue (#0F2B5B) to teal (#00B4A0) gradient
- Symbol: Stylized "B" or bill/document with a checkmark or shield
- Feel: trustworthy, medical-adjacent, premium
- Sizes: all required App Store sizes

### Onboarding Illustrations (3 screens)
1. **"See the full picture"** — Abstract bill document with magnifying glass, evidence highlights glowing in teal
2. **"Evidence, not guesses"** — Document with highlighted lines connecting to proof sources
3. **"Your action plan"** — Clean steps: letter icon → phone icon → checkmark → savings counter

Style: Flat 2.5D illustration, brand colors, clean linework, subtle shadows

### Home Screen Hero Images
- Abstract medical bill with teal highlights
- Hospital building simplified icon set
- Bill analysis visualization (document + numbers flowing)

### Empty State Illustrations
- "No cases yet" — Friendly folder with sparkle
- "No findings" — Green checkmark shield
- "Scan your first bill" — Camera + document animation

### Finding Card Icons
Each finding type gets a distinct icon:
- Duplicate charge: two overlapping document pages
- EOB mismatch: two scales (bill vs. EOB)
- Price discrepancy: price tag with question mark
- Math error: calculator with X
- Financial assistance: helping hand + shield
- Rights/NSA: gavel + shield
- GFE dispute: stopwatch + document
- Informational: info circle in soft blue

---

## Dark Mode

All colors have dark mode counterparts defined.
Surfaces invert (dark backgrounds, light cards).
Hero gradient adjusts: darker base, maintains contrast.
Glass effects remain but with dark material.
All semantic colors maintain WCAG AA contrast in dark mode.

---

## Accessibility Requirements

- Minimum contrast ratio: 4.5:1 (WCAG AA) for all text
- Large text mode: all layouts reflow correctly
- VoiceOver: all interactive elements labeled
- Reduce Motion: all animations replaced with opacity cross-fades
- Color blind: findings never rely on color alone — always include icon + label
- Minimum touch target: 44×44pt
- Focus order: logical top-to-bottom, left-to-right

---

## SF Symbols Used

```
document.text.magnifyingglass  — Bill analysis
checkmark.shield.fill          — Verified finding
exclamationmark.triangle.fill  — Critical finding
questionmark.circle            — Possible issue
info.circle                    — Informational
dollarsign.circle              — Money/savings
calendar.badge.clock           — Deadline
paperplane.fill                — Send letter
phone.fill                     — Phone script
folder.fill.badge.plus         — New case
chart.bar.doc.horizontal       — EOB
building.2                     — Hospital
person.crop.circle.badge.plus  — Financial assistance
lock.shield                    — Privacy
star.fill                      — Premium
arrow.down.doc                 — Import
camera.fill                    — Scan
checkmark.circle.fill          — Resolved
xmark.circle                   — Denied/closed
clock.badge.exclamationmark    — Urgent deadline
```

---
---

# PART II — V2 SCENIC SYSTEM

> Added Sep 28, 2026. Everything above still holds — tokens, semantic colors, spacing,
> haptics, components. This part adds the three layers that were missing:
> **a per-screen background registry, a per-screen typographic persona, and a vector asset library.**
>
> Reference implementation: `docs/Claude outputs/v2/BillFixer-Screens.html` (24 screens, all inline SVG).

---

## The Scenic Rule

Every screen gets **its own full-bleed background**. No wallpaper is ever reused.

This is not decoration. A background is a **wayfinding signal**: the user should know
which part of the app they're in before they read a single word. Capture is dark and
technical. Documents are paper. Analysis is deep space. Money is warm. Rights are engraved.

**Constraints that make it safe:**

| Rule | Value |
|---|---|
| Format | Inline SVG only — no raster, no external image requests |
| Size budget | ≤ 8 KB of markup per background |
| Text contrast | Content sits on a surface (card / glass / scrim), never raw on the scene |
| Legibility gate | Every background must pass 4.5:1 for all text layered over it |
| Motion | ≤ 3 animated elements per background, all `transform`/`opacity` only |
| Reduced motion | `@media (prefers-reduced-motion: reduce)` kills all background animation |
| Dark mode | Light scenes get a dark counterpart; dark scenes deepen, never invert |

**Anatomy — every background is exactly three layers:**

```
┌─ Layer 3: ACCENT     drifting blobs, particles, confetti, glints   (animated)
├─ Layer 2: STRUCTURE  contours, grid, waves, rays, skyline, strata  (static/slow)
└─ Layer 1: FIELD      the base CSS gradient on the container         (static)
```

---

## Background Registry

24 scenes. Each row is a contract: the screen, the scene name, its base gradient,
its structure motif, and its animation signature.

| # | Screen | Scene | Field (base gradient) | Structure | Motion |
|---|---|---|---|---|---|
| 01 | Splash | **Aurora Orbit** | `#081A38 → #0F2B5B → #144A76 → #00806F` 158° | Two counter-rotating orbit ellipses + starfield | `spin 26s` / `spin-r 34s` / `twinkle` |
| 02 | Onboarding 1 | **Topographic Mint** | `#EAFBF7 → #F4FBFA → #FFFDF7` 172° | Contour lines (teal upper, navy lower) | `drift 17s` / `pulse` |
| 03 | Onboarding 2 | **Gold Constellation** | `#FFFBF0 → #FEF6E4 → #F6F9FF` 196° | Node-and-edge constellation, two clusters | `pulse` staggered / `spin` dashed ring |
| 04 | Onboarding 3 | **Ray Burst Lilac** | `#F3F0FF → #EDF6FB → #E9FBF6` 200° | Radial rays from top + dual wave bands | `spin 26s` / `drift` |
| 05 | Sign In | **Dusk Skyline** | `#0B1B3A → #2B3D77 → #6B5490` 178° | Hospital skyline silhouette + lit windows | `twinkle` / `breathe` moon |
| 06 | Home | **Daylight Mesh** | `#0F2B5B → #1E6E86 → #EAF3F8 → #F5F6FA` 184° | Mesh radials + 26px grid below fold + wave cap | `breathe` / `drift` ×2 |
| 07 | Capture Sheet | **Scrim Bokeh** | `#0C1F42 → #1B5E70 → #243046` 170° | Gaussian-blurred shapes of the screen beneath | `drift 17s` ×2 |
| 08 | Camera | **Viewfinder Grain** | radial `#2A3040 → #05070B` | Turbulence grain + document + edge vignette | `sweep 3.2s` scan line / `bracket pulse` |
| 09 | Doc Review | **Ivory Paper Stock** | `#FBF8F1 → #F6F2E8 → #F2F4F6` 168° | Fibre turbulence + 32px ruling + red margin | `drift` ink bloom |
| 10 | OCR Edit | **Blueprint Grid** | `#EFF4FB → #F3F6FB → #FAFBFD` 176° | 20px minor / 100px major grid + dimension ticks | `drift` ×2 |
| 11 | Analysis | **Deep Orbit Navy** | `#050D1F → #123063 → #0E3C54` 168° | Orbit ring + ellipse + wave floor | `rise 7–10s` particles / `spin` |
| 12 | Results | **Radiant Burst** | `#F0FDFA → #F7F8FC → #FFFDF6` 178° | Radial rays from donut centre + confetti | `spin` / `float-s` confetti |
| 13 | Findings | **Severity Strata** | navy → crimson → amber → blue bands 180° | Horizontal strata keyed to severity tiers | `drift` ×2 |
| 14 | Finding Detail | **Crimson Dawn Hatch** | `#FFF1F1 → #FAF7F5 → #F6F7FA` 174° | 45° caution hatch + concentric alert rings | `pulse` rings / `drift` |
| 15 | Letter | **Linen & Seal** | `#F7F4EC → #F2EEE3 → #EEF1F4` 170° | Linen weave + embossed seal watermark | `spin 26s` seal |
| 16 | Phone Script | **Waveform Indigo** | `#141335 → #232B6B → #0E2436` 172° | 19-bar audio waveform, split left/right | `pulse` staggered 50ms |
| 17 | Cases | **Isometric Slate** | `#EEF2F8 → #F8F9FC → #EFF4F6` 182° | Isometric folder cubes + horizon rules | `drift` |
| 18 | Timeline | **Spine Glow** | navy → `#F6F8FC → #F2F7F6` 180° | Vertical glow behind the rail + column guides | `drift` ×2 |
| 19 | Rights | **Guilloché Engraving** | `#07322F → #0F3F62 → #F7FAFA` 176° | Six rotated ellipses (banknote engraving) | `spin 26s` |
| 20 | Assistance | **Sunrise Ladder** | `#FFF3E4 → #FDF3EC → #F4F8F8` 176° | Ascending step bars + sun + wave bands | `breathe` sun / `pulse` |
| 21 | Paywall | **Obsidian Gold Dust** | `#0A0D14 → #231B1A → #16141C` 168° | Gold orbit ring + rising dust + star field | `rise 9–13s` / `spin` / `shimmer 2.6s` |
| 22 | Settings | **Graphite Rings** | `#E8ECF3 → #F6F7FA → #EDF1F4` 180° | Two concentric ring systems + section rules | `drift` |
| 23 | Empty State | **Cloud Drift Sky** | `#DCEEFB → #F4FAFB → #FBFCFD` 184° | Layered cloud puff clusters, 2 depths | `drift 17s` ×5 |
| 24 | Success | **Emerald Aurora** | `#04291C → #0E6B52 → #0B5F63` 166° | Dashed orbit + halo rings + wave floor | `breathe` / `float-s` confetti / `spin` |

---

## Typographic Personas

The app ships **14 families**. That is deliberate — each screen has a *voice*, and the
typeface is how the voice is heard. What keeps it coherent: one shared type scale, one
shared spacing grid, and `Inter`/`DM Sans` carrying body copy almost everywhere.

```swift
// Token names map 1:1 to the CSS custom properties in the reference HTML
BFFont.Family.brand  = "Bricolage Grotesque"   // --f-brand
BFFont.Family.dash   = "Sora"                  // --f-dash
BFFont.Family.onb    = "Outfit"                // --f-onb
BFFont.Family.case_  = "Manrope"               // --f-case
BFFont.Family.tech   = "Space Grotesk"         // --f-tech
BFFont.Family.act    = "Archivo"               // --f-act
BFFont.Family.lux    = "Fraunces"              // --f-lux
BFFont.Family.warm   = "Calistoga"             // --f-warm
BFFont.Family.edit   = "Playfair Display"      // --f-edit
BFFont.Family.doc    = "Libre Baskerville"     // --f-doc
BFFont.Family.read   = "Source Serif 4"        // --f-read
BFFont.Family.legal  = "Newsreader"            // --f-legal
BFFont.Family.ui     = "Inter"                 // --f-ui    (body default)
BFFont.Family.mono   = "JetBrains Mono"        // --f-mono  (all numerics)
```

| Screen | Display face | Body face | Why this voice |
|---|---|---|---|
| Splash, Sign In, Analysis | Bricolage Grotesque | Inter | The brand itself — confident, a little idiosyncratic |
| Onboarding 1 | Outfit | DM Sans | Open, geometric, unintimidating on first contact |
| Onboarding 2 | Fraunces | DM Sans | Editorial authority — this is the "we cite sources" page |
| Onboarding 3, Home, Results | Sora | Inter | Product voice: precise, modern, data-forward |
| Capture, Cases, Timeline, Settings, Empty | Manrope | Inter | Workhorse UI — dense lists stay readable |
| Camera, OCR Edit | Space Grotesk | Inter | Technical register; pairs with mono numerics |
| Doc Review | Source Serif 4 | Inter | You are looking at a document, so it reads like one |
| Findings, Finding Detail, Script | Archivo | Inter | Assertive without shouting — this is the verdict |
| Letter | Libre Baskerville | Playfair (signature) | It must *look* like correspondence, because it is |
| Rights | Newsreader | Inter | Legal-adjacent gravity without courtroom coldness |
| Assistance, Empty, Success | Calistoga | Inter | Warmth exactly where the user is most vulnerable |
| Paywall | Fraunces | Inter | Premium, editorial, worth paying for |

**Non-negotiables regardless of persona:**

- All money, codes, dates, counts, IDs → `JetBrains Mono` with `font-variant-numeric: tabular-nums`.
- Body copy never below 15pt; line-height 1.55–1.65.
- Every custom face ships a `.scaledFont()` wrapper for Dynamic Type.
- Max **two** families visible on any one screen (mono doesn't count).

---

## Vector Asset Library

All artwork is **inline SVG**. No PNGs, no external requests, no asset catalog images
except the App Icon. Illustrations theme automatically, scale infinitely, and animate.

### Illustration set

| Asset | Used on | Composition |
|---|---|---|
| **Logo mark** | 01, 05, 11 | Rounded-square glass tile → document → folded corner → teal check disc with `draw` animation |
| **Bill + magnifier** | 02 | Stacked documents, teal/amber highlight rows, floating lens with inner check |
| **Evidence wiring** | 03 | Source doc with three dashed bezier paths → EOB / MRF / MATH source tiles |
| **Action trio** | 04 | Envelope → phone → check → savings counter card, dashed connectors |
| **Skyline** | 05 | 7 building silhouettes, one hospital with cross sign, lit window grid |
| **Folder + sparkle** | 23 | Isometric folder, tilted document, two 4-point sparkles |
| **Helping hand** | 20 | Hand + heart form, sun disc, green approval tick |
| **Shield + check** | 19, 24 | Heraldic shield, drawn checkmark, expanding halo rings |

### Finding-type icons (28×28 stroke, 1.9pt)

| Finding | Icon |
|---|---|
| Duplicate charge | Two offset document rects, second filled `criticalSurface` |
| EOB mismatch | Balance scale, pans at unequal heights |
| Price discrepancy | Price tag with question mark |
| Math error | Calculator grid with an × in the display |
| Financial assistance | Hand cradling a heart |
| Rights / NSA | Shield with inner checkmark |
| GFE dispute | Stopwatch overlapping a document |
| Informational | Circle with `i`, `info` blue |

### Micro-vectors

Status bar (signal bars + battery, one 46×11 SVG), capture brackets, progress donut
(`stroke-dasharray` 465), tab bar glyphs, timeline node tiles, waveform bars, confetti
(rects rotated 18–48°, circles r 3–5).

---

## Motion System — V2 additions

Part I's timing curves and micro-animation table still govern interaction. These are the
**ambient** keyframes that live in the background layer and run continuously.

| Keyframe | Duration | Easing | Purpose |
|---|---|---|---|
| `float` | 6s | ease-in-out ∞ | Hero illustrations — 13px vertical |
| `float-s` | 4.5s | ease-in-out ∞ | Secondary props, confetti — 7px |
| `drift` | 17s | ease-in-out ∞ | Background blobs — 3-point wander |
| `spin` / `spin-r` | 26s / 34s | linear ∞ | Orbit rings, seals, guilloché |
| `pulse` | 3.6s | ease-in-out ∞ | Capture brackets, waveform bars, nodes |
| `breathe` | 5s | ease-in-out ∞ | Aurora / sun opacity 0.2→0.62 |
| `rise` | 7–13s | linear ∞ | Particles ascending 190px, fade in/out |
| `shimmer` | 2.6s | linear ∞ | Premium badge, gold CTA sheen |
| `sweep` | 3.2s | ease-in-out ∞ | Camera scan line, top → bottom |
| `dash` (`.draw`) | 0.9–1.5s | ease-out once | Checkmark and connector path draw |
| `twinkle` | 3.4s | ease-in-out ∞ | Starfields, staggered 0.3–2.1s |
| `tick` | 2.4s | ease-in-out ∞ | Notification badge scale 1→1.13 |
| `slidein` (`.stagger`) | 0.55s | `cubic-bezier(.22,1,.36,1)` | Card entrance, +70ms per index |

**Stagger contract:** list and card entrances step 50–70ms per item, capped at 8 items —
past that the last item feels late rather than choreographed.

**Reduced motion:** a single global rule zeroes every animation and transition. Layout,
contrast, and information are identical with motion off; nothing is animation-dependent.

---

## Layered Surface Rules

Because scenes are busy, content needs a defined home. Three surface treatments only:

```swift
// 1. Solid card — light scenes, all dense content
.card       → surface white, radius 20, sh-card, border rgba(231,235,242,.8)

// 2. Light glass — over hero gradients (Home stats, onboarding chrome)
.glass      → rgba(255,255,255,.14) + blur(22px) saturate(160%) + white 26% border

// 3. Dark glass — over dark scenes (Sign In, Script, Paywall, Success)
.glass-d    → rgba(9,16,32,.44) + blur(24px) saturate(150%) + white 12% border
```

**Never** place body text directly on a background scene. Titles and captions may sit on
a scene only where the underlying region is a flat gradient with no structure layer, and
only when measured contrast clears 4.5:1 against the darkest and lightest pixel in that region.
