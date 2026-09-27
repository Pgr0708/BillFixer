# BillFixer — Architecture

> DELETE BEFORE SUBMISSION

---

## iOS Client Architecture

### Pattern: MVVM + Service Layer + Domain Layer

```
┌─────────────────────────────────────────────────────┐
│                     SwiftUI Views                    │
│  (render state, send user intents, no business logic)│
└───────────────────┬─────────────────────────────────┘
                    │ @Published / @State
┌───────────────────▼─────────────────────────────────┐
│                  ViewModels / Feature Models          │
│  (orchestrate services, prepare display state,        │
│   handle navigation, validate inputs)                │
└───────────────────┬─────────────────────────────────┘
                    │ async/await calls
┌───────────────────▼─────────────────────────────────┐
│                   Service Layer                      │
│  OCRService  │  APIClient  │  SubscriptionService   │
│  DocumentService  │  BillAnalysisService             │
│  (protocol-backed, injectable, testable)             │
└─────────┬──────────────────┬────────────────────────┘
          │                  │
┌─────────▼──────┐  ┌────────▼────────────────────────┐
│  Domain Models │  │        External Systems           │
│  Bill, EOB,    │  │  REST API  │  SwiftData  │  R2   │
│  Finding, Case │  │  Vision    │  Keychain   │  RevCat│
└────────────────┘  └─────────────────────────────────┘
```

---

## Folder Structure

```
BillFixer/
├── App/
│   ├── BillFixerApp.swift         — App entry, env setup
│   ├── AppDelegate.swift          — Push notifications, Firebase
│   └── RootView.swift             — Auth gate, tab router
│
├── Core/
│   ├── DesignSystem/
│   │   ├── BFColors.swift
│   │   ├── BFTypography.swift
│   │   ├── BFSpacing.swift
│   │   ├── BFAnimations.swift
│   │   ├── BFHaptics.swift
│   │   └── Components/
│   │       ├── BFButton.swift
│   │       ├── BFFindingCard.swift
│   │       ├── BFCaseCard.swift
│   │       ├── BFMoneyDisplay.swift
│   │       ├── BFStatusBadge.swift
│   │       ├── BFDocumentThumbnail.swift
│   │       ├── BFProgressStepper.swift
│   │       ├── BFEmptyState.swift
│   │       ├── BFGlassCard.swift
│   │       └── BFSectionHeader.swift
│   ├── Networking/
│   │   ├── APIClient.swift
│   │   ├── APIClientProtocol.swift
│   │   ├── Endpoints.swift
│   │   ├── NetworkError.swift
│   │   ├── RequestBuilder.swift
│   │   └── ResponseDecoder.swift
│   ├── Persistence/
│   │   ├── SwiftDataContainer.swift
│   │   ├── LocalModels/
│   │   │   ├── CaseEntity.swift
│   │   │   ├── DocumentEntity.swift
│   │   │   └── FindingEntity.swift
│   │   └── Migrations/
│   ├── Security/
│   │   ├── KeychainService.swift
│   │   └── DataRedaction.swift
│   └── Extensions/
│       ├── Decimal+Currency.swift
│       ├── Date+Formatting.swift
│       ├── Color+Hex.swift
│       └── View+Modifiers.swift
│
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── HomeViewModel.swift
│   ├── BillCapture/
│   │   ├── BillCaptureView.swift
│   │   ├── BillCaptureViewModel.swift
│   │   ├── CameraView.swift
│   │   └── PageThumbnailsView.swift
│   ├── OCRReview/
│   │   ├── OCRReviewView.swift
│   │   ├── OCRReviewViewModel.swift
│   │   ├── LineItemEditorView.swift
│   │   └── DocumentAnnotationView.swift
│   ├── Analysis/
│   │   ├── AnalysisLoadingView.swift
│   │   └── AnalysisViewModel.swift
│   ├── Findings/
│   │   ├── FindingsView.swift
│   │   ├── FindingsViewModel.swift
│   │   ├── FindingDetailView.swift
│   │   └── FindingEvidenceView.swift
│   ├── Letters/
│   │   ├── LetterPreviewView.swift
│   │   ├── LetterViewModel.swift
│   │   ├── LetterEditorView.swift
│   │   └── PDFExportService.swift
│   ├── PhoneScripts/
│   │   ├── ScriptsListView.swift
│   │   ├── PhoneScriptView.swift
│   │   └── ScriptViewModel.swift
│   ├── Cases/
│   │   ├── CasesListView.swift
│   │   ├── CaseDetailView.swift
│   │   ├── CaseTimelineView.swift
│   │   ├── DeadlineTrackerView.swift
│   │   └── CasesViewModel.swift
│   ├── FinancialAssistance/
│   │   ├── FAEligibilityView.swift
│   │   └── FAViewModel.swift
│   ├── Subscription/
│   │   ├── PaywallView.swift
│   │   └── SubscriptionViewModel.swift
│   └── Settings/
│       ├── SettingsView.swift
│       ├── PrivacyDashboardView.swift
│       └── SettingsViewModel.swift
│
├── Domain/
│   ├── Bill/
│   │   ├── Bill.swift             — Value types
│   │   ├── BillLineItem.swift
│   │   └── BillParser.swift
│   ├── EOB/
│   │   ├── EOB.swift
│   │   ├── EOBLineItem.swift
│   │   └── EOBParser.swift
│   ├── Finding/
│   │   ├── Finding.swift
│   │   ├── FindingType.swift
│   │   ├── FindingSeverity.swift
│   │   └── FindingEvidence.swift
│   ├── Case/
│   │   ├── BFCase.swift
│   │   ├── CaseStatus.swift
│   │   ├── CaseTimeline.swift
│   │   └── CaseOutcome.swift
│   └── Provider/
│       ├── Provider.swift
│       └── Hospital.swift
│
└── Services/
    ├── OCRService.swift           — Vision framework wrapper
    ├── BillAnalysisService.swift  — Calls backend /analyze
    ├── SubscriptionService.swift  — StoreKit 2 wrapper
    ├── DocumentService.swift      — Image handling, temp files
    ├── NotificationService.swift  — UNUserNotificationCenter
    └── AnalyticsService.swift     — Privacy-safe event logging
```

---

## Backend Architecture

```
┌─────────────────────────────────┐
│          iOS App                │
└────────────────┬────────────────┘
                 │ HTTPS REST API (JWT auth)
┌────────────────▼────────────────┐
│      Node.js + Express API      │
│  routes/ controllers/ middleware│
└────┬──────────────────┬─────────┘
     │                  │
┌────▼──────┐    ┌──────▼──────────┐
│   MySQL   │    │  Redis + Bull   │
│  Primary  │    │  Job Queue      │
│  Database │    │  (Background    │
└───────────┘    │   workers)      │
                 └──────┬──────────┘
                        │
          ┌─────────────┼─────────────┐
          │             │             │
   ┌──────▼──┐  ┌───────▼──┐  ┌──────▼──┐
   │ OCR     │  │ Analysis  │  │  Letter │
   │ Worker  │  │ Worker    │  │ Worker  │
   └─────────┘  └───────────┘  └─────────┘
          │             │             │
   ┌──────▼─────────────▼─────────────▼──┐
   │          External Services           │
   │  LLM API │ CMS MRF API │ R2 Storage │
   └──────────────────────────────────────┘
```

---

## Dependency Rules (What Can Depend on What)

```
✅ Views → ViewModels
✅ ViewModels → Services
✅ ViewModels → Domain Models
✅ Services → APIClient
✅ Services → Domain Models
✅ Domain Models → nothing (pure value types)

❌ Views → Services (direct)
❌ Views → APIClient (direct)
❌ Views → Business Logic
❌ Domain Models → Services
❌ Domain Models → SwiftData
❌ Any layer → Keychain (only KeychainService)
❌ Any iOS layer → LLM APIs (always backend only)
```

---

## State Management

- Use `@Observable` (Swift 5.9+ Observation) for ViewModels
- Use `@State` / `@Binding` for local view state only
- SwiftData for local case/finding persistence (offline support)
- No singleton ViewModels — inject via environment or init
- No global state stores — each feature owns its state

---

## Network Layer

### Authentication
- JWT access token (15 min expiry) + refresh token (30 days)
- Tokens stored in Keychain
- Auto-refresh interceptor in APIClient

### Error Handling
- All network errors map to `NetworkError` enum
- User-facing errors translated to `BFError` with recovery suggestions
- Retry logic: exponential backoff for 5xx, no retry for 4xx

### Offline Support
- Cases and findings cached in SwiftData
- Analysis requires network (backend processing)
- Case management (notes, timeline) works offline and syncs

---

## Security Architecture

- TLS 1.3 minimum for all network calls
- Certificate pinning for production API
- Keychain with `.whenUnlockedThisDeviceOnly` access
- No sensitive data in logs, analytics, or crash reports
- All documents encrypted at rest in R2 (SSE)
- Presigned URLs for document access (short-lived, 1 hour)
- API rate limiting by user ID
- All admin endpoints behind separate auth

---

## Background Tasks

| Task | Trigger | Worker |
|---|---|---|
| Bill analysis | User submits | Analysis Worker (Node) |
| Letter generation | User requests | Letter Worker (Node) |
| Hospital MRF fetch | Provider matched | MRF Worker (cron + on-demand) |
| Deadline notifications | Daily cron | Notification Worker |
| Document expiry | Daily cron | Cleanup Worker |
| Subscription sync | App Store webhook | Subscription Worker |
