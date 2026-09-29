//
//  NotificationManager.swift
//  BillFixer
//

import Foundation
internal import Combine
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    var isAuthorized: Bool {
        authorizationStatus == .authorized
            || authorizationStatus == .provisional
            || authorizationStatus == .ephemeral
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        let isGranted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        await refreshAuthorizationStatus()
        return isGranted
    }

    func scheduleReminder(identifier: String, title: String, body: String, at date: Date) async throws {
        await refreshAuthorizationStatus()
        guard isAuthorized else { throw NotificationManagerError.permissionNotGranted }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await center.add(request)
    }

    func cancelReminder(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

private enum NotificationManagerError: LocalizedError {
    case permissionNotGranted

    var errorDescription: String? {
        "Notification permission is required to schedule a reminder."
    }
}
