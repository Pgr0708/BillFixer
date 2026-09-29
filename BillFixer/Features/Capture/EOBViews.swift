import SwiftUI

/// Screen 31 — "Do you have an EOB?"
struct EOBPromptView: View {
    @Bindable var model: CaptureFlowModel
    @State private var pickSource = false
    @State private var auto: CaptureSource?

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle().fill(BFColor.tealSoft).frame(width: 170, height: 170)
                DocumentShape().fill(BFColor.surface).frame(width: 90, height: 110).bfShadow(.float)
                    .overlay(alignment: .top) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("EOB").font(BFFont.label(13)).foregroundStyle(BFColor.teal)
                            ForEach(0..<4, id: \.self) { i in Capsule().fill(BFColor.line).frame(width: [56, 44, 60, 38][i], height: 6) }
                        }
                        .padding(.top, 16)
                    }
                FloatingBadge(symbol: "checkmark.shield.fill", tint: BFColor.teal).offset(x: 62, y: -52).floating()
            }
            Text("Do you have an EOB?").font(BFFont.title(28)).foregroundStyle(BFColor.text1)
            Text("Your insurer’s Explanation of Benefits shows what you actually owe. Comparing it with the bill catches the most common errors.")
                .font(BFFont.body).foregroundStyle(BFColor.text2).multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: 12) {
                BFButton(title: "Yes, add my EOB", icon: "doc.text.fill", kind: .teal) { model.startEOBCapture(); pickSource = true }
                BFButton(title: "Skip for now", kind: .outline) { model.skipEOB() }
                Button("I don’t have insurance") { model.skipEOB(uninsured: true) }
                    .font(BFFont.label(14)).foregroundStyle(BFColor.text2).padding(.top, 4)
            }
            Text("Without an EOB the analysis is less certain — you can add it later.").font(.system(size: 12)).foregroundStyle(BFColor.text3).multilineTextAlignment(.center)
        }
        .padding(BFSpacing.screen)
        .scenicBackground(.capture)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $pickSource) {
            NavigationStack {
                SourcePicker(model: model, autoStart: $auto).padding(20)
                    .navigationTitle("Add your EOB").navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
        .onChange(of: model.eobPages.count) { _, n in if n > 0 { pickSource = false } }
        .loadingOverlay(model.isProcessing, "Opening document…")
    }
}

struct EOBReviewView: View {
    @Bindable var model: CaptureFlowModel
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("EOB Details").font(BFFont.title(26)).foregroundStyle(BFColor.text1)
                Text("Match these to the totals on your Explanation of Benefits.").font(BFFont.subheadline).foregroundStyle(BFColor.text2)
                if model.eobDraft != nil {
                    let d = Binding(get: { model.eobDraft ?? EOBDraft() }, set: { model.eobDraft = $0 })
                    VStack(spacing: 14) {
                        f("Insurance Company", d.insurerName, .insurerName, "e.g. Blue Cross", .default)
                        f("Claim Number", d.claimNumber, .claimNumber, "Optional", .asciiCapable)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Network status").font(.system(size: 12, weight: .semibold)).foregroundStyle(BFColor.text3)
                            Picker("Network", selection: d.networkStatus) {
                                ForEach(NetworkStatus.allCases) { Text($0.title).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .hapticOnChange(d.wrappedValue.networkStatus)
                        }
                        f("Amount Billed", d.billedAmount, .billedAmount, "0.00", .decimalPad)
                        f("Allowed Amount", d.allowedAmount, .allowedAmount, "0.00", .decimalPad)
                        f("Plan Paid", d.insurerPayment, .insurerPayment, "0.00", .decimalPad)
                        f("Deductible", d.deductibleApplied, .deductibleApplied, "0.00", .decimalPad)
                        f("Copay", d.copay, .copay, "0.00", .decimalPad)
                        f("Coinsurance", d.coinsurance, .coinsurance, "0.00", .decimalPad)
                        f("What You Owe (Patient Responsibility)", d.patientResponsibility, .patientResponsibility, "0.00", .decimalPad)
                    }
                    .cardStyle(padding: 16, radius: 20)
                }
                if let error { Label(error, systemImage: "exclamationmark.circle.fill").font(.system(size: 14, weight: .medium)).foregroundStyle(BFColor.red) }
                BFButton(title: "Continue", trailingIcon: "arrow.right", kind: .navy) {
                    if let e = model.eobDraft?.validationError { error = e; Haptics.error(); return }
                    model.kind = .bill
                    model.path.append(.context)
                }
            }
            .padding(BFSpacing.screen)
        }
        .scrollDismissesKeyboard(.interactively)
        .scenicBackground(.capture)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func f(_ label: String, _ text: Binding<String>, _ key: EOBField, _ prompt: String, _ kb: UIKeyboardType) -> some View {
        BFTextField(label: label, text: text, prompt: prompt, keyboard: kb, lowConfidence: model.eobDraft?.lowConfidence.contains(key) == true,
                    autocapitalization: kb == .default ? .words : .never) { model.eobDraft?.lowConfidence.remove(key) }
    }
}
