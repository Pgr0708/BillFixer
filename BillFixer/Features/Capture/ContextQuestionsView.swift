import SwiftUI

/// A few yes/no answers the rights engine needs (NSA applies to emergencies/out-of-network, GFE to self-pay…).
struct ContextQuestionsView: View {
    @Bindable var model: CaptureFlowModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("A few quick questions").font(BFFont.title(26)).foregroundStyle(BFColor.text1)
                Text("These help us check which protections may apply. Skip anything you’re unsure about.")
                    .font(BFFont.subheadline).foregroundStyle(BFColor.text2)

                question("Was this an emergency visit?", $model.wasEmergency)
                question("Do you have health insurance?", $model.hasInsurance)
                if model.hasInsurance != false { question("Was the provider out of your network?", $model.outOfNetwork) }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Could you get help paying this bill?").font(BFFont.title3(16)).foregroundStyle(BFColor.text1)
                        Spacer(minLength: 6)
                        if model.savedProfile != nil { Pill(text: "Saved info", tone: .green, icon: "checkmark", small: true) }
                    }
                    Text("Many hospitals reduce or forgive bills based on income. Answer once and we’ll check this during the analysis.")
                        .font(.system(size: 13)).foregroundStyle(BFColor.text2)
                    Stepper(value: $model.householdSize, in: 1...20) {
                        HStack { Text("Household size"); Spacer(); Text("\(model.householdSize)").font(BFFont.money(17)).contentTransition(.numericText()) }
                    }
                    .onChange(of: model.householdSize) { _, _ in Haptics.selection() }
                    BFTextField(label: "Yearly household income", text: $model.annualIncome, prompt: "e.g. 42000", icon: "dollarsign", keyboard: .decimalPad)
                    BFTextField(label: "State", text: $model.state, prompt: "e.g. TX", icon: "map", error: Validation.stateCode(model.state),
                                autocapitalization: .characters)
                        .onChange(of: model.state) { _, s in if s.count > 2 { model.state = String(s.prefix(2)) } }
                    Toggle(isOn: $model.rememberFinancials) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Remember for my next bills").font(.system(size: 14, weight: .semibold)).foregroundStyle(BFColor.text1)
                            Text("Also re-checks your open cases. Change or delete it anytime in Financial Assistance.")
                                .font(.system(size: 12)).foregroundStyle(BFColor.text3)
                        }
                    }
                    .tint(BFColor.teal)
                    .hapticOnChange(model.rememberFinancials)
                    Label("Used only to estimate eligibility. Never shared with your provider.", systemImage: "lock.fill")
                        .font(.system(size: 12)).foregroundStyle(BFColor.text3)
                }
                .cardStyle(padding: 16, radius: 20)

                BFButton(title: "Start Analysis", icon: "sparkles", kind: .navy, isLoading: model.isSubmitting) {
                    Task { await model.submit() }
                }
                if model.isSubmitting { Text(model.submitStage).font(.system(size: 13)).foregroundStyle(BFColor.text3).frame(maxWidth: .infinity) }
            }
            .padding(BFSpacing.screen)
        }
        .scrollDismissesKeyboard(.interactively)
        .scenicBackground(.analysis)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.loadSavedProfile() }
    }

    private func question(_ title: String, _ value: Binding<Bool?>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(BFColor.text1)
            HStack(spacing: 8) {
                chip("Yes", value.wrappedValue == true) { value.wrappedValue = true }
                chip("No", value.wrappedValue == false) { value.wrappedValue = false }
                chip("Not sure", value.wrappedValue == nil) { value.wrappedValue = nil }
            }
        }
        .cardStyle(padding: 16, radius: 18)
    }

    private func chip(_ title: String, _ on: Bool, action: @escaping () -> Void) -> some View {
        Button { Haptics.selection(); withAnimation(BFMotion.snappy) { action() } } label: {
            Text(title).font(.system(size: 14, weight: .semibold))
                .foregroundStyle(on ? .white : BFColor.text2)
                .frame(maxWidth: .infinity).frame(height: 40)
                .background(on ? AnyShapeStyle(BFGradient.blue) : AnyShapeStyle(BFColor.background), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.pressableQuiet)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
