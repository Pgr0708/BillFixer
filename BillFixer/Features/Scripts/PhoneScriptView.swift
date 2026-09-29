import SwiftUI

/// Screen 26 — opening line, "What did they say?" branches, do-not-say list, post-call checklist.
struct PhoneScriptView: View {
    enum Source: Hashable {
        case existing(caseId: String, scriptId: String)
        case generate(caseId: String, findingId: String?, callTarget: String, issueType: String)
        case library(LibraryScript)
    }
    let source: Source

    @Environment(\.services) private var services
    @Environment(AppRouter.self) private var router
    @State private var content: ScriptContent?
    @State private var failed: APIError?
    @State private var path: [ScriptBranch] = []
    @State private var checked: Set<String> = []
    @State private var noteText: String?

    private var locked: Bool { if case let .library(s) = source { s.locked } else { false } }
    private var caseId: String? {
        switch source {
        case let .existing(c, _), let .generate(c, _, _, _): c
        case .library: nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let content {
                    callCard(content)
                    branches(content)
                    if let dont = content.doNotSay, !dont.isEmpty { doNotSay(dont) }
                    if !content.postCallChecklist.isEmpty { checklist(content.postCallChecklist) }
                    if locked {
                        BFButton(title: "Unlock the Full Script", icon: "lock.open.fill", kind: .premium) { router.requirePremium(.scripts) }
                    }
                    if caseId != nil {
                        BFButton(title: "Log This Call", icon: "note.text.badge.plus", kind: .outline, size: .md) { noteText = "" }
                    }
                } else if let failed {
                    ErrorStateView(error: failed) { Task { await load() } }
                } else {
                    VStack(spacing: 12) { SkeletonBlock(height: 140, radius: 22); SkeletonList(rows: 3) }
                }
            }
            .padding(BFSpacing.screen)
        }
        .scenicBackground(.script)
        .navigationTitle("Phone Script")
        .navigationBarTitleDisplayMode(.inline)
        .task { if content == nil { await load() } }
        .sheet(isPresented: Binding(get: { noteText != nil }, set: { if !$0 { noteText = nil } })) {
            TextEntrySheet(title: "Log This Call", placeholder: "Who you spoke to, reference number, what they agreed to…", button: "Save to Timeline", maxLength: 1000) { text in
                guard let caseId else { return false }
                do { try await services.cases.addNote(caseId, "Call: \(text)"); Toast.success("Call logged"); return true } catch { Toast.error(error); return false }
            }
        }
    }

    private func callCard(_ c: ScriptContent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconTile(symbol: "phone.fill", tint: .white, fill: .white.opacity(0.2), size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start the call").font(BFFont.title3(17)).foregroundStyle(.white)
                    Text("Have your account number and bill ready").font(.system(size: 12)).foregroundStyle(.white.opacity(0.8))
                }
            }
            Text("“\(c.openingStatement)”").font(BFFont.evidence).foregroundStyle(.white).lineSpacing(3)
            Button {
                UIPasteboard.general.string = c.openingStatement
                Toast.success("Opening line copied")
            } label: { Label("Copy", systemImage: "doc.on.doc").font(BFFont.label(13)).foregroundStyle(.white) }
        }
        .padding(18)
        .background(LinearGradient(colors: [Color(hex: 0x0EA5E9), BFColor.navy2], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .bfShadow(.navyButton)
    }

    private func branches(_ c: ScriptContent) -> some View {
        let current = path.last?.childBranches ?? c.branches
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(path.isEmpty ? "What did they say?" : "Then what did they say?").font(BFFont.title3()).foregroundStyle(BFColor.text1)
                Spacer()
                if !path.isEmpty {
                    Button { withAnimation(BFMotion.gentle) { _ = path.popLast() }; Haptics.selection() } label: { Label("Back", systemImage: "arrow.uturn.backward") }
                        .font(BFFont.label(13))
                }
            }
            if let last = path.last {
                VStack(alignment: .leading, spacing: 8) {
                    Text("YOU SAY").font(BFFont.overline).foregroundStyle(BFColor.teal)
                    Text(last.response).font(.system(size: 15)).foregroundStyle(BFColor.text1)
                    if let f = last.followUp { Text(f).font(.system(size: 14)).foregroundStyle(BFColor.text2).italic() }
                }
                .cardStyle(padding: 14, radius: 16, fill: BFColor.tealSoft, stroke: .clear, shadow: nil)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            ForEach(Array(current.enumerated()), id: \.element.id) { i, b in
                Button {
                    Haptics.selection()
                    withAnimation(BFMotion.gentle) { path.append(b) }
                } label: {
                    HStack(spacing: 12) {
                        Text(String(UnicodeScalar(65 + i).map(Character.init) ?? "•"))
                            .font(BFFont.label(14)).foregroundStyle(BFColor.blue)
                            .frame(width: 30, height: 30).background(BFColor.blueSoft, in: Circle())
                        Text("“\(b.trigger.trimmingCharacters(in: CharacterSet(charactersIn: "\"“” ")))”").font(.system(size: 15, weight: .medium)).foregroundStyle(BFColor.text1).multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(BFColor.text4)
                    }
                    .cardStyle(padding: 12, radius: 16)
                }
                .buttonStyle(.pressable)
            }
            if current.isEmpty && !path.isEmpty {
                Text("That’s the end of this branch. Note what they agreed to and ask for a reference number.")
                    .font(.system(size: 13)).foregroundStyle(BFColor.text3)
            }
        }
    }

    private func doNotSay(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Avoid saying", systemImage: "hand.raised.fill").font(BFFont.label(15)).foregroundStyle(BFColor.red)
            ForEach(items, id: \.self) { Text("• \($0)").font(.system(size: 14)).foregroundStyle(BFColor.text2) }
        }
        .cardStyle(padding: 14, radius: 16, fill: BFColor.redSoft, stroke: .clear, shadow: nil)
    }

    private func checklist(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("After the call").font(BFFont.title3()).foregroundStyle(BFColor.text1)
            ForEach(items, id: \.self) { item in
                Button {
                    Haptics.selection()
                    if checked.contains(item) { checked.remove(item) } else { checked.insert(item) }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: checked.contains(item) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(checked.contains(item) ? BFColor.green : BFColor.text4).font(.system(size: 20))
                            .contentTransition(.symbolEffect(.replace))
                        Text(item).font(.system(size: 14)).foregroundStyle(BFColor.text1).strikethrough(checked.contains(item)).multilineTextAlignment(.leading)
                        Spacer()
                    }
                }
                .buttonStyle(.pressable)
            }
        }
        .cardStyle(padding: 16, radius: 18)
    }

    private func load() async {
        failed = nil
        do {
            switch source {
            case let .library(s): content = s.script
            case let .existing(caseId, id):
                let s = try await services.content.script(caseId, id)
                content = ScriptContent(openingStatement: s.openingStatement, branches: s.branches, doNotSay: s.doNotSay, postCallChecklist: s.postCallChecklist)
            case let .generate(caseId, findingId, target, issue):
                let job = try await services.content.requestScript(caseId, CreateScriptRequest(findingId: findingId, callTarget: target, issueType: String(issue.prefix(60))))
                let final = try await JobPoller.wait(timeout: .seconds(90), fetch: { try await services.content.job(job.jobId) })
                guard final.status == "complete", let id = final.resultId else { throw APIError.server(status: 500, code: "SCRIPT_FAILED", message: "The script couldn’t be prepared. Please try again.") }
                let s = try await services.content.script(caseId, id)
                withAnimation(BFMotion.gentle) {
                    content = ScriptContent(openingStatement: s.openingStatement, branches: s.branches, doNotSay: s.doNotSay, postCallChecklist: s.postCallChecklist)
                }
                Haptics.success()
            }
        } catch let error as APIError {
            if case .premiumRequired = error { router.requirePremium(.scripts) }
            failed = error
        } catch { failed = error.asAPIError }
    }
}
