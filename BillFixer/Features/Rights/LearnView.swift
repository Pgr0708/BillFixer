import SwiftUI

/// Learn tab (screen 30): call scripts by situation + rights + tools.
struct LearnView: View {
    @Environment(\.services) private var services
    @Environment(AppRouter.self) private var router
    @Environment(AppSession.self) private var session
    @State private var scripts: LoadState<[LibraryScript]> = .idle

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xF0F4FF), Color(hex: 0xF7F9FD)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            Circle().fill(BFColor.violetSoft).frame(width: 260).offset(x: 150, y: -100)
            Circle().fill(BFColor.tealSoft).frame(width: 200).offset(x: -110, y: 500)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Learn").font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(BFColor.text1)
                        Text("Know your rights. Know what to say.").font(BFFont.subheadline).foregroundStyle(BFColor.text2)
                    }
                    .staggeredAppear(0)

                    // Tool cards — circular icon + gradient background
                    HStack(spacing: 12) {
                        tool("Your Rights", "building.columns.fill", [Color(hex: 0x0B2B5C), Color(hex: 0x2E7DF6)]) { router.push(.rights(caseId: nil)) }
                        tool("Assistance Check", "heart.text.square.fill", [Color(hex: 0x00897B), Color(hex: 0x00BFA5)]) { router.push(.assistance(caseId: nil)) }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .staggeredAppear(1)

                    // Section header
                    HStack {
                        Circle().fill(BFColor.tealSoft).frame(width: 28, height: 28)
                            .overlay { Image(systemName: "phone.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(BFColor.teal) }
                        Text("Call Scripts").font(.system(size: 13, weight: .bold)).foregroundStyle(BFColor.text3).tracking(0.5)
                    }

                    switch scripts {
                    case let .loaded(list):
                        ForEach(Array(list.enumerated()), id: \.element.id) { i, s in
                            Button { router.push(.libraryScript(s)) } label: {
                                HStack(spacing: 14) {
                                    // Circular icon
                                    Circle()
                                        .fill(s.locked ? BFColor.amberSoft : BFColor.tealSoft)
                                        .frame(width: 44, height: 44)
                                        .overlay {
                                            Image(systemName: s.locked ? "lock.fill" : icon(for: s.callTarget))
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(s.locked ? BFColor.amber : BFColor.teal)
                                        }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(s.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(BFColor.text1).multilineTextAlignment(.leading)
                                        HStack(spacing: 6) {
                                            Text("\(s.branchCount) responses").font(.system(size: 12)).foregroundStyle(BFColor.text3)
                                            if let tag = s.tag { Pill(text: tag, tone: .violet, small: true) }
                                        }
                                    }
                                    Spacer()
                                    // Circular chevron
                                    Circle().fill(BFColor.line.opacity(0.5)).frame(width: 28, height: 28)
                                        .overlay { Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(BFColor.text4) }
                                }
                                .padding(14)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                            }
                            .buttonStyle(.pressable)
                            .staggeredAppear(i + 2)
                        }
                    case let .failed(e): ErrorStateView(error: e) { Task { await load() } }
                    default: SkeletonList(rows: 4)
                    }
                    Spacer().frame(height: 100)
                }
                .padding(BFSpacing.screen)
            }
            .scrollIndicators(.hidden)
        }
        .refreshable { await load() }
        .toolbar(.hidden, for: .navigationBar)
        .task { if scripts.value == nil { await load() } }
        .onChange(of: session.isPremium) { _, _ in Task { await load() } }
    }

    private func tool(_ title: String, _ symbol: String, _ colors: [Color], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                // Circular icon on gradient
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: symbol)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(18)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .shadow(color: colors.first?.opacity(0.35) ?? .clear, radius: 12, y: 5)
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
