import SwiftUI

struct IconTile: View {
    let symbol: String
    var tint: Color = BFColor.blue
    var fill: Color = BFColor.blueSoft
    var size: CGFloat = 44
    var radius: CGFloat = 14   // kept for call-site compatibility; tiles are circular

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(LinearGradient(colors: [fill, fill.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Circle().fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center)))
                    .overlay(Circle().strokeBorder(tint.opacity(0.28), lineWidth: 1.2))
                    .shadow(color: tint.opacity(0.22), radius: size * 0.14, y: size * 0.06)
            }
            .accessibilityHidden(true)
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(BFFont.title3(18)).foregroundStyle(BFColor.text1)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle) { Haptics.selection(); action() }
                    .font(BFFont.label(14))
                    .foregroundStyle(BFColor.blue)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

struct Avatar: View {
    let initial: String
    var size: CGFloat = 44

    var body: some View {
        Text(initial.isEmpty ? "?" : initial)
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [Color(hex: 0x5B9BFF), Color(hex: 0x7C6BFF)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 2))
            .accessibilityHidden(true)
    }
}

struct PageDots: View {
    let count: Int
    let index: Int
    var active: Color = BFColor.teal
    var inactive: Color = BFColor.text4.opacity(0.6)

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? active : inactive)
                    .frame(width: i == index ? 22 : 7, height: 7)
            }
        }
        .animation(BFMotion.snappy, value: index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(index + 1) of \(count)")
    }
}

/// "1 Template — 2 Review — 3 Send"
struct StepIndicator: View {
    let steps: [String]
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                HStack(spacing: 6) {
                    ZStack {
                        Circle().fill(i <= current ? AnyShapeStyle(BFGradient.blue) : AnyShapeStyle(BFColor.line))
                        if i < current {
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                        } else {
                            Text("\(i + 1)").font(.system(size: 11, weight: .bold)).foregroundStyle(i <= current ? .white : BFColor.text3)
                        }
                    }
                    .frame(width: 22, height: 22)
                    Text(step).font(.system(size: 12, weight: .semibold)).foregroundStyle(i <= current ? BFColor.text1 : BFColor.text3)
                        .lineLimit(1).fixedSize()
                }
                if i < steps.count - 1 {
                    Capsule().fill(i < current ? BFColor.blue : BFColor.line).frame(height: 2).frame(maxWidth: .infinity)
                }
            }
        }
        .animation(BFMotion.gentle, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(steps.count): \(steps[min(current, steps.count - 1)])")
    }
}

struct EmptyStateView<Art: View>: View {
    let title: String
    let message: String
    var buttonTitle: String? = nil
    var buttonIcon: String? = nil
    var action: (() -> Void)? = nil
    @ViewBuilder var art: () -> Art

    var body: some View {
        VStack(spacing: 14) {
            art().floating(amplitude: 5)
            Text(title).font(BFFont.warm(26)).foregroundStyle(BFColor.text1).multilineTextAlignment(.center)
            Text(message).font(BFFont.body).foregroundStyle(BFColor.text2).multilineTextAlignment(.center).lineSpacing(3)
            if let buttonTitle, let action {
                BFButton(title: buttonTitle, icon: buttonIcon, kind: .navy, action: action).padding(.top, 8)
            }
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: 440)
    }
}

/// Inline error with retry (network failures, server errors).
struct ErrorStateView: View {
    let error: APIError
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            IconTile(symbol: error == .offline ? "wifi.slash" : "exclamationmark.triangle", tint: BFColor.amber, fill: BFColor.amberSoft, size: 56, radius: 18)
            Text(error.title).font(BFFont.title3()).foregroundStyle(BFColor.text1)
            Text(error.message).font(BFFont.subheadline).foregroundStyle(BFColor.text2).multilineTextAlignment(.center)
            BFButton(title: "Try Again", icon: "arrow.clockwise", kind: .outline, size: .md, fullWidth: false, action: retry)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash").font(.system(size: 13, weight: .bold))
            Text("You’re offline — showing saved data").font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(BFColor.navy.opacity(0.92), in: Capsule())
        .bfShadow(.float)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityAddTraits(.isStaticText)
    }
}

struct SkeletonBlock: View {
    var height: CGFloat = 16
    var radius: CGFloat = 8
    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(BFColor.line.opacity(0.8))
            .frame(height: height)
            .shimmer()
            .accessibilityHidden(true)
    }
}

struct SkeletonList: View {
    var rows = 3
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: 12) {
                    SkeletonBlock(height: 44, radius: 14).frame(width: 44)
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(height: 14).frame(maxWidth: 180)
                        SkeletonBlock(height: 10).frame(maxWidth: 110)
                    }
                    Spacer()
                    SkeletonBlock(height: 18).frame(width: 60)
                }
                .cardStyle()
            }
        }
        .accessibilityLabel("Loading")
    }
}
