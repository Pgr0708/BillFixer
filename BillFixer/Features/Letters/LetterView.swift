import SwiftUI

/// Screen 14 — Template → Review → Send.
struct LetterView: View {
    enum Source: Hashable { case existing(String), generate(findingId: String?, type: LetterType) }
    let caseId: String
    let source: Source

    @Environment(\.services) private var services
    @Environment(AppRouter.self) private var router
    @State private var letter: Letter?
    @State private var draft = ""
    @State private var failed: APIError?
    @State private var generating = false
    @State private var isEditing = false
    @State private var saving = false
    @State private var pdfURL: URL?
    @State private var askFollowUp = false
    @State private var progressText = "Drafting your letter…"
    @FocusState private var editorFocused: Bool

    private var step: Int { letter == nil ? 0 : (letter?.sentAt != nil ? 2 : 1) }
    private var isDirty: Bool { letter.map { draft != $0.content } ?? false }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                StepIndicator(steps: ["Template", "Review", "Send"], current: step)
                if let letter {
                    header(letter)
                    letterBody
                    actions(letter)
                } else if let failed {
                    ErrorStateView(error: failed) { Task { await load() } }
                } else {
                    generatingCard
                }
            }
            .padding(BFSpacing.screen)
        }
        .scrollDismissesKeyboard(.interactively)
        .scenicBackground(.letter)
        .navigationTitle("Dispute Letter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.fontWeight(.semibold).disabled(saving || !isDirty)
                }
            }
        }
        .task { if letter == nil { await load() } }
        .onDisappear { if let pdfURL { try? FileManager.default.removeItem(at: pdfURL) } }
        .confirmationDialog("Add a follow-up reminder?", isPresented: $askFollowUp, titleVisibility: .visible) {
            Button("Remind me in 30 days") {
                Task {
                    let due = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
                    do {
                        try await services.cases.addDeadline(caseId, CreateDeadlineRequest(type: "follow_up", label: "Follow up on \(letter?.type.title.lowercased() ?? "letter")",
                                                                                          dueDate: DateHelpers.dayString(due), notifyDays: [3, 0]))
                        Toast.success("Reminder set", "We’ll nudge you in 30 days.")
                    } catch { Toast.error(error) }
                }
            }
            Button("Not now", role: .cancel) {}
        } message: { Text("Providers usually respond within 30 days.") }
    }

    private var generatingCard: some View {
        VStack(spacing: 16) {
            ForEach(0..<8, id: \.self) { i in SkeletonBlock(height: 12).frame(maxWidth: i % 3 == 2 ? 200 : .infinity) }
            HStack(spacing: 10) {
                ProgressView()
                Text(progressText).font(BFFont.subheadline).foregroundStyle(BFColor.text2)
            }
            .padding(.top, 6)
        }
        .cardStyle(padding: 20, radius: 20)
    }

    private func header(_ l: Letter) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l.type.title).font(BFFont.serifBold(20)).foregroundStyle(BFColor.text1)
            HStack(spacing: 8) {
                Text(l.isFallback ? "Standard template · pre-filled" : "Pre-filled with your details").font(.system(size: 13)).foregroundStyle(BFColor.text3)
                if l.sentAt != nil { Pill(text: "Sent \(DateHelpers.display(l.sentAt) ?? "")", tone: .green, icon: "paperplane.fill", small: true) }
                if isDirty { Pill(text: "Unsaved", tone: .amber, small: true) }
            }
        }
    }

    private var letterBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isEditing {
                TextEditor(text: $draft)
                    .font(BFFont.letter)
                    .frame(minHeight: 420)
                    .scrollContentBackground(.hidden)
                    .focused($editorFocused)
            } else {
                Text(draft).font(BFFont.letter).foregroundStyle(Color(light: 0x1F2937, dark: 0xE6EBF4)).lineSpacing(5).textSelection(.enabled)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(light: 0xFFFFFF, dark: 0x1A1F2A), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(BFColor.line))
        .bfShadow(.card)
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation(BFMotion.snappy) { isEditing.toggle() }
                editorFocused = isEditing
                Haptics.selection()
            } label: {
                Image(systemName: isEditing ? "eye" : "pencil").font(.system(size: 14, weight: .bold)).foregroundStyle(BFColor.blue)
                    .frame(width: 36, height: 36).background(BFColor.blueSoft, in: Circle())
            }
            .padding(8)
            .accessibilityLabel(isEditing ? "Preview" : "Edit letter")
        }
    }

    private func actions(_ l: Letter) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                BFButton(title: "Copy", icon: "doc.on.doc", kind: .outline, size: .md) {
                    UIPasteboard.general.string = draft
                    Toast.success("Copied to clipboard")
                }
                if let pdfURL {
                    ShareLink(item: pdfURL) {
                        Label("Share PDF", systemImage: "square.and.arrow.up").font(BFFont.label(15)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(BFGradient.blue, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                } else {
                    BFButton(title: "Share", icon: "square.and.arrow.up", kind: .blue, size: .md) { makePDF(l) }
                }
            }
            if l.sentAt == nil {
                BFButton(title: "I Sent This Letter", icon: "paperplane.fill", kind: .teal) { Task { await markSent(l) } }
            }
            Text("Review before sending. Send by certified mail or the provider’s portal and keep a copy.")
                .font(.system(size: 12)).foregroundStyle(BFColor.text3).multilineTextAlignment(.center)
        }
    }

    // MARK: Actions

    private func load() async {
        failed = nil
        do {
            switch source {
            case let .existing(id):
                set(try await services.content.letter(caseId, id))
            case let .generate(findingId, type):
                guard !generating else { return }
                generating = true
                defer { generating = false }
                let job = try await services.content.requestLetter(caseId, CreateLetterRequest(
                    type: findingId == nil ? type.rawValue : nil, findingId: findingId, recipientName: nil, recipientType: type.recipientType))
                let final = try await JobPoller.wait(timeout: .seconds(90), fetch: { try await services.content.job(job.jobId) }) { s in
                    progressText = s.progress > 0.5 ? "Checking facts against your bill…" : "Drafting your letter…"
                }
                guard final.status == "complete", let id = final.resultId else { throw APIError.server(status: 500, code: "LETTER_FAILED", message: "The letter couldn’t be drafted. Please try again.") }
                set(try await services.content.letter(caseId, id))
                Haptics.letterGenerated()
            }
        } catch let error as APIError {
            if case .premiumRequired = error { router.requirePremium(.letters) }
            failed = error
        } catch { failed = error.asAPIError }
    }

    private func set(_ l: Letter) {
        withAnimation(BFMotion.gentle) {
            letter = l
            draft = l.content
        }
    }

    private func save() async {
        guard let l = letter else { return }
        guard draft.trimmed.count >= 20 else { Toast.warning("Letter is too short"); return }
        saving = true
        defer { saving = false }
        do {
            set(try await services.content.updateLetter(caseId, l.id, content: draft))
            isEditing = false
            pdfURL = nil
            Toast.success("Letter saved")
        } catch { Toast.error(error) }
    }

    private func makePDF(_ l: Letter) {
        do {
            pdfURL = try LetterPDF.render(subject: l.subject, body: draft, fileName: l.type.title)
            Haptics.success()
        } catch { Toast.error("Couldn’t create PDF", error.localizedDescription) }
    }

    private func markSent(_ l: Letter) async {
        if isDirty { await save() }
        do {
            _ = try await services.content.markSent(caseId, l.id)
            set(try await services.content.letter(caseId, l.id))
            Toast.success("Marked as sent", "Added to your case timeline.")
            askFollowUp = true
        } catch { Toast.error(error) }
    }
}
