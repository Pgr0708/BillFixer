//
//  NotificationScreenView.swift
//  BillFixer — Notification permission prompt with circular design
//

import SwiftUI
import UIKit

struct NotificationScreenView: View {
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @StateObject private var notificationManager = NotificationManager()
    @State private var isRequesting = false
    @State private var appeared = false

    private let features: [(String, String, Color)] = [
        ("Deadline reminders",   "calendar.badge.clock",        Color(hex: "#0F2B5B")),
        ("Follow-up nudges",     "arrow.uturn.forward.circle",  Color(hex: "#00897B")),
        ("Analysis updates",     "bell.badge.fill",             Color(hex: "#E8A422")),
    ]

    var body: some View {
        ZStack {
            // ── Background ──────────────────────────────────────────────
            Color(hex: "#F7F9FD").ignoresSafeArea()

            // ── Circular decorations ─────────────────────────────────────
            circleDecorations

            // ── Content ──────────────────────────────────────────────────
            VStack(spacing: 0) {

                // Top bar
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(hex: "#0F2B5B"), Color(hex: "#00B4A0")],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)
                            .overlay {
                                Text("B")
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                        Text("BillFixer")
                            .font(.system(size: 19, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: "#0F2B5B"))
                    }
                    Spacer()
                    Button("Skip") { continueWithoutReminders() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "#718096"))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer()

                // ── Large circular bell icon ─────────────────────────────
                ZStack {
                    // Outer pulse ring
                    Circle()
                        .strokeBorder(Color(hex: "#0F2B5B").opacity(0.10), lineWidth: 2)
                        .frame(width: 170, height: 170)
                        .scaleEffect(appeared ? 1 : 0.6)
                        .opacity(appeared ? 1 : 0)

                    Circle()
                        .fill(Color(hex: "#0F2B5B").opacity(0.07))
                        .frame(width: 148, height: 148)
                        .scaleEffect(appeared ? 1 : 0.6)
                        .opacity(appeared ? 1 : 0)

                    // Main circle
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "#0F2B5B"), Color(hex: "#1A3F82")],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 118, height: 118)
                        .shadow(color: Color(hex: "#0F2B5B").opacity(0.3), radius: 24, y: 10)
                        .scaleEffect(appeared ? 1 : 0.5)
                        .opacity(appeared ? 1 : 0)

                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 46, weight: .medium))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color(hex: "#00D4BC"))
                        .scaleEffect(appeared ? 1 : 0.5)
                        .opacity(appeared ? 1 : 0)
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.72), value: appeared)
                .accessibilityHidden(true)

                Spacer().frame(height: 32)

                // Heading
                Text("Stay on top of your case")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "#1A202C"))
                    .multilineTextAlignment(.center)
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1), value: appeared)

                Text("Get a reminder when it's time to follow up or take action on a bill.")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: "#4A5568"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 10)
                    .padding(.horizontal, 30)
                    .offset(y: appeared ? 0 : 16)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.15), value: appeared)

                Spacer().frame(height: 28)

                // ── Feature cards (circular icon style) ─────────────────
                VStack(spacing: 12) {
                    ForEach(Array(features.enumerated()), id: \.offset) { i, feature in
                        featureRow(feature.0, symbol: feature.1, color: feature.2)
                            .offset(y: appeared ? 0 : 20)
                            .opacity(appeared ? 1 : 0)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.75)
                                    .delay(0.2 + Double(i) * 0.07),
                                value: appeared
                            )
                    }
                }
                .padding(.horizontal, 24)

                // Denied notice
                if notificationManager.authorizationStatus == .denied {
                    Text("Notifications are off. Enable them in Settings or continue without reminders.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#64748B"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                }

                Spacer()

                // ── Primary CTA ──────────────────────────────────────────
                Button(action: primaryAction) {
                    HStack(spacing: 9) {
                        if isRequesting {
                            ProgressView().tint(.white)
                        } else {
                            Text(notificationManager.authorizationStatus == .denied
                                 ? "Open Settings"
                                 : "Enable Notifications")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                            Image(systemName: notificationManager.authorizationStatus == .denied
                                  ? "arrow.up.right" : "bell.fill")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#0F2B5B"), Color(hex: "#00B4A0")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color(hex: "#0F2B5B").opacity(0.3), radius: 16, y: 8)
                }
                .buttonStyle(.plain)
                .disabled(isRequesting)
                .padding(.horizontal, 28)
                .scaleEffect(appeared ? 1 : 0.9)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.4), value: appeared)

                Button("Continue without reminders", action: continueWithoutReminders)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "#718096"))
                    .padding(.top, 14)
                    .padding(.bottom, 50)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeIn(duration: 0.3).delay(0.45), value: appeared)
            }
        }
        .onAppear {
            withAnimation { appeared = true }
        }
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

    // MARK: - Feature Row (circular icon)

    private func featureRow(_ title: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Circle()
                .fill(color.opacity(0.12))
                .frame(width: 46, height: 46)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                }

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: "#253653"))

            Spacer()

            Circle()
                .fill(Color(hex: "#00B4A0").opacity(0.15))
                .frame(width: 26, height: 26)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: "#00897B"))
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Circular background decorations

    private var circleDecorations: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#0F2B5B").opacity(0.05))
                .frame(width: 300, height: 300)
                .offset(x: 160, y: -200)

            Circle()
                .fill(Color(hex: "#00B4A0").opacity(0.06))
                .frame(width: 220, height: 220)
                .offset(x: -130, y: 320)

            Circle()
                .strokeBorder(Color(hex: "#0F2B5B").opacity(0.06), lineWidth: 1)
                .frame(width: 160, height: 160)
                .offset(x: -140, y: -140)
        }
    }

    // MARK: - Actions

    private func primaryAction() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if notificationManager.authorizationStatus == .denied {
            let url = URL(string: UIApplication.openSettingsURLString)!
            openURL(url) { accepted in
                if !accepted { DropsManager.showError(title: "Couldn't open Settings") }
            }
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
                    DropsManager.showSuccess(title: "Reminders enabled", subtitle: "We'll keep you up to date on your case")
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    DropsManager.showInfo(title: "Notifications off", subtitle: "You can enable them later in Settings")
                }
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                DropsManager.showError(title: "Couldn't request permission", subtitle: error.localizedDescription)
            }
        }
    }

    private func continueWithoutReminders() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        settings.notificationsEnabled = false
        settings.hasSeenNotificationPrompt = true
    }
}

#Preview {
    NotificationScreenView()
        .environmentObject(SettingsManager())
}
