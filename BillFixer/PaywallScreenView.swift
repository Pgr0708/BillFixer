//
//  PaywallScreenView.swift
//  Board screen 16 — Go Premium.
//

import RevenueCat
import SwiftUI

struct PaywallScreenView: View {
    var reason: PaywallReason = .general
    var isOnboarding = false
    let onFinish: () -> Void

    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var store = SubscriptionManager.shared
    @State private var selected: Package?
    @State private var link: WebLink?

    private let benefits = [
        ("doc.viewfinder", "Unlimited bill & EOB scans"),
        ("building.2.fill", "Hospital price comparisons"),
        ("checklist", "Full analysis with all findings"),
        ("envelope.fill", "All letter templates & phone scripts"),
        ("folder.fill", "Unlimited active cases"),
        ("bell.badge.fill", "Deadline reminders"),
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: [Color(hex: 0x071A3B), BFColor.navy, Color(hex: 0x0B3F66)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            Circle().fill(Color(hex: 0xFFC554).opacity(0.18)).frame(width: 320).blur(radius: 60).offset(x: 120, y: -160)

            ScrollView {
                VStack(spacing: 22) {
                    CrownBadge().padding(.top, 36)
                    VStack(spacing: 8) {
                        Text(reason == .general ? "Go Premium" : reason.headline).font(BFFont.display(32)).foregroundStyle(.white).multilineTextAlignment(.center)
                        Text("Unlock your full bill analysis and take control.").font(.system(size: 16)).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center)
                    }
                    VStack(alignment: .leading, spacing: 13) {
                        ForEach(Array(benefits.enumerated()), id: \.offset) { i, b in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: 0xFFC554))
                                Text(b.1).font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                                Spacer()
                            }
                            .staggeredAppear(i)
                        }
                    }
                    .padding(18)
                    .glassCard(radius: 22, dark: true)

                    plans
                    if let e = store.offeringError { Text(e).font(.system(size: 13)).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center) }

                    BFButton(title: ctaTitle, kind: .premium, isLoading: store.isPurchasing, isDisabled: selected == nil) { Task { await buy() } }
                    footer
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)

            IconButton(symbol: "xmark", tint: .white, fill: .white.opacity(0.15), size: 36, label: "Close") { close() }
                .padding(.trailing, 14).padding(.top, 6)
        }
        .preferredColorScheme(.dark)
        .webSheet($link)
        .task {
            await store.loadOfferings()
            if selected == nil { selected = store.annual ?? store.monthly }
        }
    }

    private var ctaTitle: String {
        guard let selected else { return "Continue" }
        if let intro = selected.storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial { return "Start Free Trial" }
        return selected.packageType == .annual ? "Continue with Annual" : "Continue with Monthly"
    }

    @ViewBuilder
    private var plans: some View {
        if store.isLoadingOfferings {
            ProgressView().tint(.white).frame(height: 120)
        } else {
            HStack(spacing: 12) {
                if let m = store.monthly { planCard(m, title: "Monthly", period: "/month", badge: nil) }
                if let a = store.annual { planCard(a, title: "Annual", period: "/year", badge: store.annualSavingsPercent.map { "Save \($0)%" }) }
            }
        }
    }

    private func planCard(_ p: Package, title: String, period: String, badge: String?) -> some View {
        let on = selected?.identifier == p.identifier
        return Button {
            Haptics.selection()
            withAnimation(BFMotion.snappy) { selected = p }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title).font(BFFont.label(15)).foregroundStyle(.white)
                    Spacer()
                    Image(systemName: on ? "checkmark.circle.fill" : "circle").foregroundStyle(on ? Color(hex: 0xFFC554) : .white.opacity(0.5))
                }
                Text(p.storeProduct.localizedPriceString).font(BFFont.money(24)).foregroundStyle(.white)
                Text(period).font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(on ? Color.white.opacity(0.16) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(on ? Color(hex: 0xFFC554) : .white.opacity(0.15), lineWidth: on ? 2 : 1))
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge).font(.system(size: 11, weight: .heavy)).foregroundStyle(BFColor.navy)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(BFGradient.premium, in: Capsule())
                        .offset(x: -8, y: -11)
                }
            }
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Text("Auto-renews until cancelled. Cancel anytime in Settings › Apple ID › Subscriptions.")
                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
            HStack(spacing: 18) {
                Button("Restore") { Task { await restore() } }
                Button("Terms") { link = .terms }
                Button("Privacy") { link = .privacy }
            }
            .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
            if isOnboarding {
                Button("Continue with Free Plan") { close() }.font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.7)).padding(.top, 4)
            }
        }
    }

    private func close() {
        Haptics.tapLight()
        if isOnboarding { onFinish() } else { dismiss() }
    }

    private func buy() async {
        guard let selected else { return }
        switch await store.purchase(selected) {
        case .purchased:
            await session.syncSubscription()
            Toast.success("Premium is active", "All features are unlocked.")
            onFinish()
        case .pending: Toast.info("Purchase pending", "We’ll unlock Premium as soon as it’s approved.")
        case .cancelled: break
        case let .failed(message): Toast.error("Purchase couldn’t be completed", message)
        }
    }

    private func restore() async {
        switch await store.restore() {
        case true?:
            await session.syncSubscription()
            Toast.success("Purchases restored")
            onFinish()
        case false?: Toast.info("No active subscription found")
        case nil: Toast.error("Couldn’t restore purchases", "Check your connection and try again.")
        }
    }
}
