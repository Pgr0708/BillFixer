import SwiftUI

/// Learn tab (screen 30): call scripts by situation + rights + tools.
struct LearnView: View {
    @Environment(\.services) private var services
    @Environment(AppRouter.self) private var router
    @Environment(AppSession.self) private var session
    @State private var scripts: LoadState<[LibraryScript]> = .idle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Learn").font(BFFont.title(28)).foregroundStyle(BFColor.text1)
                    Text("Know your rights. Know what to say.").font(BFFont.subheadline).foregroundStyle(BFColor.text2)
                }
                .staggeredAppear(0)

                HStack(spacing: 12) {
                    tool("Your Rights", "building.columns.fill", BFGradient.navy) { router.push(.rights(caseId: nil)) }
                    tool("Assistance Check", "heart.text.square.fill", BFGradient.teal) { router.push(.assistance(caseId: nil)) }
                }
                .fixedSize(horizontal: false, vertical: true)
                .staggeredAppear(1)

                SectionHeader(title: "Call Scripts")
                switch scripts {
                case let .loaded(list):
                    ForEach(Array(list.enumerated()), id: \.element.id) { i, s in
                        Button { router.push(.libraryScript(s)) } label: {
                            HStack(spacing: 14) {
                                IconTile(symbol: icon(for: s.callTarget), tint: BFColor.teal, fill: BFColor.tealSoft)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(s.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(BFColor.text1).multilineTextAlignment(.leading)
                                    HStack(spacing: 6) {
                                        Text("\(s.branchCount) responses").font(.system(size: 12)).foregroundStyle(BFColor.text3)
                                        if let tag = s.tag { Pill(text: tag, tone: .violet, small: true) }
                                    }
                                }
                                Spacer()
                                Image(systemName: s.locked ? "lock.fill" : "chevron.right").font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(s.locked ? BFColor.amber : BFColor.text4)
                            }
                            .cardStyle(padding: 14, radius: 18)
                        }
                        .buttonStyle(.pressable)
                        .staggeredAppear(i + 2)
                    }
                case let .failed(e): ErrorStateView(error: e) { Task { await load() } }
                default: SkeletonList(rows: 4)
                }
            }
            .padding(BFSpacing.screen)
        }
        .refreshable { await load() }
        .scenicBackground(.learn)
        .toolbar(.hidden, for: .navigationBar)
        .task { if scripts.value == nil { await load() } }
        .onChange(of: session.isPremium) { _, _ in Task { await load() } }
    }

    private func tool(_ title: String, _ symbol: String, _ gradient: LinearGradient, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: symbol).font(.system(size: 26, weight: .semibold)).foregroundStyle(.white)
                Text(title).font(BFFont.title3(16)).foregroundStyle(.white).multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)
            .background(gradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .bfShadow(.card)
        }
        .buttonStyle(.pressable)
    }

    private func icon(for target: String) -> String {
        switch target {
        case "insurer": "cross.case.fill"
        case "collections": "exclamationmark.bubble.fill"
        default: "building.2.fill"
        }
    }

    private func load() async {
        do { scripts = .loaded(try await services.content.library()) } catch {
            if scripts.value == nil { scripts = .failed(error.asAPIError) }
        }
    }
}
