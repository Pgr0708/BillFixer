import SwiftUI

/// Screen 13.
struct FindingDetailView: View {
    let caseId: String
    @State var finding: Finding
    @Environment(\.services) private var services
    @Environment(AppRouter.self) private var router
    @Environment(AppSession.self) private var session
    @State private var model: FindingsModel?
    @State private var link: WebLink?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Pill(text: finding.severity.label, tone: finding.severity.tone, icon: finding.severity.symbol).staggeredAppear(0)
                Text(finding.title).font(BFFont.title(26)).foregroundStyle(BFColor.text1).staggeredAppear(1)
                if let amount = finding.amountDifference ?? finding.amountFlagged {
                    CountUpMoney(money: amount, font: BFFont.money(40), color: finding.severity == .strong ? BFColor.red : BFColor.text1, compact: false)
                        .staggeredAppear(2)
                }
                Text(finding.explanation).font(BFFont.body).foregroundStyle(BFColor.text2).lineSpacing(3).staggeredAppear(3)
                HStack(spacing: 8) {
                    Pill(text: finding.confidence.title, tone: finding.confidence == .high ? .green : finding.confidence == .medium ? .amber : .neutral, small: true)
                    if let d = finding.deadlineDate { Pill(text: "Act by \(DateHelpers.display(d) ?? d)", tone: .red, icon: "clock", small: true) }
                }

                if !finding.evidence.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Evidence").font(BFFont.title3()).foregroundStyle(BFColor.text1)
                        ForEach(Array(finding.evidence.enumerated()), id: \.offset) { i, e in evidenceRow(e).staggeredAppear(i + 4) }
                    }
                }

                if let what = finding.whatYouCanDo, !what.isEmpty {
                    infoCard("What you can do", what, "lightbulb.fill", BFColor.teal, BFColor.tealSoft)
                }
                if let counter = finding.counterCase, !counter.isEmpty {
                    infoCard("Why this might be correct", counter, "scalemass.fill", BFColor.text2, Color(light: 0xF0F3F8, dark: 0x1F2633))
                }
                infoCard("Why this matters", whyItMatters, "info.circle.fill", BFColor.blue, BFColor.blueSoft)

                VStack(spacing: 10) {
                    BFButton(title: "Generate Dispute Letter", icon: "envelope.fill", kind: .navy) {
                        guard session.isPremium else { return router.requirePremium(.letters) }
                        router.push(.newLetter(caseId: caseId, findingId: finding.id, type: finding.kind.letterType))
                    }
                    BFButton(title: "Get a Phone Script", icon: "phone.fill", kind: .outline) {
                        guard session.isPremium else { return router.requirePremium(.scripts) }
                        router.push(.newScript(caseId: caseId, findingId: finding.id, callTarget: finding.kind.callTarget, issueType: finding.type))
                    }
                    if let key = finding.kind.rightKey {
                        BFButton(title: "See Your Rights", icon: "building.columns", kind: .ghost, size: .md) {
                            Task {
                                if let right = try? await services.reference.rights().first(where: { $0.key == key }) {
                                    router.push(.right(right, caseId: caseId))
                                } else { router.push(.rights(caseId: caseId)) }
                            }
                        }
                    }
                    Menu {
                        Button { Task { await setStatus(.fixed) } } label: { Label("Resolved — they fixed it", systemImage: "checkmark.circle") }
                        Button { Task { await setStatus(.partiallyFixed) } } label: { Label("Partly fixed", systemImage: "circle.lefthalf.filled") }
                        Button { Task { await setStatus(.denied) } } label: { Label("They said no", systemImage: "xmark.circle") }
                        Button { Task { await setStatus(.dismissed) } } label: { Label("Not relevant", systemImage: "eye.slash") }
                        Button(role: .destructive) { Task { await setStatus(.wrong) } } label: { Label("This finding is wrong", systemImage: "flag") }
                        if finding.status != .open { Button { Task { await setStatus(.open) } } label: { Label("Reopen", systemImage: "arrow.uturn.backward") } }
                    } label: {
                        Label(finding.status == .open ? "Mark as Resolved…" : "Status: \(finding.status.title)", systemImage: "checkmark.seal")
                            .font(BFFont.label(15)).foregroundStyle(BFColor.green)
                            .frame(maxWidth: .infinity).frame(height: 48)
                    }
                }
                .padding(.top, 6)
            }
            .padding(BFSpacing.screen)
        }
        .scenicBackground(.finding)
        .navigationBarTitleDisplayMode(.inline)
        .webSheet($link)
        .onAppear { if model == nil { model = FindingsModel(caseId: caseId, services: services) } }
    }

    private var whyItMatters: String {
        switch finding.kind {
        case .duplicateCharge: "You may be charged twice for the same service. This is one of the most common billing errors."
        case .billEobMismatch, .paidAmountMismatch: "Your bill should match what your insurer says you owe. Differences are often billing mistakes."
        case .arithmeticError, .balanceMismatch: "Totals that don’t add up usually mean a payment or adjustment wasn’t applied."
        case .priceAboveCashPrice, .priceAboveNegotiatedRate, .medicareBenchmark: "Hospitals must publish their prices. A big gap is a fair reason to ask for an adjustment."
        case .financialAssistanceEligible: "Nonprofit hospitals must offer financial assistance. It can reduce or erase the bill."
        case .noSurprisesPossible: "Federal law limits surprise out-of-network bills for emergencies and some in-network visits."
        case .gfeDisputeEligible: "If your bill is $400+ over your Good Faith Estimate, you can dispute it within 120 days."
        case .itemizedBillMissing: "You have the right to an itemized bill. It’s the only way to check every charge."
        default: "Understanding each charge helps you decide what to question."
        }
    }

    private func evidenceRow(_ e: Evidence) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(symbol: e.sourceType.contains("price") || e.sourceType.contains("mrf") ? "building.2.fill" : e.sourceType.contains("eob") ? "doc.text.fill" : "list.bullet.rectangle",
                     tint: BFColor.blue, fill: BFColor.blueSoft, size: 36, radius: 10)
            VStack(alignment: .leading, spacing: 3) {
                Text(e.label).font(.system(size: 14, weight: .semibold)).foregroundStyle(BFColor.text1)
                if let v = e.value { Text(v).font(BFFont.evidence).foregroundStyle(BFColor.text2) }
                if let url = WebLink.external(e.url) {
                    Button("View source") { link = url }.font(.system(size: 12, weight: .semibold))
                }
            }
            Spacer()
        }
        .cardStyle(padding: 12, radius: 14)
    }

    private func infoCard(_ title: String, _ body: String, _ symbol: String, _ tint: Color, _ fill: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol).font(BFFont.label(15)).foregroundStyle(tint)
            Text(body).font(.system(size: 14)).foregroundStyle(BFColor.text2).lineSpacing(2)
        }
        .cardStyle(padding: 14, radius: 16, fill: fill, stroke: .clear, shadow: nil)
    }

    private func setStatus(_ status: FindingStatus) async {
        guard let model else { return }
        if await model.update(finding, to: status), let fresh = model.response?.findings.first(where: { $0.id == finding.id }) {
            withAnimation { finding = fresh }
        }
    }
}
