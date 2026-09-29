import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case home, cases, scan, learn, settings
    var id: Int { rawValue }
    var title: String { ["Home", "Cases", "Scan", "Learn", "Settings"][rawValue] }
    var symbol: String { ["house.fill", "folder.fill", "doc.viewfinder", "book.fill", "gearshape.fill"][rawValue] }
}

/// Custom tab bar (Figma `TabBar`) with a raised Scan button in the middle.
struct BFTabBar: View {
    @Binding var selection: AppTab
    let onScan: () -> Void
    @Namespace private var indicator

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                if tab == .scan {
                    Button { Haptics.tap(); onScan() } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 58, height: 58)
                                .background(LinearGradient(colors: [Color(hex: 0x2E7DF6), BFColor.navy], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                                .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 3))
                                .bfShadow(.navyButton)
                            Text(tab.title).font(.system(size: 10, weight: .semibold)).foregroundStyle(BFColor.text3)
                        }
                        .offset(y: -14)
                    }
                    .buttonStyle(.pressableQuiet)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Scan a medical bill")
                } else {
                    Button {
                        guard selection != tab else { return }
                        Haptics.selection()
                        withAnimation(BFMotion.snappy) { selection = tab }
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                if selection == tab {
                                    Capsule().fill(BFColor.blueSoft).frame(width: 52, height: 30).matchedGeometryEffect(id: "pill", in: indicator)
                                }
                                Image(systemName: tab.symbol).font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(selection == tab ? BFColor.blue : BFColor.text3)
                                    .symbolEffect(.bounce, value: selection == tab)
                            }
                            .frame(height: 30)
                            Text(tab.title).font(.system(size: 10, weight: .semibold)).foregroundStyle(selection == tab ? BFColor.blue : BFColor.text3)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                    .accessibilityAddTraits(selection == tab ? [.isSelected, .isButton] : .isButton)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background {
            Rectangle().fill(.regularMaterial)
                .overlay(alignment: .top) { Rectangle().fill(BFColor.line).frame(height: 0.5) }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
