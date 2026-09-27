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
