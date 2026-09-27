# BillFixer — Subscriptions

> DELETE BEFORE SUBMISSION

---

## Product IDs (App Store Connect)

| Product | Product ID |
|---|---|
| Monthly Premium | com.billfixer.app.premium.monthly |
| Annual Premium | com.billfixer.app.premium.annual |
| Family Monthly (future) | com.billfixer.app.premium.family.monthly |
| Family Annual (future) | com.billfixer.app.premium.family.annual |

---

## Pricing

| Product | Price | Monthly Equivalent | Savings vs Monthly |
|---|---|---|---|
| Monthly | $7.99 | $7.99 | — |
| Annual | $59.99 | $5.00 | ~37% |
| Family Monthly (future) | $11.99 | $11.99 | — |
| Family Annual (future) | $89.99 | $7.50 | ~37% |

---

## Free Tier Limits

| Feature | Free | Premium |
|---|---|---|
| Bill scans | Unlimited | Unlimited |
| Basic bill explanation | ✅ | ✅ |
| Findings visible | 1 (rest blurred) | All |
| Letter generation | ❌ | ✅ |
| Phone scripts | ❌ | ✅ |
| PDF evidence export | ❌ | ✅ |
| Price comparison | Preview only | Full |
| Financial assistance | Notified only | Full detail + letter |
| Active cases | 1 | Unlimited |
| Case history | 30 days | Unlimited |
| Deadline notifications | ❌ | ✅ |
| Savings tracking | ❌ | ✅ |
| EOB reconciliation | ❌ | ✅ |

---

## StoreKit 2 Implementation

### Subscription Service (iOS)

```swift
protocol SubscriptionServiceProtocol {
    var currentEntitlement: SubscriptionTier { get }
    func loadProducts() async throws -> [Product]
    func purchase(_ product: Product) async throws -> PurchaseResult
    func restorePurchases() async throws
    func listenForTransactions()
}

enum SubscriptionTier: String {
    case free = "free"
    case premium = "premium"
}

enum PurchaseResult {
    case success(Transaction)
    case userCancelled
    case pending
}
```

### Transaction Listener (app startup)
```swift
// In BillFixerApp.swift
.task {
    await subscriptionService.listenForTransactions()
}
```

### Entitlement Check Pattern
```swift
// In ViewModel
guard subscriptionService.currentEntitlement == .premium else {
    paywallTrigger = .letterGeneration
    return
}
```

---

## Server-Side Validation

After every StoreKit purchase:
1. iOS sends `POST /subscription/validate` with receipt/transaction ID
2. Backend validates with App Store Server API
3. Updates `subscriptions` table
4. Returns canonical tier status

**Important:** iOS-reported tier is NEVER trusted alone for gating API calls.
Backend checks `subscriptions.status` and `subscriptions.expires_at` on every premium API call.

### App Store Server Notifications
- Configure App Store Server Notifications (v2) webhook → `/webhooks/appstore`
- Events to handle: `DID_RENEW`, `EXPIRED`, `DID_FAIL_TO_RENEW`, `GRACE_PERIOD_EXPIRED`, `REFUND`, `REVOKE`
- Update `subscriptions` table on each event

---

## Grace Period

- iOS handles grace period natively (StoreKit 2)
- During grace period: treat as premium (allow access)
- Backend uses `subscriptions.grace_period_expires` to determine grace status
- If grace expires without renewal: downgrade to free

---

## Paywall Trigger Points

| Trigger | Context | Paywall Type |
|---|---|---|
| Tapping blurred finding (2+) | Findings screen | Full-screen sheet |
| Tapping letter generation | Findings/case | Sheet |
| Tapping phone script | Scripts tab | Sheet |
| Tapping PDF export | Letter screen | Sheet |
| Viewing price comparison detail | Findings | Sheet |
| Creating second case | Cases | Sheet |
| Accessing financial assistance detail | Finding | Sheet |

### Paywall Design Requirement
- Always surface the benefit immediately ("Unlock [Feature Name]")
- Show annual as default (best value)
- Monthly visible as secondary option
- Gold gradient CTA button
- Restore Purchases always visible

---

## Revenue Tracking Events

Send these events to analytics (no user content):

| Event | When |
|---|---|
| `paywall_shown` | Paywall presented (+ trigger point key) |
| `paywall_dismissed` | User dismissed without purchasing |
| `purchase_started` | User tapped purchase |
| `purchase_complete` | Transaction verified |
| `purchase_failed` | Transaction failed |
| `restore_tapped` | Restore tapped |
| `restore_complete` | Restore successful |
| `subscription_expired` | Grace period ended |
| `subscription_renewed` | Annual/monthly renewed |
