import SwiftUI

struct AmountSheet: View {
    let title: String
    let message: String
    var initial: Money?
    let button: String
    let onSave: (Money) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var error: String?
    @State private var saving = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(message).font(BFFont.subheadline).foregroundStyle(BFColor.text2)
                BFTextField(label: "Amount", text: $text, prompt: "0.00", icon: "dollarsign", keyboard: .decimalPad, error: error)
                BFButton(title: button, kind: .navy, isLoading: saving) { Task { await save() } }
                Spacer()
            }
            .padding(24)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium])
        .onAppear { text = initial?.apiString ?? "" }
    }

    private func save() async {
        guard let m = Money(parsing: text), !m.isNegative else { error = "Enter an amount like 1234.56"; Haptics.error(); return }
        saving = true
        defer { saving = false }
        if await onSave(m) { dismiss() }
    }
}

struct ResolveCaseSheet: View {
    let original: Money?
    let onSave: (String, Money, String?) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var resolution = "partial_reduction"
    @State private var amount = ""
    @State private var notes = ""
    @State private var error: String?
    @State private var saving = false

    private let options: [(String, String)] = [
        ("full_reduction", "Bill fully removed"), ("partial_reduction", "Bill reduced"), ("financial_assistance", "Financial assistance approved"),
        ("payment_plan", "Payment plan set up"), ("denied", "Request denied"), ("no_change", "No change"), ("other", "Other"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("What happened?") {
                    Picker("Outcome", selection: $resolution) { ForEach(options, id: \.0) { Text($0.1).tag($0.0) } }
                        .pickerStyle(.inline).labelsHidden()
                        .hapticOnChange(resolution)
                }
                Section {
                    TextField("Final amount you owe", text: $amount).keyboardType(.decimalPad)
                    if let original { Text("Original: \(original.formatted)").font(.footnote).foregroundStyle(BFColor.text3) }
                    if let error { Text(error).font(.footnote).foregroundStyle(BFColor.red) }
                } header: { Text("Final balance") }
                Section("Notes (optional)") { TextField("Anything worth remembering", text: $notes, axis: .vertical).lineLimit(2...5) }
            }
            .navigationTitle("Resolve Case")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(saving).fontWeight(.semibold)
                }
            }
            .onChange(of: resolution) { _, r in if r == "full_reduction" { amount = "0.00" } }
        }
    }

    private func save() async {
        guard let m = Money(parsing: amount), !m.isNegative else { error = "Enter the final amount (0 if nothing is owed)"; Haptics.error(); return }
        saving = true
        defer { saving = false }
        if await onSave(resolution, m, notes.trimmed.isEmpty ? nil : notes.trimmed) { dismiss() }
    }
}

struct AddDeadlineSheet: View {
    let onSave: (String, String, Date) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var type = "follow_up"
    @State private var label = "Follow up with billing office"
    @State private var date = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var saving = false

    private let presets: [(String, String, Int)] = [
        ("follow_up", "Follow up with billing office", 14),
        ("insurance_appeal", "Insurance appeal deadline", 180),
        ("ppdr_120day", "Good Faith Estimate dispute window (120 days)", 120),
        ("fa_application", "Financial assistance application", 30),
        ("custom", "Custom reminder", 7),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Type", selection: $type) { ForEach(presets, id: \.0) { Text($0.1).tag($0.0) } }
                        .pickerStyle(.inline).labelsHidden()
                        .hapticOnChange(type)
                }
                Section("Details") {
                    TextField("Label", text: $label)
                    DatePicker("Due date", selection: $date, in: Date()..., displayedComponents: .date)
                        .hapticOnChange(date)
                }
                Section { Label("We’ll remind you 7 days, 1 day and the morning it’s due.", systemImage: "bell.badge").font(.footnote) }
            }
            .navigationTitle("Add Deadline")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: type) { _, t in
                if let p = presets.first(where: { $0.0 == t }) {
                    label = p.1
                    date = Calendar.current.date(byAdding: .day, value: p.2, to: Date()) ?? date
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            saving = true
                            if await onSave(type, label.trimmed.isEmpty ? "Reminder" : label.trimmed, date) { dismiss() }
                            saving = false
                        }
                    }
                    .disabled(saving).fontWeight(.semibold)
                }
            }
        }
    }
}

struct TextEntrySheet: View {
    let title: String
    let placeholder: String
    var initial: String = ""
    let button: String
    var maxLength = 500
    let onSave: (String) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var saving = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(3...8)
                    .padding(14)
                    .background(BFColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(BFColor.line))
                    .onChange(of: text) { _, t in if t.count > maxLength { text = String(t.prefix(maxLength)) } }
                Text("\(text.count)/\(maxLength)").font(.caption).foregroundStyle(BFColor.text3).frame(maxWidth: .infinity, alignment: .trailing)
                BFButton(title: button, kind: .navy, isLoading: saving, isDisabled: text.trimmed.isEmpty) {
                    Task {
                        saving = true
                        if await onSave(text.trimmed) { dismiss() }
                        saving = false
                    }
                }
                Spacer()
            }
            .padding(24)
            .background(BFColor.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .onAppear { text = initial }
    }
}
