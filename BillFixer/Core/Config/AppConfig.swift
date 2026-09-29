//
//  AppConfig.swift
//

import Foundation

nonisolated enum AppConfig {
    /// Production API. Debug builds can point elsewhere with the `BF_API_URL` launch environment variable
    /// (Xcode › Scheme › Run › Arguments), e.g. http://127.0.0.1:4100/v1 for a local backend.
    static let apiBaseURL: URL = {
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["BF_API_URL"], let url = URL(string: override) { return url }
        #endif
        return URL(string: "https://billfixer.dakshyaminfotech.store/v1")!
    }()
    /// RevenueCat entitlement that unlocks Premium (must match the RevenueCat dashboard and REVENUECAT_ENTITLEMENT on the server).
    static let entitlementID = "pro"
    static let monthlyProductID = "com.billfixer.app.premium.monthly"
    static let annualProductID = "com.billfixer.app.premium.annual"
    /// Minimum time the analysis screen stays up, so the result doesn't feel like a flicker (UX_FLOWS.md).
    static let minimumAnalysisDisplay: Duration = .milliseconds(2500)
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
}
