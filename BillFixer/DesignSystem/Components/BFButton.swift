import SwiftUI

/// The one button used across the app (Figma `Button`: navy · blue · teal · amber · outline · ghost, md 48 / lg 56).
struct BFButton: View {
    enum Kind { case navy, blue, teal, amber, premium, black, outline, ghost, destructive, white }
    enum Size { case md, lg, sm
        var height: CGFloat { switch self { case .sm: 38; case .md: 48; case .lg: 56 } }
        var font: Font { switch self { case .sm: BFFont.label(14); case .md: BFFont.label(15); case .lg: BFFont.label(16) } }
    }

    let title: String
    var icon: String? = nil
    var trailingIcon: String? = nil
    var kind: Kind = .navy
    var size: Size = .lg
    var isLoading = false
    var isDisabled = false
    var fullWidth = true
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button {
            guard !isLoading, !isDisabled else { return }
            action()
        } label: {
            HStack(spacing: 9) {
                if isLoading {
                    ProgressView().tint(foreground).transition(.scale.combined(with: .opacity))
                } else {
                    if let icon { Image(systemName: icon).font(.system(size: size == .sm ? 13 : 16, weight: .semibold)) }
                    Text(title).lineLimit(1).minimumScaleFactor(0.8)
                    if let trailingIcon { Image(systemName: trailingIcon).font(.system(size: 13, weight: .bold)) }
                }
            }
            .font(size.font)
            .foregroundStyle(foreground)
            .padding(.horizontal, size == .sm ? 14 : 20)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: size.height)
            .background(background, in: RoundedRectangle(cornerRadius: size == .sm ? 12 : 18, style: .continuous))
            .overlay {
                if kind == .outline {
                    RoundedRectangle(cornerRadius: size == .sm ? 12 : 18, style: .continuous).strokeBorder(BFColor.line, lineWidth: 1.5)
                }
            }
            .bfShadow(shadow)
            .opacity(isDisabled ? 0.45 : 1)
            .animation(BFMotion.snappy, value: isLoading)
        }
        .buttonStyle(.pressable)
        .disabled(isDisabled)
        .accessibilityLabel(isLoading ? "\(title), loading" : title)
    }

    private var foreground: Color {
        switch kind {
        case .outline, .ghost: kind == .ghost ? BFColor.blue : BFColor.text1
        case .white: BFColor.navy
        case .black: scheme == .dark ? .black : .white
        default: .white
        }
    }

    private var background: AnyShapeStyle {
        switch kind {
        case .navy: AnyShapeStyle(LinearGradient(colors: [BFColor.navy, Color(hex: 0x1B5BB5)], startPoint: .leading, endPoint: .trailing))
        case .blue: AnyShapeStyle(BFGradient.blue)
        case .teal: AnyShapeStyle(BFGradient.teal)
        case .amber: AnyShapeStyle(BFGradient.amber)
        case .premium: AnyShapeStyle(BFGradient.premium)
        case .black: AnyShapeStyle(scheme == .dark ? Color.white : Color.black)
        case .outline: AnyShapeStyle(BFColor.surface)
        case .ghost: AnyShapeStyle(Color.clear)
        case .destructive: AnyShapeStyle(BFColor.red)
        case .white: AnyShapeStyle(Color.white)
        }
    }

    private var shadow: BFShadow {
        switch kind {
        case .navy, .blue: .navyButton
        case .premium, .amber: .gold
        case .outline, .ghost, .white, .black, .teal, .destructive: BFShadow(color: .clear, radius: 0, y: 0)
        }
    }
}

/// Small circular icon button (close, bell, search, ＋).
struct IconButton: View {
    let symbol: String
    var tint: Color = BFColor.text1
    var fill: Color = BFColor.surface
    var size: CGFloat = 40
    var label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(fill, in: Circle())
                .overlay(Circle().strokeBorder(BFColor.line.opacity(0.7), lineWidth: fill == .clear ? 0 : 1))
                .contentShape(Circle())
        }
        .buttonStyle(.pressable)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(label)
    }
}
