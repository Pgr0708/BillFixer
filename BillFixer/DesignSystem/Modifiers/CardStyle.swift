import SwiftUI

struct CardStyle: ViewModifier {
    var padding: CGFloat = BFSpacing.md
    var radius: CGFloat = BFRadius.md
    var fill: Color = BFColor.surface
    var stroke: Color? = nil
    var shadow: BFShadow? = .card

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                if let stroke {
                    RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(stroke, lineWidth: 1)
                }
            }
            .modifier(OptionalShadow(shadow: shadow))
    }
}

private struct OptionalShadow: ViewModifier {
    let shadow: BFShadow?
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        if let shadow, scheme == .light { content.bfShadow(shadow) } else { content }
    }
}

extension View {
    func cardStyle(padding: CGFloat = BFSpacing.md, radius: CGFloat = BFRadius.md, fill: Color = BFColor.surface,
                   stroke: Color? = nil, shadow: BFShadow? = .card) -> some View {
        modifier(CardStyle(padding: padding, radius: radius, fill: fill, stroke: stroke ?? BFColor.line.opacity(0.6), shadow: shadow))
    }

    /// Frosted glass for content over photographs and gradients.
    func glassCard(radius: CGFloat = BFRadius.lg, dark: Bool = false) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(dark ? AnyShapeStyle(Color.black.opacity(0.28)) : AnyShapeStyle(Color.white.opacity(0.16)))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
        }
    }
}
