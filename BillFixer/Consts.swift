//
//  Consts.swift
//

/// RevenueCat *public* SDK key (appl_…). It is designed to ship in the app binary — it can only read offerings
/// and make purchases for the signed-in App Store account. Server-side secrets stay on the backend.
/// Replace the placeholder with the key from RevenueCat → Project → API keys → App-specific keys.
let revenueCatAPIKey = "........................"

var isRevenueCatConfigured: Bool { revenueCatAPIKey.hasPrefix("appl_") }
