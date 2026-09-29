//
//  PaywallViewModel.swift
//

import RevenueCat

/// Purchases now live in `SubscriptionManager`; this keeps the entitlement check in one named place.
enum ProViewModel {
    static func hasPremiumEntitlement(_ customerInfo: CustomerInfo?) -> Bool {
        customerInfo?.entitlements[AppConfig.entitlementID]?.isActive == true
            || customerInfo?.entitlements["lifetime"]?.isActive == true
    }
}
