import SwiftUI

/// Findings donut (Figma `Donut`): colored severity segments, total in the middle, draws in on appear.
struct DonutChart: View {
    struct Segment: Identifiable { let id = UUID(); let value: Double; let color: Color }
    let segments: [Segment]
    let centerValue: String
    let centerLabel: String
    var lineWidth: CGFloat = 18
    @State private var drawn: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var total: Double { max(segments.map(\.value).reduce(0, +), 0.0001) }

    var body: some View {
        ZStack {
            Circle().stroke(BFColor.line, lineWidth: lineWidth)
            ForEach(Array(segments.enumerated()), id: \.element.id) { i, seg in
                let start = segments.prefix(i).map(\.value).reduce(0, +) / total
                let end = start + seg.value / total
                Circle()
                    .trim(from: start * drawn, to: max(start, end - 0.012) * drawn)
                    .stroke(seg.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 0) {
                Text(centerValue).font(BFFont.money(38)).foregroundStyle(BFColor.text1).contentTransition(.numericText())
                Text(centerLabel).font(.system(size: 13, weight: .semibold)).foregroundStyle(BFColor.text3)
            }
        }
        .onAppear {
            if reduceMotion { drawn = 1 } else { withAnimation(.easeOut(duration: 1.0).delay(0.15)) { drawn = 1 } }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(centerValue) \(centerLabel)")
    }
}
