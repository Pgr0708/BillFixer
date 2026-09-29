//
//  SplashScreenView.swift
//

import SwiftUI

struct SplashScreenView: View {
    @Environment(AppSession.self) private var session
    @State private var isActive = false
    @State private var hasAppeared = false
    @State private var taglineIndex = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let taglines = ["Find errors.", "Know your rights.", "Take action."]

    var body: some View {
        if isActive {
            RootView().transition(.opacity)
        } else {
            GeometryReader { geometry in
                ZStack {
                    Image("SplashBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .overlay { LinearGradient(colors: [BFColor.navy.opacity(0.35), .clear, BFColor.navy.opacity(0.25)], startPoint: .top, endPoint: .bottom) }

                    VStack(spacing: 14) {
                        Spacer().frame(height: geometry.safeAreaInsets.top + geometry.size.height * 0.09)
                        LogoMark(size: 84)
                            .scaleEffect(hasAppeared ? 1 : 0.6)
                            .rotationEffect(.degrees(hasAppeared || reduceMotion ? 0 : -12))
                        Text("BillFixer")
                            .font(BFFont.display(40))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                        Text("Your medical bill, decoded.")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white.opacity(0.92))
                        Spacer()
                        VStack(spacing: 6) {
                            ForEach(Array(taglines.enumerated()), id: \.offset) { i, line in
                                Text(line)
                                    .font(BFFont.title3(17))
                                    .foregroundStyle(.white)
                                    .opacity(taglineIndex >= i ? 1 : 0)
                                    .offset(y: taglineIndex >= i ? 0 : 8)
                            }
                        }
                        PageDots(count: 3, index: max(taglineIndex, 0), active: BFColor.teal2, inactive: .white.opacity(0.5))
                            .padding(.top, 14)
                            .padding(.bottom, max(geometry.safeAreaInsets.bottom, 24) + 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(hasAppeared ? 1 : 0)
                }
            }
            .ignoresSafeArea()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("BillFixer. Your medical bill, decoded.")
            .task { await run() }
        }
    }

    private func run() async {
        async let boot: Void = session.bootstrap()
        withAnimation(reduceMotion ? .linear(duration: 0.15) : .spring(response: 0.7, dampingFraction: 0.7)) { hasAppeared = true }
        for i in 0..<3 {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 80 : 330))
            withAnimation(BFMotion.gentle) { taglineIndex = i }
        }
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 450))
        _ = await boot
        withAnimation(.easeInOut(duration: 0.35)) { isActive = true }
    }
}
