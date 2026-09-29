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
            // ── Floating white pill card (always light) ──────────────────
            HStack(spacing: 0) {
                ForEach(leftTabs)  { tab in tabItem(tab) }
                Spacer().frame(width: 84)
                ForEach(rightTabs) { tab in tabItem(tab) }
            }
            .padding(.horizontal, 6)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .background(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color(hex: 0x2E7DF6).opacity(0.10), radius: 30, y: 10)
                    .shadow(color: .black.opacity(0.10), radius: 8, y: 2)
            )
            .padding(.horizontal, 16)
            .colorScheme(.light)               // ← ALWAYS light, never goes dark

            // ── Center Scan — electric blue, elevated ─────────────────────
            Button {
                Haptics.tap()
                onScan()
            } label: {
                ZStack {
                    // Outer glow ring
                    Circle()
                        .fill(Color(hex: 0x3B8BFF).opacity(0.20))
                        .frame(width: 76, height: 76)
                    // Main button
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x3B8BFF), Color(hex: 0x1A5FE0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 62, height: 62)
                        .shadow(color: Color(hex: 0x3B8BFF).opacity(0.60), radius: 18, y: 8)
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.pressableQuiet)
            .offset(y: -22)
            .accessibilityLabel("Scan a medical bill")
        }
        .padding(.bottom, 6)
    }

    // MARK: - Individual tab item

    private func tabItem(_ tab: AppTab) -> some View {
        let isActive = selection == tab
        // Vivid per-tab accent colors
        let activeColor: Color = switch tab {
            case .home:     Color(hex: 0x00BFA5)   // vivid teal
            case .cases:    Color(hex: 0x2E7DF6)   // bright blue
            case .learn:    Color(hex: 0x8B5CF6)   // vivid violet
            case .settings: Color(hex: 0x00BFA5)   // vivid teal
            default:        Color(hex: 0x2E7DF6)
        }
        return Button {
            guard selection != tab else { return }
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) { selection = tab }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    // Glow ring behind active circle
                    if isActive {
                        Circle()
                            .fill(activeColor.opacity(0.18))
                            .frame(width: 52, height: 52)
                            .matchedGeometryEffect(id: "tabGlow", in: ns)
                    }
                    // Active fill circle
                    if isActive {
                        Circle()
                            .fill(activeColor)
                            .frame(width: 42, height: 42)
                            .shadow(color: activeColor.opacity(0.45), radius: 8, y: 3)
                            .matchedGeometryEffect(id: "tabCircle", in: ns)
                    }
                    Image(systemName: tab.symbol)
                        .font(.system(size: isActive ? 17 : 18, weight: .semibold))
                        .foregroundStyle(isActive ? .white : Color(hex: 0xA0AEC0))
                        .symbolEffect(.bounce, value: isActive)
                        .scaleEffect(isActive ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)
                }
                .frame(width: 52, height: 44)

                Text(tab.title)
                    .font(.system(size: 10, weight: isActive ? .bold : .semibold))
                    .foregroundStyle(isActive ? activeColor : Color(hex: 0xA0AEC0))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
    }
}
