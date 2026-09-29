//
//  OnBoardingScreenView.swift
//  BillFixer — First-launch onboarding: illustrations on colorful circle stacks.
//

import SwiftUI

struct OnBoardingScreenView: View {
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @State private var currentPage = 0
    @State private var appeared = false
    @State private var orbit = false

    private struct Page {
        let image: String
        let title: String
        let body: String
        /// Disc gradient + accent for rings, dots and the CTA.
        let colors: [UInt32]
        let accent: UInt32
        let orbs: [UInt32]
        let button: [UInt32]
    }

    private let pages: [Page] = [
        Page(image: "OnboardingScan", title: "Scan your medical bill",
             body: "Upload a photo, PDF or take a quick scan. We’ll extract the details for you.",
             colors: [0x6FA8FF, 0x2EE6C9], accent: 0x2468FF, orbs: [0xFFC554, 0x19D3B5, 0x9B8CFF], button: [0x2468FF, 0x6D5BFF]),
        Page(image: "OnboardingFind", title: "We find potential issues",
             body: "We check the math, find duplicate charges, compare with your EOB, and look up your hospital’s published prices.",
             colors: [0xFFE08A, 0xFFA94D], accent: 0xF59E0B, orbs: [0x2468FF, 0xFF7A7A, 0x19D3B5], button: [0xFFB020, 0xFF7A2E]),
        Page(image: "OnboardingAction", title: "Get a plan and take action",
             body: "Receive clear explanations, ready-to-send letters, and phone scripts. Track your progress in one place.",
             colors: [0x7FF0DC, 0x3BCB9A], accent: 0x00A88F, orbs: [0x2468FF, 0xFFC554, 0x6D5BFF], button: [0x00BFA5, 0x0E9F7E]),
    ]

    private var page: Page { pages[currentPage] }
    private var dark: Bool { scheme == .dark }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 8)
                illustration
                Spacer(minLength: 20)
                text
                Spacer(minLength: 20)
                PageDots(count: pages.count, index: currentPage, active: Color(hex: page.accent), inactive: Color(hex: dark ? 0x3A4768 : 0xCBD5E0))
                Spacer(minLength: 20)
                cta
            }
        }
        .contentShape(Rectangle())
        .gesture(swipe)
        .onAppear {
            withAnimation(reduceMotion ? .linear(duration: 0.15) : .spring(response: 0.6, dampingFraction: 0.75)) { appeared = true }
            if !reduceMotion { withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) { orbit = true } }
        }
        .onChange(of: currentPage) { _, _ in Haptics.selection() }
    }

    // MARK: - Pieces

    private var background: some View {
        ZStack {
            LinearGradient(colors: dark ? [Color(hex: 0x0B1636), Color(hex: 0x0A1024)]
                                        : [Color(hex: page.colors[0]).opacity(0.18), Color(hex: 0xF7FAFF), Color(hex: page.colors[1]).opacity(0.14)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            // Corner circles pick up the page palette.
            Circle().fill(Color(hex: page.colors[0]).opacity(dark ? 0.14 : 0.38)).frame(width: 320).offset(x: 170, y: -330)
            Circle().fill(Color(hex: page.colors[1]).opacity(dark ? 0.12 : 0.34)).frame(width: 240).offset(x: -170, y: 340)
            Circle().strokeBorder(Color(hex: page.accent).opacity(0.25), lineWidth: 1.5).frame(width: 200).offset(x: -160, y: -250)
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : BFMotion.slow, value: currentPage)
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 8) {
                LogoMark(size: 34, tile: false)
                Text("BillFixer").font(BFFont.display(19)).foregroundStyle(dark ? .white : BFColor.navy)
            }
            Spacer()
            if currentPage < pages.count - 1 {
                Button("Skip", action: finish)
                    .font(BFFont.label(15))
                    .foregroundStyle(BFColor.text2)
                    .frame(minWidth: 44, minHeight: 44)
                    .buttonStyle(.pressable)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private var illustration: some View {
        GeometryReader { g in
            let d = min(g.size.width, g.size.height)
            ZStack {
                // Rings
                Circle().strokeBorder(Color(hex: page.accent).opacity(0.35), lineWidth: 2).frame(width: d * 0.98)
                Circle().strokeBorder(Color(hex: page.accent).opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [4, 8])).frame(width: d * 0.84)
                    .rotationEffect(.degrees(orbit ? 360 : 0))
                // Colorful disc
                Circle()
                    .fill(LinearGradient(colors: page.colors.map { Color(hex: $0).opacity(dark ? 0.95 : 0.8) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Circle().fill(RadialGradient(colors: [.white.opacity(dark ? 0.12 : 0.4), .clear], center: .topLeading, startRadius: 0, endRadius: d * 0.5)))
                    .frame(width: d * 0.78)
                    .shadow(color: Color(hex: page.accent).opacity(0.3), radius: 30, y: 14)
                // Orbiting dots
                ForEach(Array(page.orbs.enumerated()), id: \.offset) { i, c in
                    Circle().fill(Color(hex: c)).frame(width: [16, 11, 13][i])
                        .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 2))
                        .offset(y: -d * 0.42)
                        .rotationEffect(.degrees(Double(i) * 120 + (orbit ? 360 : 0)))
                }
                // Illustration
                Image(page.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: d * 0.9, height: d * 0.9)
                    .floating(amplitude: 5, duration: 3.4)
                    .id(page.image)
                    .transition(.asymmetric(insertion: .scale(scale: 0.85).combined(with: .opacity),
                                            removal: .scale(scale: 1.05).combined(with: .opacity)))
                    .accessibilityHidden(true)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .frame(maxHeight: 360)
        .scaleEffect(appeared ? 1 : 0.8)
        .opacity(appeared ? 1 : 0)
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.75), value: currentPage)
    }

    private var text: some View {
        VStack(spacing: 14) {
            Text(page.title)
                .font(BFFont.title(29))
                .foregroundStyle(BFColor.text1)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .id("title_\(currentPage)")
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
            Text(page.body)
                .font(.system(size: 16.5))
                .foregroundStyle(BFColor.text2)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .id("body_\(currentPage)")
                .transition(.opacity)
        }
        .padding(.horizontal, 30)
        .animation(reduceMotion ? nil : BFMotion.gentle, value: currentPage)
    }

    private var cta: some View {
        Button(action: advance) {
            HStack(spacing: 10) {
                Text(currentPage == pages.count - 1 ? "Get Started" : "Next").font(BFFont.label(17))
                Image(systemName: currentPage == pages.count - 1 ? "checkmark" : "arrow.right").font(.system(size: 15, weight: .bold))
                    .contentTransition(.symbolEffect(.replace))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(LinearGradient(colors: page.button.map { Color(hex: $0) },
                                       startPoint: .leading, endPoint: .trailing), in: Capsule())
            .shadow(color: Color(hex: page.accent).opacity(0.4), radius: 16, y: 8)
        }
        .buttonStyle(.pressable)
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .animation(BFMotion.standard, value: currentPage)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24).onEnded { v in
            if v.translation.width < -50, currentPage < pages.count - 1 { go(currentPage + 1) }
            else if v.translation.width > 50, currentPage > 0 { go(currentPage - 1) }
        }
    }

    // MARK: - Actions

    private func go(_ i: Int) {
        withAnimation(reduceMotion ? .linear(duration: 0.12) : BFMotion.gentle) { currentPage = i }
    }

    private func advance() {
        Haptics.tap()
        if currentPage < pages.count - 1 { go(currentPage + 1) } else { finish() }
    }

    private func finish() {
        Haptics.success()
        withAnimation(BFMotion.smooth) { settings.hasSeenOnboarding = true }
    }
}

#Preview {
    OnBoardingScreenView()
        .environmentObject(SettingsManager())
}
