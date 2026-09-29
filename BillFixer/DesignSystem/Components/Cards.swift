import SwiftUI

/// Case row (Figma `Card/Case`): provider, date, stage pill, findings, balance.
struct CaseCard: View {
    let item: CaseSummary

    var body: some View {
        HStack(spacing: 14) {
            IconTile(symbol: "building.2.fill", tint: BFColor.blue, fill: BFColor.blueSoft, size: 46)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.displayName).font(.system(size: 16, weight: .semibold)).foregroundStyle(BFColor.text1).lineLimit(2)
                HStack(spacing: 6) {
                    Text(DateHelpers.display(item.billDate) ?? DateHelpers.display(item.createdAt) ?? "")
                    if item.findingCount > 0 {
                        Text("·")
                        Text("\(item.findingCount) finding\(item.findingCount == 1 ? "" : "s")")
                    }
                }
                .font(.system(size: 13)).foregroundStyle(BFColor.text3)
                Pill(text: item.stageLabel.0, tone: item.stageLabel.1, small: true)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 6) {
                if let balance = item.currentBalance ?? item.originalBalance {
                    Text(balance.formattedCompact).font(BFFont.money(18)).foregroundStyle(BFColor.text1)
                }
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(BFColor.text4)
            }
        }
        .cardStyle(padding: 14, radius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens case details")
    }
}

/// Finding card (Figma `Card/Finding`) — locked variant shows a blurred teaser.
struct FindingCard: View {
    let finding: Finding

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3).fill(finding.severity.color).frame(width: 4)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Pill(text: finding.severity.label, tone: finding.severity.tone, icon: finding.severity.symbol, small: true)
                    Spacer()
                    if let amount = finding.amountDifference ?? finding.amountFlagged, !finding.locked {
                        Text(amount.formatted).font(BFFont.money(17)).foregroundStyle(finding.severity == .informational ? BFColor.text2 : BFColor.text1)
                    }
                }
                Text(finding.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(BFColor.text1).multilineTextAlignment(.leading)
                if !finding.locked, !finding.explanation.isEmpty {
                    Text(finding.explanation).font(.system(size: 14)).foregroundStyle(BFColor.text2).lineLimit(2).multilineTextAlignment(.leading)
                }
                if finding.locked {
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonBlock(height: 10).frame(maxWidth: 220)
                        SkeletonBlock(height: 10).frame(maxWidth: 160)
                    }
                    .blur(radius: 1.5)
                    Label("Premium", systemImage: "lock.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: 0xB86E00))
                } else if finding.status != .open {
                    Pill(text: finding.status.title, tone: .green, icon: "checkmark", small: true)
                }
            }
            Image(systemName: finding.locked ? "lock.fill" : "chevron.right")
                .font(.system(size: 12, weight: .bold)).foregroundStyle(BFColor.text4).padding(.top, 4)
        }
        .cardStyle(padding: 14, radius: 18, fill: finding.severity == .strong && !finding.locked ? BFColor.redSoft.opacity(0.55) : BFColor.surface)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(finding.locked ? "Locked \(finding.severity.title) finding. Upgrade to view." : "\(finding.severity.label): \(finding.title)")
    }
}

extension FindingStatus {
    var title: String {
        switch self {
        case .open: "Open"
        case .dismissed: "Dismissed"
        case .fixed: "Resolved"
        case .partiallyFixed: "Partly fixed"
        case .denied: "Denied"
        case .wrong: "Marked incorrect"
        }
    }
}

/// Icon + title + subtitle + chevron (Figma `Card/Action`).
struct ActionRow: View {
    let symbol: String
    let title: String
    var subtitle: String? = nil
    var tint: Color = BFColor.blue
    var fill: Color = BFColor.blueSoft
    var locked = false

    var body: some View {
        HStack(spacing: 14) {
            IconTile(symbol: symbol, tint: tint, fill: fill, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(BFColor.text1)
                if let subtitle { Text(subtitle).font(.system(size: 13)).foregroundStyle(BFColor.text3).multilineTextAlignment(.leading) }
            }
            Spacer(minLength: 4)
            Image(systemName: locked ? "lock.fill" : "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(locked ? BFColor.amber : BFColor.text4)
        }
        .cardStyle(padding: 14, radius: 18)
        .accessibilityElement(children: .combine)
    }
}

/// Timeline row (Figma `TimelineRow`) with a connecting rail.
struct TimelineRow: View {
    let event: CaseEvent
    var isLast = false

    private var style: (String, Color) {
        switch event.type {
        case "document_added": ("doc.fill", BFColor.blue)
        case "analysis_run": ("sparkles", BFColor.violet)
        case "letter_generated": ("envelope.fill", BFColor.amber)
        case "letter_sent": ("paperplane.fill", BFColor.teal)
        case "balance_updated": ("arrow.down.circle.fill", BFColor.green)
        case "case_resolved": ("checkmark.seal.fill", BFColor.green)
        case "script_generated": ("phone.fill", BFColor.blue)
        case "deadline_set": ("calendar.badge.clock", BFColor.red)
        case "note_added": ("note.text", BFColor.navy2)
        default: event.isUserLog ? ("person.fill", BFColor.text2) : ("circle.fill", BFColor.text3)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Image(systemName: style.0).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 32, height: 32).background(style.1, in: Circle())
                if !isLast { Rectangle().fill(BFColor.line).frame(width: 2).frame(maxHeight: .infinity) }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(event.label).font(.system(size: 15, weight: .semibold)).foregroundStyle(BFColor.text1)
                Text(DateHelpers.timeline(event.occurredAt)).font(.system(size: 13)).foregroundStyle(BFColor.text3)
            }
            .padding(.bottom, isLast ? 0 : 22)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

/// Settings list row (Figma `ListRow/Setting`).
struct SettingsRow<Trailing: View>: View {
    let symbol: String
    let title: String
    var tint: Color = BFColor.blue
    var destructive = false
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 14) {
            IconTile(symbol: symbol, tint: destructive ? BFColor.red : tint, fill: destructive ? BFColor.redSoft : tint.opacity(0.12), size: 34, radius: 10)
            Text(title).font(.system(size: 16, weight: .medium)).foregroundStyle(destructive ? BFColor.red : BFColor.text1)
            Spacer()
            trailing()
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

extension SettingsRow where Trailing == AnyView {
    init(symbol: String, title: String, tint: Color = BFColor.blue, value: String? = nil, destructive: Bool = false, chevron: Bool = true) {
        self.symbol = symbol
        self.title = title
        self.tint = tint
        self.destructive = destructive
        self.trailing = {
            AnyView(HStack(spacing: 6) {
                if let value { Text(value).font(.system(size: 14)).foregroundStyle(BFColor.text3) }
                if chevron && !destructive { Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(BFColor.text4) }
            })
        }
    }
}

/// Amber "Free Plan" banner (board screen 06).
struct PlanBanner: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "crown.fill").foregroundStyle(Color(hex: 0xE89412))
                Text(text).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(light: 0x8A5300, dark: 0xFFC554))
                Spacer()
                Text("Upgrade").font(BFFont.label(13)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(BFGradient.amber, in: Capsule())
            }
            .padding(12)
            .background(BFColor.amberSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(BFColor.amber.opacity(0.35)))
        }
        .buttonStyle(.pressable)
    }
}
