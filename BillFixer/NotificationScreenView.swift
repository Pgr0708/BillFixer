//
//  NotificationScreenView.swift
//  BillFixer
//

import SwiftUI
import UIKit

struct NotificationScreenView: View {
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @StateObject private var notificationManager = NotificationManager()
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("BillFixer")
                    .font(.custom("Nunito-ExtraBold", size: 20, relativeTo: .headline))
                    .foregroundStyle(Color(hex: "#0B2B5C"))
                Spacer()
                Button("Skip") { continueWithoutReminders() }
                    .font(.custom("DMSans-Bold", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Color(hex: "#087D91"))
            }

            Spacer(minLength: 22)

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 46, weight: .medium))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color(hex: "#47D7C2"))
                .frame(width: 120, height: 120)
                .background(
                    LinearGradient(colors: [Color(hex: "#0D55A5"), Color(hex: "#0B2B5C")], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 38, style: .continuous)
                )
                .shadow(color: Color(hex: "#0B2B5C").opacity(0.18), radius: 24, y: 12)
                .accessibilityHidden(true)

            Text("Stay on top of your case")
                .font(.custom("Nunito-ExtraBold", size: 30, relativeTo: .largeTitle))
                .foregroundStyle(Color(hex: "#14213D"))
                .multilineTextAlignment(.center)
                .padding(.top, 28)

            Text("Get a reminder when it’s time to follow up or take action on a bill.")
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "#4A5A75"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 15) {
                reminderRow("Deadline reminders", symbol: "calendar.badge.clock")
                reminderRow("Follow-up nudges", symbol: "arrow.uturn.forward.circle")
                reminderRow("Analysis updates", symbol: "checkmark.circle")
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(hex: "#E5EBF4"), lineWidth: 1)
            }
            .padding(.top, 28)

            if notificationManager.authorizationStatus == .denied {
                Text("Notifications are off. You can enable them in Settings or continue without reminders.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#64748B"))
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
            }

            Spacer(minLength: 24)

            Button(action: primaryAction) {
                HStack(spacing: 9) {
                    if isRequesting {
                        ProgressView().tint(.white)
                    } else {
                        Text(notificationManager.authorizationStatus == .denied ? "Open Settings" : "Enable Notifications")
                        Image(systemName: notificationManager.authorizationStatus == .denied ? "arrow.up.right" : "bell")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .font(.custom("DMSans-Bold", size: 16, relativeTo: .headline))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(colors: [Color(hex: "#0B2B5C"), Color(hex: "#176AC4")], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(isRequesting)

            Button("Continue without reminders", action: continueWithoutReminders)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "#4A5A75"))
                .padding(.top, 14)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .background(Color(hex: "#F7F9FD").ignoresSafeArea())
        .task {
            await notificationManager.refreshAuthorizationStatus()
            if notificationManager.isAuthorized {
                settings.notificationsEnabled = true
                settings.hasSeenNotificationPrompt = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await notificationManager.refreshAuthorizationStatus()
                if notificationManager.isAuthorized {
                    settings.notificationsEnabled = true
                    settings.hasSeenNotificationPrompt = true
                }
            }
        }
    }

    private func reminderRow(_ title: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: "#087D91"))
                .frame(width: 22)
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: "#253653"))
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: "#12A785"))
        }
    }

    private func primaryAction() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if notificationManager.authorizationStatus == .denied {
            let settingsURL = URL(string: UIApplication.openSettingsURLString)!
            openURL(settingsURL) { accepted in
                if !accepted { DropsManager.showError(title: "Couldn’t open Settings") }
            }
            DropsManager.showInfo(title: "Notification settings opened")
            return
        }

        isRequesting = true
        Task {
            defer { isRequesting = false }
            do {
                if try await notificationManager.requestAuthorization() {
                    settings.notificationsEnabled = true
                    settings.hasSeenNotificationPrompt = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    DropsManager.showSuccess(title: "Reminders enabled", subtitle: "We’ll keep you up to date on your case")
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    DropsManager.showInfo(title: "Notifications remain off", subtitle: "You can enable them later in Settings")
                }
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                DropsManager.showError(title: "Couldn’t request permission", subtitle: error.localizedDescription)
            }
        }
    }

    private func continueWithoutReminders() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        settings.notificationsEnabled = false
        settings.hasSeenNotificationPrompt = true
        DropsManager.showInfo(title: "Continuing without reminders", subtitle: "You can change this any time in Settings")
    }
}

#Preview {
    NotificationScreenView()
        .environmentObject(SettingsManager())
}
