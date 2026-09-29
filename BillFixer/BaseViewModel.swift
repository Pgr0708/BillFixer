//
//  BaseViewModel.swift
//

import Foundation
import RevenueCat

/// Kept for source compatibility with older screens. Premium state now lives in `SubscriptionManager`.
@MainActor
class BaseViewModel: NSObject {
    static let shared = BaseViewModel()

    func checkUserIsPro(customerInfo: CustomerInfo?) {
        SubscriptionManager.shared.apply(entitlementActive: ProViewModel.hasPremiumEntitlement(customerInfo))
    }
}
