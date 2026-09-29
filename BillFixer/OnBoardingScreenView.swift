//
//  OnBoardingScreenView.swift
//  BillFixer — First-launch onboarding with circular design elements
//

import SwiftUI

struct OnBoardingScreenView: View {
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentPage = 0
    @State private var appeared = false

    private struct Page {
        let icon: String
        let iconColors: [Color]
        let title: String
        let body: String
        let accentColor: Color
        let bgColors: [Color]
    }

    private let pages: [Page] = [
        Page(
            icon: "doc.text.viewfinder",
            iconColors: [Color(hex: "#0F2B5B"), Color(hex: "#1A3F82")],
            title: "Scan your medical bill",
            body: "Photo, PDF, or camera — Bill Fixer reads your bill so you don't have to decode medical jargon alone.",
            accentColor: Color(hex: "#0F2B5B"),
            bgColors: [Color(hex: "#EEF2FF"), Color(hex: "#E8F0FF")]
        ),
        Page(
            icon: "magnifyingglass.circle.fill",
            iconColors: [Color(hex: "#00897B"), Color(hex: "#00B4A0")],
            title: "We find potential issues",
            body: "We check the math, find duplicate charges, compare your EOB, and look up your hospital's published prices.",
            accentColor: Color(hex: "#00897B"),
            bgColors: [Color(hex: "#E8F8F5"), Color(hex: "#F0FBF9")]
        ),
        Page(
            icon: "checkmark.seal.fill",
            iconColors: [Color(hex: "#1B5E20"), Color(hex: "#2E7D32")],
            title: "Get a plan and take action",
            body: "Dispute letters, phone scripts, deadline tracking — everything you need to take back control of your bill.",
            accentColor: Color(hex: "#1B5E20"),
            bgColors: [Color(hex: "#F0FFF4"), Color(hex: "#E8F5E9")]
        ),
    ]

    private var page: Page { pages[currentPage] }

    var body: some View {
        ZStack {
            // ── Background gradient (changes per page) ───────────────────
            LinearGradient(
                colors: page.bgColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(reduceMotion ? nil : BFMotion.slow, value: currentPage)

            // ── Circular decorations ──────────────────────────────────────
            circleDecorations

            // ── Main layout ──────────────────────────────────────────────
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#0F2B5B"), Color(hex: "#00B4A0")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
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
                    if currentPage < pages.count - 1 {
                        Button("Skip", action: finish)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: "#718096"))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer()

                // Large circular icon
                ZStack {
                    // Outer ring (subtle)
                    Circle()
                        .strokeBorder(page.accentColor.opacity(0.15), lineWidth: 2)
                        .frame(width: 170, height: 170)

                    // Mid ring
                    Circle()
                        .fill(page.accentColor.opacity(0.08))
                        .frame(width: 148, height: 148)

                    // Main circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: page.iconColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 118, height: 118)
                        .shadow(color: page.iconColors.last!.opacity(0.35), radius: 24, y: 10)

                    Image(systemName: page.icon)
                        .font(.system(size: 48, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                }
                .scaleEffect(appeared ? 1 : 0.7)
                .opacity(appeared ? 1 : 0)
                .animation(reduceMotion ? .linear(duration: 0.15) :
                    .spring(response: 0.55, dampingFraction: 0.72), value: appeared)
                .animation(reduceMotion ? .linear(duration: 0.15) :
                    .spring(response: 0.45, dampingFraction: 0.68), value: currentPage)

                Spacer().frame(height: 36)

                // Text content
                VStack(spacing: 14) {
                    Text(page.title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "#1A202C"))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .id("title_\(currentPage)")
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                    Text(page.body)
                        .font(.system(size: 16.5, weight: .regular))
                        .foregroundStyle(Color(hex: "#4A5568"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .id("body_\(currentPage)")
                        .transition(.opacity)
                }
                .padding(.horizontal, 30)
                .animation(reduceMotion ? nil : BFMotion.gentle, value: currentPage)

                Spacer().frame(height: 32)

                // Page dots
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? page.accentColor : Color(hex: "#CBD5E0"))
                            .frame(width: i == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
                    }
                }

                Spacer()

                // CTA button
                Button(action: advance) {
                    HStack(spacing: 10) {
                        Text(currentPage == pages.count - 1 ? "Get Started" : "Next")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                        Image(systemName: currentPage == pages.count - 1 ? "checkmark" : "arrow.right")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: page.iconColors,
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: page.accentColor.opacity(0.35), radius: 16, y: 8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.bottom, 50)
                .scaleEffect(appeared ? 1 : 0.9)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? .linear(duration: 0.15) :
                .spring(response: 0.6, dampingFraction: 0.75)) {
                appeared = true
            }
        }
        .onChange(of: currentPage) { _, _ in
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    // MARK: - Circular background decorations

    private var circleDecorations: some View {
        ZStack {
            Circle()
                .fill(page.accentColor.opacity(0.06))
                .frame(width: 300, height: 300)
                .offset(x: 160, y: -180)
                .animation(reduceMotion ? nil : BFMotion.slow, value: currentPage)

            Circle()
                .fill(page.accentColor.opacity(0.05))
                .frame(width: 220, height: 220)
                .offset(x: -130, y: 280)
                .animation(reduceMotion ? nil : BFMotion.slow, value: currentPage)

            Circle()
                .strokeBorder(page.accentColor.opacity(0.08), lineWidth: 1)
                .frame(width: 180, height: 180)
                .offset(x: -150, y: -120)
                .animation(reduceMotion ? nil : BFMotion.slow, value: currentPage)
        }
    }

    // MARK: - Actions

    private func advance() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if currentPage < pages.count - 1 {
            withAnimation(reduceMotion ? .linear(duration: 0.12) : BFMotion.gentle) {
                currentPage += 1
            }
        } else {
            finish()
        }
    }

    private func finish() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(BFMotion.smooth) {
            settings.hasSeenOnboarding = true
        }
    }
}

#Preview {
    OnBoardingScreenView()
        .environmentObject(SettingsManager())
}
