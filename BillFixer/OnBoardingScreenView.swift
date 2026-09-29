//
//  OnBoardingScreenView.swift
//

import SwiftUI

struct OnBoardingScreenView: View {
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentPage = 0

    private struct Page {
        let image: String
        let title: String
        let body: String
        let scene: ScenicBackground.Scene
    }

    private let pages: [Page] = [
        Page(image: "OnboardingScan", title: "Scan your medical bill",
             body: "Upload a photo, PDF or take a quick scan. We’ll extract the details for you.",
             scene: .auth),
        Page(image: "OnboardingFind", title: "We find potential issues",
             body: "We check the math, find duplicate charges, compare with your EOB, and look up your hospital’s published prices.",
             scene: .results),
        Page(image: "OnboardingAction", title: "Get a plan and take action",
             body: "Receive clear explanations, ready-to-send letters, and phone scripts. Track your progress in one place.",
             scene: .assistance),
    ]

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 8) {
                        LogoMark(size: 30, tile: false)
                        Text("BillFixer").font(BFFont.display(19)).foregroundStyle(BFColor.navy)
                    }
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Skip", action: finish)
                            .font(BFFont.label(15))
                            .foregroundStyle(BFColor.text2)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }
                .padding(.horizontal, 24)

                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { i in
                        pageView(pages[i], height: geo.size.height).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                PageDots(count: pages.count, index: currentPage, active: BFColor.blue)
                    .padding(.bottom, 20)

                BFButton(title: currentPage == pages.count - 1 ? "Get Started" : "Next",
                         trailingIcon: "arrow.right", kind: .navy, action: advance)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }
            .background(ScenicBackground(scene: pages[currentPage].scene).animation(BFMotion.slow, value: currentPage))
            .onChange(of: currentPage) { _, _ in Haptics.selection() }
        }
    }

    private func pageView(_ page: Page, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            GeometryReader { g in
                ZStack {
                    Image(page.image).resizable().scaledToFit().padding(10).floating(amplitude: 4, duration: 3.6).accessibilityHidden(true)
                }
                .frame(width: g.size.width, height: g.size.height)
            }
            .frame(height: max(250, height * 0.46))
            Text(page.title)
                .font(BFFont.title(30))
                .foregroundStyle(BFColor.text1)
                .fixedSize(horizontal: false, vertical: true)
            Text(page.body)
                .font(.system(size: 16.5))
                .foregroundStyle(BFColor.text2)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }

    private func advance() {
        if currentPage < pages.count - 1 {
            withAnimation(reduceMotion ? .linear(duration: 0.12) : BFMotion.gentle) { currentPage += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        Haptics.tap()
        withAnimation(BFMotion.smooth) { settings.hasSeenOnboarding = true }
    }
}
