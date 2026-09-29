//
//  RootView.swift
//  App flow: onboarding → paywall (once) → notification → customization → main tabs.
//

import SwiftUI

/// All possible states in the first-launch / navigation flow.
enum AppFlow: Equatable {
    case loading
    case onboarding
    case paywall
    case notification
    case customization
    case main
}

struct RootView: View {
    @EnvironmentObject private var settings: SettingsManager

    /// Evaluate the current step the user should be on.
    /// Each step is shown exactly once — gated by its `hasSeenX` flag.
    private var flow: AppFlow {
        // 1. Onboarding — very first launch
        if !settings.hasSeenOnboarding         { return .onboarding }

        // 2. Paywall — shown once right after onboarding
        if !settings.hasSeenPaywall            { return .paywall }

        // 3. Notification permission prompt
        if !settings.hasSeenNotificationPrompt { return .notification }

        // 4. Customization (theme / accent colour)
        if !settings.hasSeenCustomization      { return .customization }

        // 5. Main app
        return .main
    }

    var body: some View {
        ZStack {
            switch flow {

            case .loading:
                BFLoadingBackground()
                    .transition(.opacity)

            case .onboarding:
                OnBoardingScreenView()
                    .transition(.opacity)

            case .paywall:
                PaywallScreenView(reason: .general, isOnboarding: true) {
                    withAnimation(BFMotion.smooth) {
                        settings.hasSeenPaywall = true
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))

            case .notification:
                NotificationScreenView()
                    .transition(.opacity)

            case .customization:
                CustomizationScreenView()
                    .transition(.opacity)

            case .main:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(BFMotion.smooth, value: flow)
    }
}

// MARK: - Loading background (brief bridging state)
private struct BFLoadingBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0F2B5B"), Color(hex: "#1A3F82"), Color(hex: "#00B4A0")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                LogoMark(size: 64)
                ProgressView().tint(.white)
            }
        }
    }
}
