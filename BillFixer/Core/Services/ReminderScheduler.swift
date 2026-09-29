import Foundation
import UserNotifications

/// Local notifications for case deadlines (e.g. the 120-day GFE dispute window). Nothing leaves the device.
/// Notification text never includes amounts or diagnosis details — only the provider and the task.
enum ReminderScheduler {
    private static let center = UNUserNotificationCenter.current()

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: AppStorageKeys.deadlineRemindersEnabled) as? Bool ?? true
    }

    static func sync(caseId: String, provider: String, deadlines: [Deadline]) async {
        let prefix = "deadline.\(caseId)."
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard isEnabled, await center.notificationSettings().authorizationStatus == .authorized else { return }

        for deadline in deadlines where !deadline.isCompleted {
            let offsets = deadline.notifyDays.isEmpty ? [7, 1, 0] : deadline.notifyDays
            for days in Set(offsets) {
                guard let due = DateHelpers.localDate(deadline.dueDate, hour: 9),
                      let fire = Calendar.current.date(byAdding: .day, value: -days, to: due), fire > Date() else { continue }
                let content = UNMutableNotificationContent()
                content.title = days == 0 ? "Due today: \(deadline.label)" : "\(deadline.label) in \(days) day\(days == 1 ? "" : "s")"
                content.body = "\(provider) — open Bill Fixer to take the next step."
                content.sound = .default
                content.userInfo = ["caseId": caseId]
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let request = UNNotificationRequest(identifier: "\(prefix)\(deadline.id).\(days)", content: content,
                                                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
                try? await center.add(request)
            }
        }
    }

    static func cancel(caseId: String) async {
        let prefix = "deadline.\(caseId)."
        let ids = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    static func cancelAll() { center.removeAllPendingNotificationRequests() }
}
