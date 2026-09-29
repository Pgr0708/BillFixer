import OSLog
import Foundation
import Observation
import RevenueCat

/// App Store purchases through RevenueCat. The server re-verifies every entitlement with RevenueCat
/// (POST /subscription/validate + webhook), so a tampered client can't unlock premium server features.
@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    private(set) var packages: [Package] = []
    private(set) var isLoadingOfferings = false
    private(set) var isPurchasing = false
    private(set) var offeringError: String?
    /// Local entitlement (fast UI); the server tier from `AppSession` is authoritative for API features.
    private(set) var entitlementActive = UserDefaults.standard.bool(forKey: AppStorageKeys.isPremium)

    var isAvailable: Bool { isRevenueCatConfigured }
    var annual: Package? { packages.first { $0.packageType == .annual } }
    var monthly: Package? { packages.first { $0.packageType == .monthly } }

    /// "Save 37%" from real store prices, nil when it can't be computed.
    var annualSavingsPercent: Int? {
        guard let a = annual?.storeProduct.price, let m = monthly?.storeProduct.price, m > 0 else { return nil }
        let yearlyAtMonthly = m * 12
        guard yearlyAtMonthly > a else { return nil }
        let pct = ((yearlyAtMonthly - a) / yearlyAtMonthly * 100) as NSDecimalNumber
        return pct.intValue
    }

    func apply(entitlementActive: Bool) {
        self.entitlementActive = entitlementActive
        UserDefaults.standard.set(entitlementActive, forKey: AppStorageKeys.isPremium)
    }

    /// Ties purchases to our user id so the RevenueCat webhook can find the account.
    func identify(userId: String) async {
        guard isAvailable else { return }
        do {
            let (info, _) = try await Purchases.shared.logIn(userId)
            apply(entitlementActive: info.entitlements[AppConfig.entitlementID]?.isActive == true)
        } catch {
            AppLog.purchases.error("RevenueCat logIn failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func reset() async {
        apply(entitlementActive: false)
        guard isAvailable, !Purchases.shared.isAnonymous else { return }
        _ = try? await Purchases.shared.logOut()
    }

    func loadOfferings() async {
        guard isAvailable else {
            offeringError = "Subscriptions aren’t available in this build yet."
            return
        }
        guard packages.isEmpty, !isLoadingOfferings else { return }
        isLoadingOfferings = true
        offeringError = nil
        defer { isLoadingOfferings = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            packages = offerings.current?.availablePackages.filter { [.monthly, .annual].contains($0.packageType) } ?? []
            if packages.isEmpty { offeringError = "Plans are unavailable right now. You can keep using the free plan." }
        } catch {
            offeringError = "Plans couldn’t load. Check your connection and try again."
        }
    }

    enum PurchaseOutcome { case purchased, cancelled, pending, failed(String) }

    func purchase(_ package: Package) async -> PurchaseOutcome {
        guard isAvailable else { return .failed("Subscriptions aren’t available in this build yet.") }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return .cancelled }
            let active = result.customerInfo.entitlements[AppConfig.entitlementID]?.isActive == true
            apply(entitlementActive: active)
            return active ? .purchased : .pending
        } catch let error as ErrorCode where error == .paymentPendingError {
            return .pending
        } catch let error as ErrorCode where error == .purchaseCancelledError {
            return .cancelled
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func restore() async -> Bool? {
        guard isAvailable else { return nil }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            let active = info.entitlements[AppConfig.entitlementID]?.isActive == true
            apply(entitlementActive: active)
            return active
        } catch {
            return nil
        }
    }
}
