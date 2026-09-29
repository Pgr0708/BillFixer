import SwiftUI

/// Card entrance: y+18 → 0 and opacity 0 → 1, staggered by index. Opacity-only under Reduce Motion.
struct StaggeredAppear: ViewModifier {
    let index: Int
    var offset: CGFloat = 18
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : offset)
            .onAppear {
                guard !shown else { return }
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : BFMotion.gentle.delay(BFMotion.stagger(index))) { shown = true }
            }
    }
}

/// Horizontal error shake (4 cycles, 0.4 s) driven by a trigger value.
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 8
    var shakes: CGFloat = 4
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(animatableData * .pi * shakes), y: 0))
    }
}

/// Moving highlight for loading skeletons (1.5 s loop).
struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.overlay {
            if !reduceMotion {
                GeometryReader { geo in
                    LinearGradient(colors: [.clear, .white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: phase * geo.size.width * 1.6)
                }
                .mask(content)
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { phase = 1 }
        }
    }
}

/// Gentle idle float for illustrations.
struct FloatingEffect: ViewModifier {
    var amplitude: CGFloat = 8
    var duration: Double = 3.2
    @State private var up = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .offset(y: reduceMotion ? 0 : (up ? -amplitude : amplitude))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) { up = true }
            }
    }
}

extension View {
    func staggeredAppear(_ index: Int, offset: CGFloat = 18) -> some View { modifier(StaggeredAppear(index: index, offset: offset)) }
    func shake(_ trigger: Int) -> some View { modifier(ShakeEffect(animatableData: CGFloat(trigger))).animation(.linear(duration: 0.4), value: trigger) }
    func shimmer() -> some View { modifier(Shimmer()) }
    func floating(amplitude: CGFloat = 8, duration: Double = 3.2) -> some View { modifier(FloatingEffect(amplitude: amplitude, duration: duration)) }

    @ViewBuilder func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}
