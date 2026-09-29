//
//  AppDelegate.swift
//

import OSLog
import Foundation
import Firebase
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications
import RevenueCat

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        Analytics.setAnalyticsCollectionEnabled(true)
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .error
        #endif
        if isRevenueCatConfigured {
            Purchases.configure(withAPIKey: revenueCatAPIKey)
            Purchases.shared.delegate = self
        } else {
            AppLog.purchases.error("RevenueCat key missing — purchases disabled until Consts.revenueCatAPIKey is set")
        }

        application.registerForRemoteNotifications()
        Haptics.prepare()
        return true
    }

    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        AppLog.app.error("APNs registration failed: \(error.localizedDescription, privacy: .public)")
    }

    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
}

extension AppDelegate: MessagingDelegate {
    nonisolated func messaging(_: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        AppLog.app.debug("FCM token refreshed: \(fcmToken != nil, privacy: .public)")
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Show deadline reminders even when the app is open.
    nonisolated func userNotificationCenter(_: UNUserNotificationCenter, willPresent _: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}

extension AppDelegate: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        let active = customerInfo.entitlements[AppConfig.entitlementID]?.isActive == true
        Task { @MainActor in SubscriptionManager.shared.apply(entitlementActive: active) }
    }
}
