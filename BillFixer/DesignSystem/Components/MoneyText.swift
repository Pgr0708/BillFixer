import SwiftUI

/// Counts up to an amount when it first appears (UX: "the number is the reward").
/// Animates a Double for display only; the final frame shows the exact `Money` string.
struct CountUpMoney: View {
    let money: Money
    var font: Font = BFFont.money(34)
    var color: Color = BFColor.text1
    var compact = true
    @State private var progress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CountingLabel(target: money.doubleValue, progress: progress, exact: compact ? money.formattedCompact : money.formatted)
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .onAppear {
                if reduceMotion { progress = 1 } else { withAnimation(.easeOut(duration: 1.1)) { progress = 1 } }
            }
            .onChange(of: money) { _, _ in progress = 1 }
            .accessibilityLabel(money.formatted)
    }
}

private struct CountingLabel: View, Animatable {
    let target: Double
    var progress: Double
    let exact: String

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Text(progress >= 1 ? exact : (target * progress).formatted(.currency(code: "USD").precision(.fractionLength(0))))
    }
}
