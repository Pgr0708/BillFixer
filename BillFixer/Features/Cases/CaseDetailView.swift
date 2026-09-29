import SwiftUI

/// Screen 29: header card + Summary / Documents / Findings / Letters / Timeline.
struct CaseDetailView: View {
    let caseId: String
    @Environment(\.services) private var services
    @Environment(AppRouter.self) private var router
    @Environment(CasesStore.self) private var store
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var model: CaseDetailModel?
    @State private var tab: Tab = .summary
    @State private var sheet: Sheet?
    @State private var confirmDelete = false

    enum Tab: String, CaseIterable, Identifiable { case summary = "Summary", documents = "Documents", findings = "Findings", letters = "Letters", timeline = "Timeline"; var id: String { rawValue } }
    enum Sheet: String, Identifiable { case balance, resolve, deadline, note, rename; var id: String { rawValue } }

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                ProgressView()
            }
        }
        .scenicBackground(.cases)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil { model = CaseDetailModel(caseId: caseId, services: services) }
            await model?.load()
        }
    }

    @ViewBuilder
    private func content(_ model: CaseDetailModel) -> some View {
        if let info = model.info {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard(info, model).staggeredAppear(0)
                    tabs.staggeredAppear(1)
                    Group {
                        switch tab {
                        case .summary: summary(info, model)
                        case .documents: documents(model)
                        case .findings: findingsTab(model)
                        case .letters: letters(model)
                        case .timeline: timeline(model)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                .padding(.horizontal, BFSpacing.screen)
                .padding(.bottom, 30)
                .animation(BFMotion.gentle, value: tab)
            }
            .refreshable { await model.load() }
            .loadingOverlay(model.isWorking)
            .toolbar { toolbar(info, model) }
            .sheet(item: $sheet) { s in sheetView(s, info, model) }
            .confirmationDialog("Delete this case?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Case", role: .destructive) {
                    Task { await store.delete(caseId); dismiss() }
                }
            } message: { Text("This permanently deletes the case and everything in it. This can’t be undone.") }
        } else if case let .failed(error) = model.state {
            ErrorStateView(error: error) { Task { await model.load() } }
        } else {
            VStack { SkeletonBlock(height: 160, radius: 24); SkeletonList(rows: 3) }.padding(BFSpacing.screen)
        }
    }

    @ToolbarContentBuilder
    private func toolbar(_ info: CaseDetail, _ model: CaseDetailModel) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { sheet = .balance } label: { Label("Update Balance", systemImage: "dollarsign.circle") }
                Button { sheet = .deadline } label: { Label("Add Deadline", systemImage: "calendar.badge.plus") }
                Button { sheet = .note } label: { Label("Log a Call or Note", systemImage: "note.text.badge.plus") }
                Button { sheet = .rename } label: { Label("Rename", systemImage: "pencil") }
                Divider()
                if info.status == .resolved || info.status == .closed {
                    Button { Task { _ = await model.setStatus(.active); await store.load(force: true) } } label: { Label("Reopen Case", systemImage: "arrow.uturn.backward") }
                } else {
                    Button { sheet = .resolve } label: { Label("Mark Resolved", systemImage: "checkmark.seal") }
                    Button { Task { _ = await model.setStatus(.closed); await store.load(force: true) } } label: { Label("Close Case", systemImage: "archivebox") }
                }
                Divider()
                Button(role: .destructive) { confirmDelete = true } label: { Label("Delete Case", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis.circle").font(.system(size: 18, weight: .semibold))
            }
            .accessibilityLabel("Case actions")
        }
    }

    private func headerCard(_ info: CaseDetail, _ model: CaseDetailModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(info.providerName ?? info.title).font(BFFont.title2(22)).foregroundStyle(.white).lineLimit(2)
                    Text([DateHelpers.display(info.billDate), info.insurerName].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                Pill(text: info.status.title, tone: .glass, small: true)
            }
            HStack(alignment: .bottom, spacing: 22) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CURRENT BALANCE").font(BFFont.overline).foregroundStyle(.white.opacity(0.65))
                    CountUpMoney(money: info.currentBalance ?? info.originalBalance ?? .zero, font: BFFont.money(32), color: .white, compact: false)
                }
                if let original = info.originalBalance, let current = info.currentBalance, original != current {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ORIGINAL").font(BFFont.overline).foregroundStyle(.white.opacity(0.65))
                        Text(original.formatted).font(BFFont.money(17)).foregroundStyle(.white.opacity(0.7)).strikethrough()
                    }
                }
            }
            if let saved = info.verifiedSavings, saved.value > 0 {
                Label("You saved \(saved.formatted)", systemImage: "checkmark.seal.fill")
                    .font(BFFont.label(14)).foregroundStyle(BFColor.teal2)
            } else if let potential = info.potentialSavings, potential.value > 0 {
                Label("Up to \(potential.formattedCompact) may be disputable", systemImage: "sparkles")
                    .font(BFFont.label(14)).foregroundStyle(Color(hex: 0xFFC554))
            }
        }
        .padding(20)
        .background {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(BFGradient.navy)
                Circle().fill(BFColor.teal.opacity(0.22)).frame(width: 170).offset(x: 60, y: -70)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .bfShadow(.navyButton)
    }

    private var tabs: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(Tab.allCases) { t in
                    Button {
                        Haptics.selection()
                        tab = t
                    } label: {
                        Text(t.rawValue).font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(tab == t ? BFColor.navy : BFColor.text3)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(tab == t ? BFColor.surface : .clear, in: Capsule())
                            .bfShadow(tab == t ? .subtle : BFShadow(color: .clear, radius: 0, y: 0))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(BFColor.line.opacity(0.5), in: Capsule())
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Tabs

    @ViewBuilder
    private func summary(_ info: CaseDetail, _ model: CaseDetailModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if info.lastAnalyzedAt != nil {
                Button { router.push(.results(caseId)) } label: {
                    ActionRow(symbol: "chart.pie.fill", title: "View analysis results",
                              subtitle: "\(info.findingCount) finding\(info.findingCount == 1 ? "" : "s") · \(DateHelpers.display(info.lastAnalyzedAt) ?? "")",
                              tint: BFColor.violet, fill: BFColor.violetSoft)
                }.buttonStyle(.pressable)
            } else {
                HStack(spacing: 12) {
                    if model.analysisRunning { ProgressView() }
                    Text(model.analysisRunning ? "Analysis in progress… pull to refresh." : "This case hasn’t been analyzed yet.")
                        .font(BFFont.subheadline).foregroundStyle(BFColor.text2)
                }
                .cardStyle()
            }

            if let deadlines = model.detail?.deadlines, !deadlines.isEmpty {
                SectionHeader(title: "Deadlines", actionTitle: "Add") { sheet = .deadline }.padding(.top, 6)
                ForEach(deadlines) { d in deadlineRow(d, model) }
            } else {
                Button { sheet = .deadline } label: {
                    ActionRow(symbol: "calendar.badge.plus", title: "Add a deadline", subtitle: "Get reminded before disputes or payments are due",
                              tint: BFColor.red, fill: BFColor.redSoft)
                }.buttonStyle(.pressable)
            }

            SectionHeader(title: "Next steps").padding(.top, 6)
            Button { router.push(.newScript(caseId: caseId, findingId: nil, callTarget: "provider_billing", issueType: "itemized_bill")) } label: {
                ActionRow(symbol: "phone.fill", title: "Call the billing office", subtitle: "Get a step-by-step script", tint: BFColor.teal, fill: BFColor.tealSoft,
                          locked: !session.isPremium)
            }.buttonStyle(.pressable)
            Button { router.push(.assistance(caseId: caseId)) } label: {
                ActionRow(symbol: "heart.text.square.fill", title: "Check financial assistance", subtitle: "See if you may qualify for free or discounted care",
                          tint: BFColor.green, fill: BFColor.greenSoft)
            }.buttonStyle(.pressable)
            if info.status != .resolved {
                BFButton(title: "Mark Case Resolved", icon: "checkmark.seal.fill", kind: .teal, size: .md) { sheet = .resolve }.padding(.top, 6)
            }
            if let notes = info.notes, !notes.isEmpty {
                Text(notes).font(BFFont.subheadline).foregroundStyle(BFColor.text2).cardStyle()
            }
        }
    }

    private func deadlineRow(_ d: Deadline, _ model: CaseDetailModel) -> some View {
        HStack(spacing: 12) {
            Button { Task { await model.toggleDeadline(d) } } label: {
                Image(systemName: d.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22)).foregroundStyle(d.isCompleted ? BFColor.green : BFColor.text4)
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(d.isCompleted ? "Mark not done" : "Mark done")
            VStack(alignment: .leading, spacing: 2) {
                Text(d.label).font(.system(size: 15, weight: .semibold)).foregroundStyle(BFColor.text1).strikethrough(d.isCompleted)
                Text("\(DateHelpers.display(d.dueDate) ?? d.dueDate) · \(DateHelpers.dueLabel(d.dueDate))").font(.system(size: 12))
                    .foregroundStyle(!d.isCompleted && (DateHelpers.daysUntil(d.dueDate) ?? 99) <= 3 ? BFColor.red : BFColor.text3)
            }
            Spacer()
            Menu {
                Button(role: .destructive) { Task { await model.deleteDeadline(d) } } label: { Label("Delete", systemImage: "trash") }
            } label: { Image(systemName: "ellipsis").foregroundStyle(BFColor.text3).frame(width: 32, height: 32) }
        }
        .cardStyle(padding: 12, radius: 16)
    }

    @ViewBuilder
    private func documents(_ model: CaseDetailModel) -> some View {
        let docs = model.detail?.documents ?? []
        if docs.isEmpty {
            Text("No documents yet.").font(BFFont.subheadline).foregroundStyle(BFColor.text3).cardStyle()
        } else {
            ForEach(docs) { doc in
                HStack(spacing: 12) {
                    IconTile(symbol: doc.type == "eob" ? "doc.text.fill" : "doc.richtext.fill", tint: doc.type == "eob" ? BFColor.teal : BFColor.blue,
                             fill: doc.type == "eob" ? BFColor.tealSoft : BFColor.blueSoft)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(doc.type == "eob" ? "Explanation of Benefits" : doc.type == "gfe" ? "Good Faith Estimate" : "Medical Bill")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(BFColor.text1)
                        Text("\(doc.pageCount) page\(doc.pageCount == 1 ? "" : "s") · \(doc.source.capitalized) · \(DateHelpers.display(doc.createdAt) ?? "")")
                            .font(.system(size: 12)).foregroundStyle(BFColor.text3)
                    }
                    Spacer()
                    if let c = doc.ocrConfidence { Pill(text: "\(Int(c * 100))%", tone: c < 0.7 ? .amber : .green, small: true) }
                }
                .cardStyle(padding: 12, radius: 16)
            }
            Label("Images stay on your iPhone. Only the details you confirmed are saved.", systemImage: "lock.shield")
                .font(.system(size: 12)).foregroundStyle(BFColor.text3)
        }
    }

    @ViewBuilder
    private func findingsTab(_ model: CaseDetailModel) -> some View {
        if let f = model.findings, !f.findings.isEmpty {
            ForEach(f.findings.prefix(6)) { finding in
                Button {
                    if finding.locked { router.requirePremium(.findings) } else { router.push(.finding(caseId: caseId, finding: finding)) }
                } label: { FindingCard(finding: finding) }
                .buttonStyle(.pressable)
            }
            if f.findings.count > 6 {
                BFButton(title: "See all \(f.findings.count) findings", kind: .outline, size: .md) { router.push(.findings(caseId)) }
            }
        } else {
            Text(model.info?.lastAnalyzedAt == nil ? "Findings appear after analysis." : "No issues were found on this bill.")
                .font(BFFont.subheadline).foregroundStyle(BFColor.text3).cardStyle()
        }
    }

    @ViewBuilder
    private func letters(_ model: CaseDetailModel) -> some View {
        let letters = model.detail?.letters ?? []
        let scripts = model.detail?.scripts ?? []
        if letters.isEmpty && scripts.isEmpty {
            Text("Letters and phone scripts you create will be saved here.").font(BFFont.subheadline).foregroundStyle(BFColor.text3).cardStyle()
        }
        ForEach(letters) { l in
            Button { router.push(.letter(caseId: caseId, letterId: l.id)) } label: {
                ActionRow(symbol: l.sentAt != nil ? "paperplane.fill" : "envelope.fill", title: l.type.title,
                          subtitle: l.sentAt != nil ? "Sent \(DateHelpers.display(l.sentAt) ?? "")" : "Draft · v\(l.version)",
                          tint: l.sentAt != nil ? BFColor.teal : BFColor.amber, fill: l.sentAt != nil ? BFColor.tealSoft : BFColor.amberSoft)
            }.buttonStyle(.pressable)
        }
        ForEach(scripts) { s in
            Button { router.push(.script(caseId: caseId, scriptId: s.id)) } label: {
                ActionRow(symbol: "phone.fill", title: "Phone script", subtitle: s.callTarget.replacingOccurrences(of: "_", with: " ").capitalized)
            }.buttonStyle(.pressable)
        }
    }

    @ViewBuilder
    private func timeline(_ model: CaseDetailModel) -> some View {
        if model.events.isEmpty {
            Text("Nothing here yet.").font(BFFont.subheadline).foregroundStyle(BFColor.text3).cardStyle()
        } else {
            VStack(spacing: 0) {
                ForEach(Array(model.events.enumerated()), id: \.element.id) { i, e in
                    TimelineRow(event: e, isLast: i == model.events.count - 1).staggeredAppear(i)
                }
            }
            .cardStyle(padding: 18, radius: 20)
            BFButton(title: "Log a Call or Note", icon: "plus", kind: .outline, size: .md) { sheet = .note }
        }
    }

    // MARK: Sheets

    @ViewBuilder
    private func sheetView(_ s: Sheet, _ info: CaseDetail, _ model: CaseDetailModel) -> some View {
        switch s {
        case .balance:
            AmountSheet(title: "Update Balance", message: "Enter the latest balance from your statement or the billing office.",
                        initial: info.currentBalance, button: "Save Balance") { money in
                let ok = await model.updateBalance(money)
                if ok { await store.load(force: true) }
                return ok
            }
        case .resolve:
            ResolveCaseSheet(original: info.originalBalance ?? info.currentBalance) { resolution, final, notes in
                if let saved = await model.resolve(resolution: resolution, finalBalance: final, notes: notes) {
                    await store.load(force: true)
                    Toast.success(saved.value > 0 ? "You saved \(saved.formatted)!" : "Case resolved", "Great work following through.")
                    return true
                }
                return false
            }
        case .deadline:
            AddDeadlineSheet { type, label, date in await model.addDeadline(type: type, label: label, due: date) }
        case .note:
            TextEntrySheet(title: "Log a Call or Note", placeholder: "e.g. Called billing, spoke to Maria, reference #4411. They’re reviewing the duplicate charge.",
                           button: "Save Note", maxLength: 1000) { await model.addNote($0) }
        case .rename:
            TextEntrySheet(title: "Rename Case", placeholder: "Case name", initial: info.title, button: "Save", maxLength: 120) {
                let ok = await model.rename($0)
                if ok { await store.load(force: true) }
                return ok
            }
        }
    }
}

/// Screen 18 — standalone timeline.
struct CaseTimelineView: View {
    let caseId: String
    @Environment(\.services) private var services
    @State private var events: LoadState<[CaseEvent]> = .idle

    var body: some View {
        ScrollView {
            switch events {
            case let .loaded(list):
                VStack(spacing: 0) {
                    ForEach(Array(list.enumerated()), id: \.element.id) { i, e in TimelineRow(event: e, isLast: i == list.count - 1).staggeredAppear(i) }
                }
                .cardStyle(padding: 18, radius: 20)
                .padding(BFSpacing.screen)
            case let .failed(e): ErrorStateView(error: e) { Task { await load() } }
            default: SkeletonList(rows: 5).padding(BFSpacing.screen)
            }
        }
        .navigationTitle("Case Timeline")
        .scenicBackground(.cases)
        .task { await load() }
    }

    private func load() async {
        do { events = .loaded(try await services.cases.events(caseId)) } catch { events = .failed(error.asAPIError) }
    }
}
