import SwiftUI

/// Screen 10 — the user confirms every extracted value before analysis (deterministic engines need correct inputs).
struct BillReviewView: View {
    @Bindable var model: CaptureFlowModel
    @State private var editing: LineItemDraft?
    @State private var showMore = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Extracted Information").font(BFFont.title(26)).foregroundStyle(BFColor.text1)
                    Text("Check each value against your bill. Fields marked Low confidence need a second look.")
                        .font(BFFont.subheadline).foregroundStyle(BFColor.text2)
                }
                if !model.billDraft.lowConfidence.isEmpty {
                    Label("\(model.billDraft.lowConfidence.count) field\(model.billDraft.lowConfidence.count == 1 ? "" : "s") need review", systemImage: "exclamationmark.triangle.fill")
                        .font(BFFont.label(14)).foregroundStyle(Color(hex: 0xB86E00))
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(BFColor.amberSoft, in: RoundedRectangle(cornerRadius: 14))
                }

                VStack(spacing: 14) {
                    field("Provider", $model.billDraft.providerName, .providerName, prompt: "Hospital or clinic name", icon: "building.2", keyboard: .default)
                    dateRow
                    field("Total Charges", $model.billDraft.totalCharges, .totalCharges, prompt: "0.00", icon: "dollarsign", keyboard: .decimalPad)
                    field("Patient Responsibility", $model.billDraft.patientResponsibility, .patientResponsibility, prompt: "0.00", icon: "person", keyboard: .decimalPad)
                    field("Amount Due / Current Balance", $model.billDraft.currentBalance, .currentBalance, prompt: "0.00", icon: "creditcard", keyboard: .decimalPad)
                    DisclosureGroup(isExpanded: $showMore) {
                        VStack(spacing: 14) {
                            field("Insurance Paid", $model.billDraft.insurancePayment, .insurancePayment, prompt: "0.00", icon: "shield", keyboard: .decimalPad)
                            field("Adjustments / Discounts", $model.billDraft.adjustments, .adjustments, prompt: "0.00", icon: "minus.circle", keyboard: .decimalPad)
                            field("Payments You Made", $model.billDraft.previousPayments, .previousPayments, prompt: "0.00", icon: "checkmark.circle", keyboard: .decimalPad)
                            field("Insurance Company", $model.billDraft.insurerName, .insurerName, prompt: "e.g. Aetna", icon: "cross.case", keyboard: .default)
                            field("Account Number", $model.billDraft.accountNumber, .accountNumber, prompt: "Optional", icon: "number", keyboard: .asciiCapable)
                        }
                        .padding(.top, 12)
                    } label: {
                        Text("More details").font(BFFont.label(15)).foregroundStyle(BFColor.blue)
                    }
                    .tint(BFColor.blue)
                }
                .cardStyle(padding: 16, radius: 20)

                lineItems

                if let error { Label(error, systemImage: "exclamationmark.circle.fill").font(.system(size: 14, weight: .medium)).foregroundStyle(BFColor.red) }

                BFButton(title: "Continue to Analysis", trailingIcon: "arrow.right", kind: .navy) {
                    if let e = model.billDraft.validationError { error = e; Haptics.error(); return }
                    error = nil
                    model.path.append(.eobPrompt)
                }
            }
            .padding(BFSpacing.screen)
            .animation(BFMotion.gentle, value: model.billDraft.lineItems.count)
        }
        .scrollDismissesKeyboard(.interactively)
        .scenicBackground(.capture)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { item in
            LineItemEditor(item: item) { updated in
                if let i = model.billDraft.lineItems.firstIndex(where: { $0.id == updated.id }) { model.billDraft.lineItems[i] = updated }
                else { model.billDraft.lineItems.append(updated) }
            } onDelete: {
                model.billDraft.lineItems.removeAll { $0.id == item.id }
            }
        }
    }

    private func field(_ label: String, _ text: Binding<String>, _ key: BillField, prompt: String, icon: String, keyboard: UIKeyboardType) -> some View {
        BFTextField(label: label, text: text, prompt: prompt, icon: icon, keyboard: keyboard,
                    lowConfidence: model.billDraft.lowConfidence.contains(key),
                    autocapitalization: keyboard == .default ? .words : .never) { model.billDraft.markEdited(key) }
    }

    private var dateRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Date of Service").font(.system(size: 12, weight: .semibold)).foregroundStyle(BFColor.text3)
                if model.billDraft.lowConfidence.contains(.serviceDate) { Pill(text: "Low confidence", tone: .amber, icon: "exclamationmark.triangle.fill", small: true) }
            }
            HStack {
                if let date = model.billDraft.serviceDateStart {
                    DatePicker("Service date", selection: Binding(get: { date }, set: {
                        model.billDraft.serviceDateStart = $0
                        if let end = model.billDraft.serviceDateEnd, end < $0 { model.billDraft.serviceDateEnd = $0 }
                        model.billDraft.markEdited(.serviceDate)
                    }), in: ...Date(), displayedComponents: .date).labelsHidden()
                    Spacer()
                    Button("Clear") { model.billDraft.serviceDateStart = nil; model.billDraft.serviceDateEnd = nil }.font(.footnote)
                } else {
                    Button { model.billDraft.serviceDateStart = Date() } label: { Label("Add date", systemImage: "calendar.badge.plus") }
                        .font(BFFont.label(14))
                    Spacer()
                }
            }
            .padding(.horizontal, 14).frame(minHeight: 52)
            .background(BFColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(BFColor.line))
        }
    }

    private var lineItems: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Line Items (\(model.billDraft.lineItems.count))")
            if model.billDraft.lineItems.isEmpty {
                Text("No itemized charges found. That’s OK — we’ll suggest requesting an itemized bill. You can also add lines yourself.")
                    .font(BFFont.subheadline).foregroundStyle(BFColor.text2).cardStyle()
            }
            ForEach(model.billDraft.lineItems) { item in
                Button { editing = item } label: {
                    HStack(spacing: 12) {
                        Text(item.code.isEmpty ? "—" : item.code).font(BFFont.monoSmall).foregroundStyle(BFColor.blue)
                            .frame(width: 58, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.description).font(.system(size: 15, weight: .medium)).foregroundStyle(BFColor.text1).lineLimit(2).multilineTextAlignment(.leading)
                            if item.quantity != "1" || item.dateOfService != nil {
                                Text([item.quantity != "1" ? "Qty \(item.quantity)" : nil, DateHelpers.display(item.dateOfService)].compactMap { $0 }.joined(separator: " · "))
                                    .font(.system(size: 12)).foregroundStyle(BFColor.text3)
                            }
                        }
                        Spacer()
                        Text(item.totalMoney?.formatted ?? item.total).font(BFFont.money(15)).foregroundStyle(BFColor.text1)
                        if item.isLowConfidence { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(BFColor.amber).font(.system(size: 12)) }
                    }
                    .padding(12)
                    .background(BFColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(item.isLowConfidence ? BFColor.amber.opacity(0.6) : BFColor.line))
                }
                .buttonStyle(.pressable)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
            if let total = Money(parsing: model.billDraft.totalCharges), model.billDraft.lineItems.count >= 2, total != model.billDraft.lineItemsTotal {
                Label("Line items add up to \(model.billDraft.lineItemsTotal.formatted), total charges show \(total.formatted). Check for a missed line.",
                      systemImage: "info.circle.fill")
                    .font(.system(size: 13)).foregroundStyle(BFColor.blue)
            }
            BFButton(title: "Add Line Item", icon: "plus", kind: .ghost, size: .md) {
                editing = LineItemDraft(isUserEdited: true)
            }
        }
    }
}

struct LineItemEditor: View {
    @State var item: LineItemDraft
    let onSave: (LineItemDraft) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Charge") {
                    TextField("Code (CPT / HCPCS, optional)", text: $item.code).textInputAutocapitalization(.characters).font(BFFont.mono)
                    TextField("Description", text: $item.description, axis: .vertical)
                }
                Section("Amount") {
                    TextField("Quantity", text: $item.quantity).keyboardType(.numberPad)
                    TextField("Unit price (optional)", text: $item.unitPrice).keyboardType(.decimalPad)
                    TextField("Line total", text: $item.total).keyboardType(.decimalPad)
                }
                Section {
                    DatePicker("Date of service", selection: Binding(get: { item.dateOfService ?? Date() }, set: { item.dateOfService = $0 }),
                               in: ...Date(), displayedComponents: .date)
                }
                if let error { Section { Text(error).foregroundStyle(BFColor.red) } }
                Section { Button("Delete Line", role: .destructive) { onDelete(); dismiss() } }
            }
            .navigationTitle("Line Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !item.description.trimmed.isEmpty else { error = "Add a description"; return }
                        guard item.totalMoney != nil else { error = "Enter a valid line total"; return }
                        item.isUserEdited = true
                        Haptics.success()
                        onSave(item)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
