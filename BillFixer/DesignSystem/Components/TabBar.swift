import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case home, cases, scan, learn, settings
    var id: Int { rawValue }
    var title: String { ["Home", "Cases", "Scan", "Learn", "Settings"][rawValue] }
    var symbol: String { ["house.fill", "folder", "plus", "sparkles", "gearshape"][rawValue] }
}

// MARK: - BFTabBar
// Floating rounded pill: white in light mode, deep-navy glass in dark mode.
// Active tab: its own bright color in a filled circle with a soft halo.
// Center Scan: elevated gradient circle with plus, offset up.
// Glow/fill circles are always rendered and faded with opacity — no matchedGeometryEffect
// (a conditional matchedGeometryEffect caused the "invalid reuse after initialization failure" crash).

struct BFTabBar: View {
    @Binding var selection: AppTab
    let onScan: () -> Void
    @Environment(\.colorScheme) private var scheme

    private let leftTabs: [AppTab]  = [.home, .cases]
    private let rightTabs: [AppTab] = [.learn, .settings]
    private var dark: Bool { scheme == .dark }
    private var inactive: Color { dark ? Color(hex: 0x8E9CBD) : Color(hex: 0x8A97B0) }

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                ForEach(leftTabs)  { tab in tabItem(tab) }
                Spacer().frame(width: 84)
                ForEach(rightTabs) { tab in tabItem(tab) }
            }
            .padding(.horizontal, 6)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .background(pill)
            .padding(.horizontal, 16)

            scanButton.offset(y: -22)
        }
        .padding(.bottom, 6)
    }

    private var pill: some View {
        RoundedRectangle(cornerRadius: 36, style: .continuous)
            .fill(dark
                  ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x223262), Color(hex: 0x141D3C)], startPoint: .top, endPoint: .bottom))
                  : AnyShapeStyle(Color.white))
            .overlay(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .strokeBorder(LinearGradient(colors: dark ? [.white.opacity(0.24), .white.opacity(0.05)] : [Color(hex: 0xDCE7FF), .white],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 1)
            )
            .shadow(color: dark ? .black.opacity(0.55) : Color(hex: 0x2468FF).opacity(0.14), radius: 26, y: 10)
            .shadow(color: .black.opacity(dark ? 0.3 : 0.08), radius: 6, y: 2)
    }

    private var scanButton: some View {
        Button {
            Haptics.tap()
            onScan()
        } label: {
            ZStack {
                Circle().fill(Color(hex: 0x4F8BFF).opacity(dark ? 0.28 : 0.2)).frame(width: 78, height: 78)
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: 0x4F9BFF), Color(hex: 0x2468FF), Color(hex: 0x6D5BFF)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 62, height: 62)
                    .overlay(Circle().strokeBorder(.white.opacity(dark ? 0.35 : 0.85), lineWidth: 2.5))
                    .shadow(color: Color(hex: 0x3B8BFF).opacity(0.6), radius: 18, y: 8)
                Image(systemName: "plus").font(.system(size: 28, weight: .black)).foregroundStyle(.white)
            }
        }
        .buttonStyle(.pressableQuiet)
        .accessibilityLabel("Scan a medical bill")
    }

    // MARK: - Individual tab item

    private func tabItem(_ tab: AppTab) -> some View {
        let isActive = selection == tab
        let activeColor: Color = switch tab {
            case .home:     Color(hex: dark ? 0x2EE6C9 : 0x00BFA5)
            case .cases:    Color(hex: dark ? 0x6FA8FF : 0x2468FF)
            case .learn:    Color(hex: dark ? 0xB3A6FF : 0x7C5CFF)
            case .settings: Color(hex: dark ? 0xFFB547 : 0xF59E0B)
            default:        Color(hex: 0x2468FF)
        }
        return Button {
            guard selection != tab else { return }
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) { selection = tab }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(activeColor.opacity(dark ? 0.26 : 0.18))
                        .frame(width: 52, height: 52)
                        .opacity(isActive ? 1 : 0)
                        .scaleEffect(isActive ? 1 : 0.6)
                    Circle()
                        .fill(LinearGradient(colors: [activeColor.opacity(0.85), activeColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 42, height: 42)
                        .shadow(color: activeColor.opacity(0.5), radius: 8, y: 3)
                        .opacity(isActive ? 1 : 0)
                        .scaleEffect(isActive ? 1 : 0.5)
                    Image(systemName: tab.symbol)
                        .font(.system(size: isActive ? 17 : 18, weight: .semibold))
                        .foregroundStyle(isActive ? .white : inactive)
                        .scaleEffect(isActive ? 1.05 : 1.0)
                }
                .frame(width: 52, height: 44)
                .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isActive)

                Text(tab.title)
                    .font(.system(size: 10, weight: isActive ? .bold : .semibold))
                    .foregroundStyle(isActive ? activeColor : inactive)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
    }
}
