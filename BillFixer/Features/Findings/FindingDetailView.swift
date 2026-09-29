import SwiftUI

/// Screen 13 — single finding detail with circular design.
struct FindingDetailView: View {
    let caseId: String
    @State var finding: Finding
    @Environment(\.services) private var services
    @Environment(AppRouter.self) private var router
    @Environment(AppSession.self) private var session
    @State private var model: FindingsModel?
    @State private var link: WebLink?
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [finding.severity.bgLight, Color(hex: 0xF7F9FD)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            circleDecorations

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Hero section ─────────────────────────────────────
                    heroSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -16)

                    // ── Amount ───────────────────────────────────────────
                    if let amount = finding.amountDifference ?? finding.amountFlagged {
                        amountCard(amount)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: appeared)
                    }

                    // ── Explanation ──────────────────────────────────────
                    explanationCard
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.09), value: appeared)

                    // ── Evidence ─────────────────────────────────────────
                    if !finding.evidence.isEmpty {
                        evidenceSection
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.13), value: appeared)
                    }

                    // ── Info cards ───────────────────────────────────────
                    if let what = finding.whatYouCanDo, !what.isEmpty {
                        infoCard("What you can do", what, "lightbulb.fill", BFColor.teal, BFColor.tealSoft)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.16), value: appeared)
                    }
                    if let counter = finding.counterCase, !counter.isEmpty {
                        infoCard("Why this might be correct", counter, "scalemass.fill", BFColor.text2,
                                 Color(light: 0xF0F3F8, dark: 0x1F2633))
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.18), value: appeared)
                    }
                    infoCard("Why this matters", whyItMatters, "info.circle.fill", BFColor.blue, BFColor.blueSoft)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.20), value: appeared)

                    // ── Action buttons ───────────────────────────────────
                    actionButtons
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.24), value: appeared)

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .webSheet($link)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) { appeared = true }
            if model == nil { model = FindingsModel(caseId: caseId, services: services) }
        }
    }

    // MARK: - Hero section

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Circular severity badge + confidence pills
            HStack(spacing: 10) {
                // Circular severity icon
                ZStack {
                    Circle()
                        .fill(finding.severity.color.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Circle()
                        .fill(finding.severity.color.opacity(0.25))
                        .frame(width: 40, height: 40)
                    Image(systemName: finding.severity.symbol)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(finding.severity.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(finding.severity.label)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(finding.severity.color)
                        .tracking(0.5)
                    Text(finding.confidence.title + " confidence")
                        .font(.system(size: 12))
                        .foregroundStyle(BFColor.text3)
                }

                Spacer()

                if let d = finding.deadlineDate {
                    HStack(spacing: 5) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                        Text("Act by \(DateHelpers.display(d) ?? d)")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(BFColor.red)
                    .clipShape(Capsule())
                }
            }

            Text(finding.title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(BFColor.text1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(BFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: finding.severity.color.opacity(0.12), radius: 16, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(finding.severity.color.opacity(0.2), lineWidth: 1.5)
        )
    }

    // MARK: - Amount card

    private func amountCard(_ amount: Money) -> some View {
        HStack(spacing: 16) {
            // Circular icon
            Circle()
                .fill(finding.severity == .strong ? BFColor.redSoft : BFColor.amberSoft)
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(finding.severity == .strong ? BFColor.red : BFColor.amber)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("Amount flagged")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BFColor.text3)
                    .tracking(0.4)
                CountUpMoney(money: amount,
                             font: BFFont.money(32),
                             color: finding.severity == .strong ? BFColor.red : BFColor.amber,
                             compact: false)
            }
        }
        .padding(18)
        .background(BFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    // MARK: - Explanation card

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(BFColor.blueSoft)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(BFColor.blue)
                    }
                Text("What we found")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(BFColor.text1)
            }
            Text(finding.explanation)
                .font(.system(size: 15))
                .foregroundStyle(BFColor.text2)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(BFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Evidence section

    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(BFColor.tealSoft)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(BFColor.teal)
                    }
                Text("Evidence")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(BFColor.text1)
            }
            ForEach(Array(finding.evidence.enumerated()), id: \.offset) { i, e in
                evidenceRow(e)
            }
        }
        .padding(16)
        .background(BFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private func evidenceRow(_ e: Evidence) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(BFColor.blueSoft)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: e.sourceType.contains("price") || e.sourceType.contains("mrf")
                          ? "building.2.fill"
                          : e.sourceType.contains("eob") ? "doc.text.fill" : "list.bullet.rectangle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BFColor.blue)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(e.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BFColor.text1)
                if let v = e.value {
                    Text(v)
                        .font(BFFont.evidence)
                        .foregroundStyle(BFColor.text2)
                }
                if let url = WebLink.external(e.url) {
                    Button("View source") { link = url }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BFColor.blue)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    // MARK: - Info card

    private func infoCard(_ title: String, _ body: String, _ symbol: String, _ tint: Color, _ fill: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(BFColor.text1)
            }
            Text(body)
                .font(.system(size: 14))
                .foregroundStyle(BFColor.text2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(tint.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Letter button — full capsule primary
            Button {
                guard session.isPremium else { return router.requirePremium(.letters) }
                router.push(.newLetter(caseId: caseId, findingId: finding.id, type: finding.kind.letterType))
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    Text("Generate Dispute Letter")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(LinearGradient(colors: [Color(hex: 0x0B2B5C), Color(hex: 0x2E7DF6)],
                                           startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
                .shadow(color: Color(hex: 0x2E7DF6).opacity(0.35), radius: 14, y: 6)
            }
            .buttonStyle(.pressable)

            // Phone script button — outlined capsule
            Button {
                guard session.isPremium else { return router.requirePremium(.scripts) }
                router.push(.newScript(caseId: caseId, findingId: finding.id,
                                       callTarget: finding.kind.callTarget, issueType: finding.type))
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(BFColor.teal.opacity(0.12))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(BFColor.teal)
                        }
                    Text("Get a Phone Script")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(BFColor.teal)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(BFColor.surface)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(BFColor.teal, lineWidth: 1.5))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
            }
            .buttonStyle(.pressable)

            // Rights button (if applicable)
            if let key = finding.kind.rightKey {
                Button {
                    Task {
                        if let right = try? await services.reference.rights().first(where: { $0.key == key }) {
                            router.push(.right(right, caseId: caseId))
                        } else { router.push(.rights(caseId: caseId)) }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "building.columns")
                            .font(.system(size: 14, weight: .semibold))
                        Text("See Your Rights")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(BFColor.violet)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.pressable)
            }

            // Status menu
            Menu {
                Button { Task { await setStatus(.fixed) } }       label: { Label("Resolved — they fixed it", systemImage: "checkmark.circle") }
                Button { Task { await setStatus(.partiallyFixed) } } label: { Label("Partly fixed", systemImage: "circle.lefthalf.filled") }
                Button { Task { await setStatus(.denied) } }      label: { Label("They said no", systemImage: "xmark.circle") }
                Button { Task { await setStatus(.dismissed) } }   label: { Label("Not relevant", systemImage: "eye.slash") }
                Button(role: .destructive) { Task { await setStatus(.wrong) } } label: { Label("This finding is wrong", systemImage: "flag") }
                if finding.status != .open { Button { Task { await setStatus(.open) } } label: { Label("Reopen", systemImage: "arrow.uturn.backward") } }
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(BFColor.greenSoft)
                        .frame(width: 30, height: 30)
                        .overlay {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(BFColor.green)
                        }
                    Text(finding.status == .open ? "Mark as Resolved…" : "Status: \(finding.status.title)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BFColor.green)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
        }
    }

    // MARK: - Background circles

    private var circleDecorations: some View {
        ZStack {
            Circle()
                .fill(finding.severity.color.opacity(0.06))
                .frame(width: 280)
                .offset(x: 150, y: -140)
                .blur(radius: 2)
            Circle()
                .fill(BFColor.blueSoft)
                .frame(width: 200)
                .offset(x: -120, y: 450)
        }
    }

    // MARK: - Why it matters

    private var whyItMatters: String {
        switch finding.kind {
        case .duplicateCharge:         "You may be charged twice for the same service. This is one of the most common billing errors."
        case .billEobMismatch, .paidAmountMismatch: "Your bill should match what your insurer says you owe. Differences are often billing mistakes."
        case .arithmeticError, .balanceMismatch: "Totals that don't add up usually mean a payment or adjustment wasn't applied."
        case .priceAboveCashPrice, .priceAboveNegotiatedRate, .medicareBenchmark: "Hospitals must publish their prices. A big gap is a fair reason to ask for an adjustment."
        case .financialAssistanceEligible: "Nonprofit hospitals must offer financial assistance. It can reduce or erase the bill."
        case .noSurprisesPossible:     "Federal law limits surprise out-of-network bills for emergencies and some in-network visits."
        case .gfeDisputeEligible:      "If your bill is $400+ over your Good Faith Estimate, you can dispute it within 120 days."
        case .itemizedBillMissing:     "You have the right to an itemized bill. It's the only way to check every charge."
        default:                       "Understanding each charge helps you decide what to question."
        }
    }

    private func setStatus(_ status: FindingStatus) async {
        guard let model else { return }
        if await model.update(finding, to: status),
           let fresh = model.response?.findings.first(where: { $0.id == finding.id }) {
            withAnimation { finding = fresh }
        }
    }
}

// MARK: - Severity helpers

extension Severity {
    var bgLight: Color {
        switch self {
        case .strong:   return Color(hex: 0xFFF5F5)
        case .likely:   return Color(hex: 0xFFFBEB)
        case .possible: return Color(hex: 0xEFF6FF)
        default:        return Color(hex: 0xF7F9FD)
        }
    }
}
