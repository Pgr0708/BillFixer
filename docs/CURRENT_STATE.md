# BillFixer — Current State

> DELETE BEFORE SUBMISSION. Updated manually as work progresses.

---

## As of: 2026-09-27

---

## What Exists

### iOS Project
- [x] Xcode project created (`BillFixer.xcodeproj`)
- [x] Basic app structure ported from MileageTax base
- [x] `BillFixerApp.swift` — AppDelegate, SplashScreenView, CoreData (placeholder), SettingsManager
- [x] `AppInfo.swift` — app name, bundle ID set to BillFixer
- [x] `GoViral.entitlements` — iCloud container updated
- [x] `Info.plist` — updated
- [x] SPM dependencies: RevenueCat, Firebase, Drops, Lottie
- [x] Package.resolved — resolved
- [x] Build succeeds (`** BUILD SUCCEEDED **`)
- [x] Initial git commit: `1b1b730` "basic flow established"
- [x] Git repo initialized locally

### Documentation (`/docs`)
- [x] `AGENTS.md` — AI agent instructions (root level)
- [x] `docs/product/PRODUCT.md`
- [x] `docs/product/REQUIREMENTS.md`
- [x] `docs/product/MVP.md`
- [x] `docs/ux/UX_FLOWS.md`
- [x] `docs/ux/DESIGN_SYSTEM.md`
- [x] `docs/ux/SCREENS.md`
- [x] `docs/architecture/ARCHITECTURE.md`
- [x] `docs/data/DATA_MODEL.md`
- [x] `docs/api/API_SPEC.md`
- [x] `docs/analysis/BILL_ANALYSIS.md`
- [x] `docs/ai/AI_PIPELINE.md`
- [x] `docs/privacy/PRIVACY.md`
- [x] `docs/legal/LEGAL.md`
- [x] `docs/infra/SUBSCRIPTIONS.md`
- [x] `docs/infra/INFRASTRUCTURE.md`
- [x] `docs/testing/TESTING.md`
- [x] `docs/growth/ANALYTICS.md`
- [x] `docs/growth/APP_STORE.md`
- [x] `docs/decisions/` — folder created

---

## What Does NOT Exist Yet

### iOS
- [ ] Design system implementation (BFColors, BFTypography, BFSpacing, BFAnimations, BFHaptics)
- [ ] Component library (BFButton, BFFindingCard, BFCaseCard, etc.)
- [ ] All feature screens (Home, Capture, OCR, Analysis, Findings, Letters, Cases, Paywall, Settings)
- [ ] Vision OCR integration
- [ ] API client (URLSession)
- [ ] SwiftData models
- [ ] Keychain service
- [ ] StoreKit 2 subscription service
- [ ] Notification service
- [ ] Navigation / routing (RootView logic)
- [ ] Onboarding flow
- [ ] Auth (Apple Sign In)

### Backend
- [ ] Node.js project initialized
- [ ] MySQL schema deployed
- [ ] Authentication endpoints
- [ ] All API endpoints
- [ ] Analysis workers
- [ ] Letter generation workers
- [ ] Hospital directory
- [ ] MRF index

### Infrastructure
- [ ] Domain registered / DNS configured
- [ ] VPS configured
- [ ] R2 bucket created
- [ ] App Store Connect app created

---

## Next Steps (Suggested Order)

1. **Design system** — Implement `Core/DesignSystem/` in iOS (colors, fonts, spacing, animations, haptics)
2. **Component library** — Build `BFButton`, `BFFindingCard`, `BFCaseCard`, `BFMoneyDisplay`, etc.
3. **Navigation skeleton** — Implement tab bar + routing in `RootView`
4. **Screens** — Build each screen per `docs/ux/SCREENS.md`
5. **Backend** — Node.js project, MySQL schema, auth endpoints
6. **API client** — iOS `APIClient.swift` connecting to backend
7. **OCR integration** — Vision framework in `OCRService.swift`
8. **Analysis engine** — Backend workers implementing `docs/analysis/BILL_ANALYSIS.md`
9. **Letter generation** — LLM integration per `docs/ai/AI_PIPELINE.md`
10. **StoreKit 2** — Subscription service + paywall
11. **Testing** — Unit tests, UI tests per `docs/testing/TESTING.md`
12. **Beta** — TestFlight phases per testing plan

---

## GitHub

Remote repo: Not yet created
Branch: main
