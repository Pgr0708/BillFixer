import SwiftUI

enum PillTone {
    case blue, teal, green, amber, red, neutral, violet, navy, glass
    var fg: Color {
        switch self {
        case .blue: BFColor.blue
        case .teal: Color(light: 0x00967F, dark: 0x22D3BB)
        case .green: Color(light: 0x149A5E, dark: 0x3BDC93)
        case .amber: Color(light: 0xB86E00, dark: 0xFFC554)
        case .red: BFColor.red
        case .neutral: BFColor.text2
        case .violet: BFColor.violet
        case .navy: .white
        case .glass: .white
        }
    }
    var bg: Color {
        switch self {
        case .blue: BFColor.blueSoft
        case .teal: BFColor.tealSoft
        case .green: BFColor.greenSoft
        case .amber: BFColor.amberSoft
        case .red: BFColor.redSoft
        case .neutral: Color(light: 0xF0F3F8, dark: 0x1F2633)
        case .violet: BFColor.violetSoft
        case .navy: BFColor.navy
        case .glass: .white.opacity(0.18)
        }
    }
}

struct Pill: View {
    let text: String
    var tone: PillTone = .blue
    var icon: String? = nil
    var small = false

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: small ? 9 : 10, weight: .bold)) }
            Text(text).lineLimit(1)
        }
        .font(.system(size: small ? 11 : 12, weight: .bold))
        .foregroundStyle(tone.fg)
        .padding(.horizontal, small ? 8 : 10)
        .padding(.vertical, small ? 3 : 5)
        .background(tone.bg, in: Capsule())
    }
}

@MainActor
extension Severity {
    var tone: PillTone {
        switch self {
        case .strong: .red
        case .likely: .amber
        case .possible: .blue
        case .informational: .neutral
        }
    }
    var color: Color {
        switch self {
        case .strong: BFColor.red
        case .likely: BFColor.amber
        case .possible: BFColor.blue
        case .informational: BFColor.text3
        }
    }
    var symbol: String {
        switch self {
        case .strong: "exclamationmark.octagon.fill"
        case .likely: "exclamationmark.triangle.fill"
        case .possible: "questionmark.circle.fill"
        case .informational: "info.circle.fill"
        }
    }
    var label: String { self == .informational ? "Info" : "\(title) Finding" }
}

@MainActor
extension CaseStatus {
    var tone: PillTone {
        switch self {
        case .draft: .neutral
        case .active: .blue
        case .awaitingResponse: .amber
        case .resolved: .green
        case .closed: .neutral
        }
    }
}

@MainActor
extension CaseSummary {
    /// Board labels: "Analysis Complete", "Letter Sent", "In Review".
    var stageLabel: (String, PillTone) {
        switch status {
        case .draft: ("Draft", .neutral)
        case .awaitingResponse: ("Letter Sent", .amber)
        case .resolved: ("Resolved", .green)
        case .closed: ("Closed", .neutral)
        case .active: lastAnalyzedAt == nil ? ("In Review", .violet) : ("Analysis Complete", .teal)
        }
    }
}
