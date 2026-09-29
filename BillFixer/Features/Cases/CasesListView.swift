import SwiftUI

/// Board screens 15 / 24 (dark) / 22 (empty).
struct CasesListView: View {
    @Environment(AppRouter.self) private var router
    @Environment(CasesStore.self) private var store
    @Environment(AppSession.self) private var session
    @State private var filter: Filter = .active
    @State private var search = ""
    @State private var pendingDelete: CaseSummary?

    enum Filter: String, CaseIterable, Identifiable { case active = "Active", resolved = "Resolved", closed = "Closed"; var id: String { rawValue } }

    private var items: [CaseSummary] {
        let base: [CaseSummary] = switch filter {
        case .active: store.active
        case .resolved: store.resolved
        case .closed: store.closed
        }
        let q = search.trimmed.lowercased()
        return q.isEmpty ? base : base.filter { $0.displayName.lowercased().contains(q) || $0.title.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, BFSpacing.screen).padding(.top, 8)
            if store.cases.isEmpty && store.hasLoaded {
                Spacer()
                EmptyStateView(title: "No Cases Yet",
                               message: "Scan your first medical bill to get started. We’ll check for errors, compare prices, and help you take action.",
                               buttonTitle: "Scan Your First Bill", buttonIcon: "doc.viewfinder", action: { router.startCapture() }) {
                    FolderIllustration()
                }
                Spacer()
            } else {
                filterBar.padding(.horizontal, BFSpacing.screen).padding(.vertical, 12)
                list
            }
        }
        .scenicBackground(.cases)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Delete this case?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible, presenting: pendingDelete) { item in
            Button("Delete Case", role: .destructive) { Task { await store.delete(item.id) } }
        } message: { _ in
            Text("This permanently deletes the case, its bill details, findings, letters and timeline. This can’t be undone.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("My Cases").font(BFFont.title(28)).foregroundStyle(BFColor.text1)
            Spacer()
            IconButton(symbol: "plus", tint: .white, fill: BFColor.blue, label: "New case") {
                if !session.isPremium && store.active.count >= 1 { router.requirePremium(.cases) } else { router.startCapture() }
            }
        }
    }

    private var filterBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(Filter.allCases) { f in
                    let count = f == .active ? store.active.count : f == .resolved ? store.resolved.count : store.closed.count
                    Button {
                        Haptics.selection()
                        withAnimation(BFMotion.snappy) { filter = f }
                    } label: {
                        Text("\(f.rawValue) (\(count))")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(filter == f ? .white : BFColor.text2)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(filter == f ? AnyShapeStyle(BFGradient.blue) : AnyShapeStyle(BFColor.surface), in: Capsule())
                            .overlay(Capsule().strokeBorder(BFColor.line, lineWidth: filter == f ? 0 : 1))
                    }
                    .buttonStyle(.pressableQuiet)
                }
                Spacer()
            }
            if store.cases.count > 4 {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(BFColor.text3)
                    TextField("Search providers", text: $search).textInputAutocapitalization(.never)
                }
                .padding(12)
                .background(BFColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var list: some View {
        if case let .failed(error) = store.state, store.cases.isEmpty {
            ErrorStateView(error: error) { Task { await store.load(force: true) } }
            Spacer()
        } else if !store.hasLoaded {
            SkeletonList(rows: 4).padding(.horizontal, BFSpacing.screen)
            Spacer()
        } else {
            List {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    Button { router.push(.caseDetail(item.id)) } label: { CaseCard(item: item) }
                        .buttonStyle(.pressable)
                        .staggeredAppear(i)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: BFSpacing.screen, bottom: 6, trailing: BFSpacing.screen))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { pendingDelete = item } label: { Label("Delete", systemImage: "trash") }
                        }
                }
                if items.isEmpty {
                    Text(search.isEmpty ? "No \(filter.rawValue.lowercased()) cases." : "No matches for “\(search)”.")
                        .font(BFFont.subheadline).foregroundStyle(BFColor.text3)
                        .frame(maxWidth: .infinity).padding(.top, 40)
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { await store.load(force: true) }
        }
    }
}
