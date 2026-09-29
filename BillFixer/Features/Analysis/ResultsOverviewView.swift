import SwiftUI

/// Screens 12 / 21 (dark).
struct ResultsOverviewView: View {
    let caseId: String
    @Environment(\.services) private var services
    @Environment(AppRouter.self) private var router
    @Environment(AppSession.self) private var session
    @State private var model: FindingsModel?
    @State private var revealed = false

    var body: some View {
        ScrollView {
            if let model {
                switch model.state {
                case let .loaded(r): content(r)
                case let .failed(e): ErrorStateView(error: e) { Task { await model.load() } }
                default: VStack(spacing: 16) { SkeletonBlock(height: 220, radius: 110).frame(width: 220); SkeletonList(rows: 2) }.padding(BFSpacing.screen)
                }
            }
        }
        .scenicBackground(.results)
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil { model = FindingsModel(caseId: caseId, services: services) }
            await model?.load()
            if let n = model?.response?.summary.total, !revealed { revealed = true; Haptics.findingsRevealed(count: n) }
        }
    }

    private func content(_ r: FindingsResponse) -> some View {
        let s = r.summary
        return VStack(alignment: .leading, spacing: 20) {
            Text(s.total == 0 ? "No clear errors found" : "Analysis Complete").font(BFFont.title(28)).foregroundStyle(BFColor.text1).staggeredAppear(0)

            HStack(spacing: 20) {
                DonutChart(segments: Severity.allCases.map { .init(value: Double(s.count($0)), color: $0.color) }.filter { $0.value > 0 }
                                     .ifEmpty([.init(value: 1, color: BFColor.green)]),
                           centerValue: "\(s.total)", centerLabel: s.total == 1 ? "Finding" : "Findings")
                    .frame(width: 150, height: 150)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Severity.allCases, id: \.self) { sev in
                        if s.count(sev) > 0 {
                            Pill(text: "\(s.count(sev)) \(sev == .informational ? "Info" : sev.title)", tone: sev.tone, icon: sev.symbol)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .cardStyle(padding: 18, radius: 24)
            .staggeredAppear(1)

            savingsCard(s).staggeredAppear(2)

            BFButton(title: "View Findings", trailingIcon: "arrow.right", kind: .navy) { router.push(.findings(caseId)) }.staggeredAppear(3)

            if let first = s.recommendedFirstAction, let finding = r.findings.first(where: { $0.id == first.findingId }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start here").overlineStyle()
                    Button { router.push(.finding(caseId: caseId, finding: finding)) } label: {
                        ActionRow(symbol: "flag.fill", title: first.title, subtitle: "Our recommended first step", tint: BFColor.red, fill: BFColor.redSoft)
                    }.buttonStyle(.pressable)
                }
                .staggeredAppear(4)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Or jump to an action").overlineStyle()
                Button { openLetter(r) } label: {
                    ActionRow(symbol: "envelope.fill", title: "Generate Letter", subtitle: "Ready-to-send dispute or request letter",
                              tint: BFColor.amber, fill: BFColor.amberSoft, locked: !session.isPremium)
                }.buttonStyle(.pressable)
                Button { openScript(r) } label: {
                    ActionRow(symbol: "phone.fill", title: "Phone Script", subtitle: "What to say when you call", tint: BFColor.teal, fill: BFColor.tealSoft,
                              locked: !session.isPremium)
                }.buttonStyle(.pressable)
                Button { router.push(.rights(caseId: caseId)) } label: {
                    ActionRow(symbol: "building.columns.fill", title: "View Rights", subtitle: "Protections that may apply", tint: BFColor.violet, fill: BFColor.violetSoft)
                }.buttonStyle(.pressable)
            }
            .staggeredAppear(5)

            Text("Bill Fixer isn’t a law firm and doesn’t give legal advice. Findings are based on the details you confirmed and public pricing data.")
                .font(.system(size: 11)).foregroundStyle(BFColor.text3)
        }
        .padding(BFSpacing.screen)
    }

    @ViewBuilder
    private func savingsCard(_ s: FindingsSummary) -> some View {
        if s.potentialSavingsLocked {
            Button { router.requirePremium(.findings) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("You may be overcharged").font(BFFont.title3(17)).foregroundStyle(.white)
                        Text("Unlock to see the amount").font(.system(size: 13)).foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                    Image(systemName: "lock.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                }
                .padding(18)
                .background(BFGradient.amber, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .bfShadow(.gold)
            }.buttonStyle(.pressable)
        } else if let savings = s.potentialSavings, savings.value > 0 {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("You may be overcharged").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
                    CountUpMoney(money: savings, font: BFFont.money(36), color: .white)
                    Text("Based on our analysis").font(.system(size: 12)).foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Image(systemName: "dollarsign.circle.fill").font(.system(size: 50)).foregroundStyle(.white.opacity(0.9))
            }
            .padding(18)
            .background(BFGradient.amber, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .bfShadow(.gold)
        }
    }

    private func openLetter(_ r: FindingsResponse) {
        guard session.isPremium else { return router.requirePremium(.letters) }
        let top = r.findings.first { !$0.locked && $0.severity != .informational }
        router.push(.newLetter(caseId: caseId, findingId: top?.id, type: top?.kind.letterType ?? .itemizedBillRequest))
    }

    private func openScript(_ r: FindingsResponse) {
        guard session.isPremium else { return router.requirePremium(.scripts) }
        let top = r.findings.first { !$0.locked && $0.severity != .informational }
        router.push(.newScript(caseId: caseId, findingId: top?.id, callTarget: top?.kind.callTarget ?? "provider_billing", issueType: top?.type ?? "itemized_bill"))
    }
}

extension Array {
    func ifEmpty(_ fallback: [Element]) -> [Element] { isEmpty ? fallback : self }
}
