//
//  PaywallScreenView.swift
//  BillFixer — Premium paywall with circular design
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
    @State private var appeared = false

    private let benefits: [(String, Color, String)] = [
        ("doc.viewfinder",      Color(hex: 0x2E7DF6), "Unlimited bill & EOB scans"),
        ("building.2.fill",     Color(hex: 0x00BFA5), "Hospital price comparisons"),
        ("checklist",           Color(hex: 0xFFC554), "Full analysis — every finding"),
        ("envelope.fill",       Color(hex: 0x8A2BE2), "Dispute letters & phone scripts"),
        ("folder.fill",         Color(hex: 0x22C07A), "Unlimited active cases"),
        ("bell.badge.fill",     Color(hex: 0xEF4444), "Deadline reminders"),
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // ── Dark navy gradient background ────────────────────────────
            LinearGradient(
                colors: [Color(hex: 0x050F20), Color(hex: 0x0B2B5C), Color(hex: 0x0A1F3A)],
                startPoint: .top, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // ── Circular decorations ─────────────────────────────────────
            paywallCircles

            ScrollView {
                VStack(spacing: 24) {

                    // Crown badge
                    crownBadge
                        .padding(.top, 40)
                        .scaleEffect(appeared ? 1 : 0.6)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: appeared)

                    // Headline
                    VStack(spacing: 8) {
                        Text(reason == .general ? "Go Premium" : reason.headline)
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Text("Unlock your full bill analysis and take control.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: appeared)

                    // Benefits — circular icon rows
                    benefitsList
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: appeared)

                    // Plan cards
                    plans
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.22), value: appeared)

                    if let e = store.offeringError {
                        Text(e)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }

                    // CTA
                    ctaButton
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.28), value: appeared)

                    footer
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeIn(duration: 0.3).delay(0.35), value: appeared)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)

            // Close button (circular)
            Button { close() } label: {
                Circle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
            }
            .buttonStyle(.pressable)
            .padding(.trailing, 16)
            .padding(.top, 12)
            .accessibilityLabel("Close")
        }
        .preferredColorScheme(.dark)
        .webSheet($link)
        .onAppear {
            withAnimation { appeared = true }
        }
        .task {
            await store.loadOfferings()
            if selected == nil { selected = store.annual ?? store.monthly }
        }
    }

    // MARK: - Crown badge

    private var crownBadge: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(Color(hex: 0xFFC554).opacity(0.10))
                .frame(width: 120, height: 120)
            Circle()
                .fill(Color(hex: 0xFFC554).opacity(0.08))
                .frame(width: 100, height: 100)
            // Main circle
            Circle()
                .fill(LinearGradient(
                    colors: [Color(hex: 0xFFC554), Color(hex: 0xF5A623)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 80, height: 80)
                .shadow(color: Color(hex: 0xFFC554).opacity(0.5), radius: 20, y: 6)
            Image(systemName: "crown.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Benefits list

    private var benefitsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(benefits.enumerated()), id: \.offset) { i, b in
                HStack(spacing: 14) {
                    // Circular icon
                    Circle()
                        .fill(b.1.opacity(0.18))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: b.0)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(b.1)
                        }
                    Text(b.2)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                    Spacer()
                    // Gold checkmark circle
                    Circle()
                        .fill(Color(hex: 0xFFC554).opacity(0.2))
                        .frame(width: 24, height: 24)
                        .overlay {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(hex: 0xFFC554))
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .opacity(appeared ? 1 : 0)
                .offset(x: appeared ? 0 : -20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8)
                    .delay(0.18 + Double(i) * 0.05), value: appeared)

                if i < benefits.count - 1 {
                    Divider()
                        .background(.white.opacity(0.1))
                        .padding(.leading, 70)
                }
            }
        }
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Plan cards

    @ViewBuilder
    private var plans: some View {
        if store.isLoadingOfferings {
            ProgressView().tint(.white).frame(height: 120)
        } else {
            HStack(spacing: 12) {
                if let m = store.monthly  { planCard(m, title: "Monthly",  period: "/month", badge: nil) }
                if let a = store.annual   { planCard(a, title: "Annual",   period: "/year",  badge: store.annualSavingsPercent.map { "Save \($0)%" }) }
            }
        }
    }

    private func planCard(_ p: Package, title: String, period: String, badge: String?) -> some View {
        let isOn = selected?.identifier == p.identifier
        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { selected = p }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    // Circular check
                    ZStack {
                        Circle()
                            .fill(isOn ? Color(hex: 0xFFC554) : .white.opacity(0.15))
                            .frame(width: 24, height: 24)
                        if isOn {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(BFColor.navy)
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isOn)
                }
                Text(p.storeProduct.localizedPriceString)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(period)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isOn ? .white.opacity(0.15) : .white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isOn ? Color(hex: 0xFFC554) : .white.opacity(0.12),
                                  lineWidth: isOn ? 2 : 1)
            )
            .shadow(color: isOn ? Color(hex: 0xFFC554).opacity(0.2) : .clear, radius: 12, y: 4)
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(BFColor.navy)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(
                            LinearGradient(colors: [Color(hex: 0xFFC554), Color(hex: 0xF5A623)],
                                           startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                        .offset(x: -8, y: -11)
                }
            }
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button { Task { await buy() } } label: {
            Group {
                if store.isPurchasing {
                    ProgressView().tint(BFColor.navy)
                } else {
                    HStack(spacing: 10) {
                        Text(ctaTitle)
                            .font(.system(size: 17, weight: .black, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .bold))
                    }
                }
            }
            .foregroundStyle(BFColor.navy)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                LinearGradient(colors: [Color(hex: 0xFFC554), Color(hex: 0xF5A623)],
                               startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(Capsule())
            .shadow(color: Color(hex: 0xFFC554).opacity(0.45), radius: 20, y: 8)
        }
        .buttonStyle(.pressable)
        .disabled(selected == nil || store.isPurchasing)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            Text("Auto-renews until cancelled. Cancel anytime in Settings › Apple ID › Subscriptions.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            HStack(spacing: 20) {
                Button("Restore") { Task { await restore() } }
                Button("Terms")   { link = .terms }
                Button("Privacy") { link = .privacy }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.7))
            if isOnboarding {
                Button("Continue with Free Plan") { close() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Circle decorations

    private var paywallCircles: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0xFFC554).opacity(0.12))
                .frame(width: 350)
                .blur(radius: 60)
                .offset(x: 140, y: -180)
            Circle()
                .fill(Color(hex: 0x2E7DF6).opacity(0.08))
                .frame(width: 280)
                .blur(radius: 50)
                .offset(x: -130, y: 350)
            Circle()
                .strokeBorder(.white.opacity(0.04), lineWidth: 1)
                .frame(width: 220)
                .offset(x: 130, y: 250)
        }
    }

    // MARK: - Computed

    private var ctaTitle: String {
        guard let selected else { return "Continue" }
        if let intro = selected.storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial {
            return "Start Free Trial"
        }
        return selected.packageType == .annual ? "Continue with Annual" : "Continue with Monthly"
    }

    // MARK: - Actions

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
        case .pending:   Toast.info("Purchase pending", "We'll unlock Premium as soon as it's approved.")
        case .cancelled: break
        case let .failed(message): Toast.error("Purchase couldn't be completed", message)
        }
    }

    private func restore() async {
        switch await store.restore() {
        case true?:
            await session.syncSubscription()
            Toast.success("Purchases restored")
            onFinish()
        case false?: Toast.info("No active subscription found")
        case nil:    Toast.error("Couldn't restore purchases", "Check your connection and try again.")
        }
    }
}
