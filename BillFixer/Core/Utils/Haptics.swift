//
//  Haptics.swift
//  Prepared generators (lower latency) + the named sequences from DESIGN_SYSTEM.md.
//

import UIKit

@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let notify = UINotificationFeedbackGenerator()
    private static let select = UISelectionFeedbackGenerator()

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: AppStorageKeys.hapticsEnabled) as? Bool ?? true
    }

    static func prepare() {
        guard isEnabled else { return }
        [light, medium, heavy].forEach { $0.prepare() }
        notify.prepare()
    }

    static func tapLight() { guard isEnabled else { return }; light.impactOccurred() }
    static func tap() { guard isEnabled else { return }; medium.impactOccurred() }
    static func tapHeavy() { guard isEnabled else { return }; heavy.impactOccurred() }
    static func tapSoft() { guard isEnabled else { return }; soft.impactOccurred(intensity: 0.7) }
    static func selection() { guard isEnabled else { return }; select.selectionChanged() }
    static func success() { guard isEnabled else { return }; notify.notificationOccurred(.success) }
    static func warning() { guard isEnabled else { return }; notify.notificationOccurred(.warning) }
    static func error() { guard isEnabled else { return }; notify.notificationOccurred(.error) }

    /// medium → success → light
    static func scanComplete() {
        guard isEnabled else { return }
        medium.impactOccurred()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100)); notify.notificationOccurred(.success)
            try? await Task.sleep(for: .milliseconds(200)); light.impactOccurred()
        }
    }

    /// light × count, 80 ms apart, then medium.
    static func findingsRevealed(count: Int) {
        guard isEnabled else { return }
        Task { @MainActor in
            for _ in 0..<min(count, 8) {
                light.impactOccurred()
                try? await Task.sleep(for: .milliseconds(80))
            }
            medium.impactOccurred()
        }
    }

    /// heavy → success
    static func letterGenerated() {
        guard isEnabled else { return }
        heavy.impactOccurred()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150)); notify.notificationOccurred(.success)
        }
    }
}
