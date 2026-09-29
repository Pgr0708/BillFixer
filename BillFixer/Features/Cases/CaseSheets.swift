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
    @State private var speech = SpeechTranscriber()
    /// Text typed before dictation started; spoken words are appended to it.
    @State private var dictationBase = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(3...8)
                    .padding(14)
                    .background(BFColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(BFColor.line))
                    .onChange(of: text) { _, t in if t.count > maxLength { text = String(t.prefix(maxLength)) } }
                HStack {
                    micButton
                    Spacer()
                    Text("\(text.count)/\(maxLength)").font(.caption).foregroundStyle(BFColor.text3)
                }
                BFButton(title: button, kind: .navy, isLoading: saving, isDisabled: text.trimmed.isEmpty) {
                    speech.stop()
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
        .onDisappear { speech.cancel() }
        .onChange(of: speech.transcript) { _, spoken in
            guard !spoken.isEmpty else { return }
            let joined = dictationBase.isEmpty ? spoken : dictationBase + " " + spoken
            text = String(joined.prefix(maxLength))
        }
    }

    private var micButton: some View {
        Button {
            if speech.isRecording {
                Haptics.tapLight()
                speech.stop()
            } else {
                Haptics.tap()
                dictationBase = text.trimmed
                Task {
                    do { try await speech.start() } catch { Toast.error("Can’t start voice typing", error.localizedDescription) }
                }
            }
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    if speech.isRecording {
                        Circle().fill(BFColor.red.opacity(0.25)).frame(width: 40, height: 40)
                            .phaseAnimator([1.0, 1.35]) { v, s in v.scaleEffect(s) } animation: { _ in .easeInOut(duration: 0.7) }
                    }
                    Circle().fill(speech.isRecording ? AnyShapeStyle(BFColor.red) : AnyShapeStyle(BFGradient.aurora)).frame(width: 34, height: 34)
                    Image(systemName: speech.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 40, height: 40)
                Text(speech.isRecording ? "Listening… tap to stop" : "Speak instead of typing")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(speech.isRecording ? BFColor.red : BFColor.text2)
            }
        }
        .buttonStyle(.pressable)
        .animation(BFMotion.gentle, value: speech.isRecording)
        .accessibilityLabel(speech.isRecording ? "Stop voice typing" : "Start voice typing")
    }
}
