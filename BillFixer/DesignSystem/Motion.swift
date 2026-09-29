//
//  Motion.swift
//  Animation tokens. Every animated view reads `accessibilityReduceMotion` and falls back to opacity.
//

import SwiftUI

enum BFMotion {
    static let quick = Animation.easeOut(duration: 0.15)
    static let standard = Animation.easeInOut(duration: 0.25)
    static let smooth = Animation.easeInOut(duration: 0.35)
    static let slow = Animation.easeInOut(duration: 0.5)
    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let bounce = Animation.spring(response: 0.42, dampingFraction: 0.6)
    static let gentle = Animation.spring(response: 0.5, dampingFraction: 0.82)
    static let countUp = Animation.easeOut(duration: 0.8)

    /// Stagger delay for list item `index` (capped so long lists never feel slow).
    static func stagger(_ index: Int, step: Double = 0.05) -> Double { min(Double(index), 8) * step }
}

extension Animation {
    /// Returns nil (no animation) when Reduce Motion is on.
    func unlessReduced(_ reduce: Bool) -> Animation? { reduce ? nil : self }
}
