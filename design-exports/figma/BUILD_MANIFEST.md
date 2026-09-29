# BillFixer — Figma Build Manifest

> Execution spec for the native Figma build. Source of truth: the 24-screen reference board.
> Rule for this build: **match the board exactly.** Where the board is ambiguous, the docs in
> `docs/ux/` decide. Nothing is reinterpreted.

---

## 0. Status

| | |
|---|---|
| Target | Native Figma file, real frames + components + styles |
| Blocker | `design:figma` connector is configured but **not authorized**; this session is non-interactive so the OAuth flow cannot run here |
| Unblocks when | Connector authorized, then a session started with it live |
| Fidelity | Pixel-match the board (24) + 8 new screens in identical style |
| Total frames | **32** |

---

## 1. File structure

```
Bill Fixer — iOS
├─ Page: 01 Cover
├─ Page: 02 Foundations        color / type / effect / grid styles
├─ Page: 03 Components         published component set
├─ Page: 04 Illustrations      vector library, components
├─ Page: 05 Screens — Board    32 frames, 8-across, matching board order
└─ Page: 06 Flows              FigJam-style connectors over frame thumbnails
```

Frame size **390 × 844** (iPhone 15/16 logical). Board grid: 8 columns, 80px gutter,
160px row gap, caption text 14/600 centered 24px under each frame.

---

## 2. Foundations

### Color styles

| Style | Hex | Used for |
|---|---|---|
| `brand/navy` | `#0B2B5C` | primary buttons, headings, splash base |
| `brand/navy-2` | `#123A7A` | gradient stop |
| `brand/blue` | `#2E7DF6` | links, active tab, accents |
| `brand/blue-soft` | `#E8F1FE` | icon tiles, selected chips |
| `brand/teal` | `#00BFA5` | success accents, logo check |
| `brand/teal-soft` | `#E2F9F5` | surfaces |
| `semantic/green` | `#22C07A` | completed, resolved |
| `semantic/amber` | `#F5A623` | low confidence, free-plan banner |
| `semantic/amber-soft` | `#FFF5E2` | banner fill |
| `semantic/red` | `#EF4444` | strong finding, delete |
| `semantic/red-soft` | `#FEF0F0` | finding card fill |
| `text/1` | `#14213D` | headings |
| `text/2` | `#4A5A75` | body |
| `text/3` | `#8492AB` | meta |
| `surface/white` | `#FFFFFF` | cards |
| `surface/bg` | `#F7F9FD` | screen background |
| `surface/line` | `#E9EEF6` | dividers, card borders |
| `dark/bg` | `#0D1117` | dark-mode screens 22, 17 |

Gradients as styles: `grad/navy` 158°, `grad/blue`, `grad/teal`, `grad/amber`, `grad/sky`.

### Text styles

| Style | Font | Size / weight / LH |
|---|---|---|
| `display/xl` | Figtree | 45 / 900 / 100% |
| `title/1` | Outfit | 35 / 700 / 110% |
| `title/2` | Plus Jakarta Sans | 22 / 800 / 120% |
| `title/3` | Plus Jakarta Sans | 17 / 700 / 130% |
| `body/lg` | DM Sans | 16.5 / 400 / 162% |
| `body/md` | Plus Jakarta Sans | 15 / 400 / 150% |
| `body/sm` | Plus Jakarta Sans | 13 / 400 / 150% |
| `label/md` | Plus Jakarta Sans | 12 / 700 / 130% |
| `label/sm` | Plus Jakarta Sans | 11 / 700 / 130% |
| `mono/md` | JetBrains Mono | 15 / 500 / tabular |
| `mono/sm` | JetBrains Mono | 11 / 500 / .12em tracking |
| `serif/doc` | Lora | 13 / 400 / 178% — letter body only |

### Effect styles

`sh/sm` 0 1 3 rgba(16,35,70,.05) · `sh/card` 0 3 10 .06 + 0 10 30 .05 ·
`sh/float` 0 6 20 .10 + 0 16 48 .08 · `sh/btn-navy` 0 5 14 rgba(11,43,92,.30)

### Corner radius scale
12 / 18 / 24 / 32 / 999

---

## 3. Components

| Component | Variants |
|---|---|
| `Button` | style = navy · blue · teal · amber · outline · ghost / size = md 48 · lg 56 / state = default · pressed · loading · disabled |
| `StatusBar` | theme = light · dark |
| `HomeBar` | theme = light · dark |
| `TabBar` | active = home · cases · scan · learn · settings |
| `Card/Case` | status = analysis-complete · letter-sent · in-review · resolved · closed |
| `Card/Finding` | severity = strong · likely · possible · info / expanded = true · false |
| `Card/Action` | icon slot + title + subtitle + chevron |
| `ListRow/Setting` | type = nav · toggle · value · destructive |
| `Pill` | tone = blue · teal · green · amber · red · neutral / size = sm · md |
| `FieldRow` | confidence = high · low (low adds amber rail + badge) |
| `Stepper` | steps = 3 · 4 / active index |
| `PageDots` | count = 3 / active index |
| `Donut` | value, segment colors, center number + label |
| `Thumbnail/Page` | state = selected · default · empty |
| `TimelineRow` | kind = upload · analysis · letter · sent · response · balance |
| `Avatar` | type = photo · initial |

All built with auto-layout. Text and icon slots exposed as properties.

---

## 4. Illustration library

Drawn as vector components, reused across frames.

| Component | Appears on |
|---|---|
| `il/logo-mark` | 01, 05, 11 |
| `il/girl-phone` | 02 |
| `il/girl-point` | 07, 11 |
| `il/doc-stack` | 03, 09 |
| `il/magnifier` | 03 |
| `il/icon-cluster` | 04 |
| `il/hospital-scene` | 05 |
| `il/folder-empty` | 23 |
| `il/check-burst` | 18 |
| `il/crown` | 17 |
| `badge/camera`·`coin`·`warn`·`mail`·`doc`·`phone`·`check`·`shield` | 02–04, 07 |
| `deco/cloud`·`tree`·`plant`·`sparkle` | 02–05, 23 |

---

## 5. Frame inventory — board screens (1–24)

Order and content match the reference board left→right, top→bottom.

| # | Frame | Key content locked from the board |
|---|---|---|
| 01 | Splash Screen | Navy gradient + white wave. Logo tile. `BillFixer` / `Your medical bill, decoded.` Bottom: `Find errors. / Know your rights. / Take action.` 3 dots, first active |
| 02 | Onboarding 1 | Girl-with-phone illustration + 4 floating badges. `Scan your medical bill` / `Upload a photo, PDF or take a quick scan. We'll extract the details for you.` `Next →`, dots 1/3 |
| 03 | Onboarding 2 | Doc stack + magnifier + coin + warn badges. `We find potential issues` / `We check the math, find duplicate charges, compare with your EOB, and look up your hospital's published prices.` `Next →`, dots 2/3 |
| 04 | Onboarding 3 | Icon cluster (list, coin, mail, pin). `Get a plan and take action` / `Receive clear explanations, ready-to-send letters, and phone scripts. Track your progress in one place.` `Get Started`, dots 3/3 |
| 05 | Sign In | Logo, `BillFixer`, `Your medical bill, decoded.`, hospital scene. `Continue with Apple` (black), `Continue with Email` (outline). Terms + Privacy line |
| 06 | Home (Dashboard) | Avatar + `Good morning, Alex` + bell. Amber `Free Plan — 1 of 1 finding preview used`. Navy card `Scan a Medical Bill / Photo, PDF or Camera` + `＋`. Row: `Scan Bill` `Add EOB` `Import PDF`. `Your Cases` / `See All`. Case row: Riverside Medical Center · Mar 15, 2024 · `Analysis Complete` · `$2,845`. Tab bar: Home Cases Scan Learn Settings |
| 07 | Capture Options | Sheet. `Add Your Document` / `Upload your medical bill or EOB`, ✕. Rows: `Take a Photo / Scan with your camera`, `Import from Photos / Choose existing photos`, `Import PDF / From Files, Mail or other apps`. Blue card `What should I upload?` + girl illustration |
| 08 | Camera Scan | Dark. ✕, flash, info. Document in corner brackets. `SINGLE` / `MULTI` toggle. Thumbnail, shutter, `Done (4)` |
| 09 | Document Review | `Review Your Document` / `Page 1 of 4`. Scan preview. 4 page thumbnails, 1 selected. `Case 2176` badge. `Continue` |
| 10 | OCR Review / Edit | `Extracted Information`. Provider `Riverside Medical Center`, Date of Service `Mar 15, 2024`, Total Amount `$2,845.00` + `Low confidence`, Patient Responsibility `$1,234.56`. `Line Items (12)`: `99284 Emergency Dept Visit $850.00`, `71046 Chest X-Ray $420.00`, `93000 EKG $210.00`. `＋ Add Line Item`. `Continue to Analysis` |
| 11 | Analysis Progress | `Analyzing Your Bill`. Steps: Extracting text ✓ Completed · Checking bill arithmetic ✓ Completed · Finding duplicate charges ◉ In progress… · Comparing with your EOB · Looking up hospital prices · Checking your rights · Generating results. Card: `This usually takes 30–60 seconds. We'll notify you when it's done.` + girl |
| 12 | Results Overview | `Analysis Complete`. Donut `5 / Findings`. Chips `2 Strong` `1 Likely` `1 Possible` `1 Info`. Amber card `You may be overcharged $892 / Based on our analysis`. `View Findings →`. `Or jump to an action`: Generate Letter · Phone Script · View Rights |
| 13 | Finding Detail | `Strong Finding` red pill. `Duplicate Charge Detected` / `$420.00`. `This charge appears 2 times on your bill for the same service and date.` Evidence: `Line Item 3 / 71046 — Chest X-Ray / Mar 15, 2024 / $420.00`, `Line Item 7` same. `Why this matters — You may be charged twice for the same service. This is a common billing error.` `Generate Dispute Letter`, `Mark as Resolved` |
| 14 | Letter Generation | `Dispute Letter`. Stepper `1 Template` `2 Review` `3 Send`. `EOB Mismatch Dispute Letter / Pre-filled with your details`. Letter body from `March 20, 2024` through `Please review the attached EOB and…`. `Copy to Clipboard`, `Share` |
| 15 | Case Management | Avatar + `My Cases` + blue `＋`. Tabs `Active (3)` `Resolved (1)` `Closed (1)`. Rows: Riverside Medical Center · Mar 15, 2024 · `Analysis Complete` · 3 findings · `$2,845`; St. Mary's Hospital · Feb 2, 2024 · `Letter Sent` · 2 findings · `$1,420`; City Health Clinic · Jan 10, 2024 · `In Review` · 1 finding · `$320`. Tab bar, Cases active |
| 16 | Go Premium | Dark navy. Crown. `Go Premium` / `Unlock your full bill analysis and take control.` Checklist: Unlimited bill & EOB scans · Hospital price comparisons · Full analysis with all findings · All letter templates & phone scripts · Unlimited active cases · Deadline reminders. `Monthly $7.99/month` vs `Annual $59.99/year` + `Save 37%`. `Continue with Annual`. ✕ |
| 17 | You're All Set! | Green check burst. `You're All Set!` / `Welcome to BillFixer Premium`. Ticks: Your subscription is active · All features unlocked · Start scanning your first bill. `Start Scanning` |
| 18 | Case Timeline | `Case Timeline`. Rows: Bill uploaded `Mar 15, 2024 · 10:24 AM` · Analysis complete `10:25 AM` · Dispute letter generated `Mar 16 · 9:12 AM` · Letter sent `Mar 16 · 9:15 AM` · Provider response `Mar 22 · 2:41 PM` · Balance reduced `Mar 28 · 11:20 AM` |
| 19 | Your Rights May Apply | `Your Rights May Apply`. Cards: `No Surprises Act — Out-of-network charges may be protected under federal law.` · `Financial Assistance — You may qualify based on your income and hospital type.` · `Request an Itemized Bill — You have the right to request a detailed, itemized bill.` · `Compare with Your EOB — Your bill should match your EOB patient responsibility.` |
| 20 | Settings | `Settings` + search. Alex Johnson / alex@example.com. Rows: Account · Subscription `Premium (Annual)` · Notifications · Help & Support · Privacy Policy · Terms of Service · `Delete Account` in red |
| 21 | Results Overview — Dark | Frame 12 on `dark/bg`, same content, surfaces inverted |
| 22 | No Cases Yet | Folder illustration. `No Cases Yet` / `Scan your first medical bill to get started. We'll check for errors, compare prices, and help you take action.` `Scan Your First Bill`. Tab bar |
| 23 | Home — Dark | Frame 06 on `dark/bg` |
| 24 | Case Management — Dark | Frame 15 on `dark/bg` |

---

## 6. Frame inventory — new screens (25–32)

Same visual language, drawn from `docs/ux/SCREENS.md` and `UX_FLOWS.md`.

| # | Frame | Purpose |
|---|---|---|
| 25 | Findings List | All 5 findings sorted Strong → Info. Free tier blurs 2+ behind an unlock overlay. Board shows only the detail view |
| 26 | Phone Script | Call card, opening statement, `What did they say?` branch list A–D. Flow 5 |
| 27 | Financial Assistance | FPL estimator — household size stepper, income slider, eligibility result, document checklist. Flow 6 |
| 28 | Rights Detail — No Surprises Act | Expanded rights card: what it covers, whether it applies here, cited source, generate-letter CTA |
| 29 | Case Detail — Summary | Header card + segmented Summary / Documents / Findings / Letters / Timeline. Board only shows Timeline |
| 30 | Scripts Tab | Library of call scripts by situation. Tab 4 has no board frame |
| 31 | EOB Prompt | `Do you have an EOB?` — Yes → EOB capture · Skip → reduced-confidence analysis. Decision point in Flow 2 |
| 32 | Notification Permission | Pre-permission screen for deadline + follow-up reminders, before the system dialog |

---

## 7. Build order

1. Foundations page — color, text, effect styles
2. Illustration components
3. UI components with auto-layout + variants
4. Frames 01–05, review checkpoint
5. Frames 06–15
6. Frames 16–24
7. Frames 25–32
8. Flows page with connectors
9. Cover

---

## 8. To unblock

The Figma connector must be authorized before any of this can be written:

- **claude.ai connectors** — enable the Figma connector in connector settings
- **local MCP** — run `/mcp` inside an interactive `claude` terminal, or `claude mcp` to authorize `design:figma`

Once authorized, start a session where the connector is live and point me at this file.
