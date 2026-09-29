import Foundation

/// One place for user-facing feedback: a Drop + the matching haptic.
enum Toast {
    static func success(_ title: String, _ subtitle: String? = nil) {
        Haptics.success()
        DropsManager.showSuccess(title: title, subtitle: subtitle)
    }

    static func info(_ title: String, _ subtitle: String? = nil) {
        DropsManager.showInfo(title: title, subtitle: subtitle)
    }

    static func warning(_ title: String, _ subtitle: String? = nil) {
        Haptics.warning()
        DropsManager.showWarning(title: title, subtitle: subtitle)
    }

    static func error(_ error: Error) {
        let e = error.asAPIError
        guard e != .cancelled else { return }
        Haptics.error()
        DropsManager.showError(title: e.title, subtitle: e.message)
    }

    static func error(_ title: String, _ subtitle: String? = nil) {
        Haptics.error()
        DropsManager.showError(title: title, subtitle: subtitle)
    }
}
