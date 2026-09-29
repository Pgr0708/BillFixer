import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case home, cases, scan, learn, settings
    var id: Int { rawValue }
    var title: String { ["Home", "Cases", "Scan", "Learn", "Settings"][rawValue] }
    var symbol: String { ["house.fill", "folder", "plus", "sparkles", "gearshape"][rawValue] }
}

// MARK: - BFTabBar — matches the Claude design image exactly
// Layout: floating white rounded-pill card
// Active tab: teal filled circle background
// Center Scan: elevated large blue filled circle with plus, offset up
// Inactive: gray icon + gray label

struct BFTabBar: View {
    @Binding var selection: AppTab
    let onScan: () -> Void
    @Namespace private var ns

    // Only non-scan tabs (2 left, 2 right)
    private let leftTabs: [AppTab]  = [.home, .cases]
    private let rightTabs: [AppTab] = [.learn, .settings]

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Floating pill card ───────────────────────────────────────
            HStack(spacing: 0) {
                // Left side: Home, Cases
                ForEach(leftTabs) { tab in
                    tabItem(tab)
                }

                // Center gap for the elevated scan button
                Spacer().frame(width: 80)

                // Right side: Learn, Settings
                ForEach(rightTabs) { tab in
                    tabItem(tab)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.12), radius: 24, y: 8)
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            )
            .padding(.horizontal, 20)

            // ── Elevated center Scan button (overlaps the pill) ──────────
            Button {
                Haptics.tap()
                onScan()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x2E7DF6), Color(hex: 0x0B2B5C)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: Color(hex: 0x2E7DF6).opacity(0.45), radius: 16, y: 6)

                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.pressableQuiet)
            .offset(y: -20)
            .accessibilityLabel("Scan a medical bill")
        }
        .padding(.bottom, 8)
    }

    // MARK: - Individual tab item

    private func tabItem(_ tab: AppTab) -> some View {
        let isActive = selection == tab
        return Button {
            guard selection != tab else { return }
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    // Active background circle
                    if isActive {
                        Circle()
                            .fill(BFColor.teal)
                            .frame(width: 44, height: 44)
                            .matchedGeometryEffect(id: "tabCircle", in: ns)
                    }

                    Image(systemName: tab.symbol)
                        .font(.system(size: isActive ? 18 : 19, weight: .semibold))
                        .foregroundStyle(isActive ? .white : BFColor.text3)
                        .symbolEffect(.bounce, value: isActive)
                }
                .frame(width: 44, height: 44)

                Text(tab.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isActive ? BFColor.teal : BFColor.text3)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
    }
}
