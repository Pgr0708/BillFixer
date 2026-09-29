import SwiftUI

/// Screen 27 — Federal Poverty Level estimator. The server computes the % from HHS guidelines (official data).
/// Not tied to one case: the answers can be saved to the user's profile, reused for every new bill, and
/// saving re-checks all unresolved cases.
struct FinancialAssistanceView: View {
    let caseId: String?
    @Environment(\.services) private var services
    @Environment(AppRouter.self) private var router
    @Environment(AppSession.self) private var session
    @State private var household = 2
    @State private var income: Double = 40_000
    @State private var state = ""
    @State private var estimate: FPLEstimate?
    @State private var loading = false
    @State private var debounce: Task<Void, Never>?
    @State private var link: WebLink?
    @State private var saved: FinancialProfile?
    @State private var saving = false
    @State private var confirmForget = false
    @State private var incomeMax: Double = 250_000

    private var currentIncome: Money { Money(Decimal(Int(income))) }
    private var matchesSaved: Bool {
        guard let saved else { return false }
        return saved.householdSize == household && saved.annualIncome == currentIncome && (saved.state ?? "") == state.uppercased()
    }

    private var tier: (String, String, Color) {
        guard let pct = estimate?.fplPercent else { return ("", "", BFColor.text3) }
        switch pct {
        case ..<201: return ("Likely eligible for free care", "Many nonprofit hospitals give free care up to 200% of the poverty level.", BFColor.green)
        case ..<401: return ("May qualify for a discount", "Discounts are common between 200% and 400% of the poverty level.", BFColor.amber)
        default: return ("Less likely to qualify", "Some hospitals still help with large bills — it’s worth asking.", BFColor.text2)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Financial Assistance").font(BFFont.title(28)).foregroundStyle(BFColor.text1)
                Text("Nonprofit hospitals must offer financial assistance (IRS §501(r)). See where you stand.")
                    .font(BFFont.subheadline).foregroundStyle(BFColor.text2)

                VStack(alignment: .leading, spacing: 16) {
                    Stepper(value: $household, in: 1...20) {
                        HStack { Text("Household size").font(.system(size: 15, weight: .medium)); Spacer()
                            Text("\(household)").font(BFFont.money(20)).contentTransition(.numericText()) }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack { Text("Yearly income").font(.system(size: 15, weight: .medium)); Spacer()
                            Text(Money(Decimal(Int(income))).formattedCompact).font(BFFont.money(20)).contentTransition(.numericText()) }
                        Slider(value: $income, in: 0...incomeMax, step: 1_000).tint(BFColor.teal)
                            .hapticOnChange(income)
                    }
                    BFTextField(label: "State (for Alaska & Hawaii guidelines)", text: $state, prompt: "e.g. TX", icon: "map",
                                error: Validation.stateCode(state), autocapitalization: .characters)
                        .onChange(of: state) { _, s in if s.count > 2 { state = String(s.prefix(2)) } }
                }
                .cardStyle(padding: 16, radius: 20)
                .onChange(of: household) { _, _ in Haptics.selection(); schedule() }
                .onChange(of: income) { _, _ in schedule() }
                .onChange(of: state) { _, s in if s.count == 2 || s.isEmpty { schedule() } }

                if let estimate {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(estimate.fplPercent)%").font(BFFont.money(44)).foregroundStyle(tier.2).contentTransition(.numericText())
                            Text("of the poverty level").font(.system(size: 14, weight: .medium)).foregroundStyle(BFColor.text2)
                            if loading { ProgressView().controlSize(.small) }
                        }
                        Text(tier.0).font(BFFont.title3()).foregroundStyle(BFColor.text1)
                        Text(tier.1).font(.system(size: 14)).foregroundStyle(BFColor.text2)
                        Text("\(String(estimate.year)) HHS guideline for \(estimate.householdSize): \(estimate.guideline.formattedCompact)")
                            .font(.system(size: 12)).foregroundStyle(BFColor.text3)
                        if let src = WebLink.external(estimate.sourceUrl) { Button("Source: HHS Poverty Guidelines") { link = src }.font(.system(size: 12, weight: .semibold)) }
                    }
                    .cardStyle(padding: 18, radius: 22)
                    .animation(BFMotion.gentle, value: estimate.fplPercent)
                }

                savedCard

                VStack(alignment: .leading, spacing: 10) {
                    Text("Documents to gather").font(BFFont.title3()).foregroundStyle(BFColor.text1)
                    ForEach(["Recent pay stubs or tax return", "Proof of household size", "Bank statements (some hospitals)", "The bill and account number"], id: \.self) {
                        Label($0, systemImage: "doc.text").font(.system(size: 14)).foregroundStyle(BFColor.text2)
                    }
                }
                .cardStyle(padding: 16, radius: 18)

                if let caseId {
                    BFButton(title: "Draft Assistance Request Letter", icon: "envelope.fill", kind: .teal) {
                        guard session.isPremium else { return router.requirePremium(.letters) }
                        router.push(.newLetter(caseId: caseId, findingId: nil, type: .financialAssistance))
                    }
                }
                Text("An estimate only. Each hospital sets its own policy; ask the billing office for their financial assistance application.")
                    .font(.system(size: 11)).foregroundStyle(BFColor.text3)
            }
            .padding(BFSpacing.screen)
        }
        .scrollDismissesKeyboard(.interactively)
        .scenicBackground(.assistance)
        .navigationBarTitleDisplayMode(.inline)
        .webSheet($link)
        .task { await loadSaved(); await fetch() }
        .confirmationDialog("Forget your saved income?", isPresented: $confirmForget, titleVisibility: .visible) {
            Button("Forget Saved Info", role: .destructive) { Task { await forget() } }
        } message: { Text("New bills won’t be checked for financial assistance until you enter it again.") }
    }

    // MARK: - Saved profile

    private var savedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                IconTile(symbol: saved == nil ? "person.crop.circle.badge.plus" : "checkmark.shield.fill",
                         tint: saved == nil ? BFColor.blue : BFColor.green, fill: saved == nil ? BFColor.blueSoft : BFColor.greenSoft, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(saved == nil ? "Use this for all my bills" : (matchesSaved ? "Saved — used for all your bills" : "Update your saved info"))
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(BFColor.text1)
                    Text(saved == nil ? "We’ll check every new bill automatically and re-check your open cases."
                                      : "Every new bill and your unresolved cases use these numbers.")
                        .font(.system(size: 12)).foregroundStyle(BFColor.text3)
                }
            }
            if saved == nil || !matchesSaved {
                BFButton(title: saved == nil ? "Save & Check My Bills" : "Update & Re-check", icon: "arrow.triangle.2.circlepath",
                         kind: .teal, size: .md, isLoading: saving, isDisabled: Validation.stateCode(state) != nil) {
                    Task { await save() }
                }
            }
            if saved != nil {
                Button("Forget saved info") { confirmForget = true }
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(BFColor.red)
            }
        }
        .cardStyle(padding: 16, radius: 18)
        .animation(BFMotion.gentle, value: matchesSaved)
    }

    private func loadSaved() async {
        guard let p = try? await services.reference.financialProfile().profile else { return }
        saved = p
        household = p.householdSize
        let value = NSDecimalNumber(decimal: p.annualIncome.value).doubleValue
        incomeMax = max(250_000, (value / 1_000).rounded(.up) * 1_000)
        income = value
        state = p.state ?? ""
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            let r = try await services.reference.saveFinancialProfile(householdSize: household, annualIncome: currentIncome, state: state)
            saved = r.profile
            if let e = r.estimate { estimate = e }
            let n = r.recheckedCases ?? 0
            Toast.success("Saved", n > 0 ? "Re-checking \(n) open case\(n == 1 ? "" : "s") with your numbers." : "Every new bill will use these numbers.")
        } catch { Toast.error(error) }
    }

    private func forget() async {
        do {
            try await services.reference.deleteFinancialProfile()
            withAnimation(BFMotion.gentle) { saved = nil }
            Toast.info("Saved income removed")
        } catch { Toast.error(error) }
    }

    /// Slider moves fire many changes — debounce to one request.
    private func schedule() {
        debounce?.cancel()
        debounce = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await fetch()
        }
    }

    private func fetch() async {
        guard Validation.stateCode(state) == nil else { return }
        loading = true
        defer { loading = false }
        do {
            estimate = try await services.reference.fplEstimate(householdSize: household, annualIncome: Money(Decimal(Int(income))), state: state)
        } catch {
            if error.asAPIError != .cancelled && estimate == nil { Toast.error(error) }
        }
    }
}
