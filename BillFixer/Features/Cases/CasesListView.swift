import SwiftUI

struct CasesListView: View {
    @Environment(AppRouter.self) private var router
    @Environment(CasesStore.self) private var store
    @Environment(AppSession.self) private var session
    @State private var filter: Filter = .active
    @State private var search = ""
    @State private var pendingDelete: CaseSummary?
    @State private var appeared = false

    enum Filter: String, CaseIterable, Identifiable {
        case active = "Active", resolved = "Resolved", closed = "Closed"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .active:   return "clock.fill"
            case .resolved: return "checkmark.circle.fill"
            case .closed:   return "archivebox.fill"
            }
        }
        var tint: Color {
            switch self {
            case .active:   return BFColor.blue
            case .resolved: return BFColor.green
            case .closed:   return BFColor.text3
            }
        }
    }

    private var items: [CaseSummary] {
        let base: [CaseSummary] = switch filter {
        case .active:   store.active
        case .resolved: store.resolved
        case .closed:   store.closed
        }
        let q = search.trimmed.lowercased()
        return q.isEmpty ? base : base.filter {
            $0.displayName.lowercased().contains(q) || $0.title.lowercased().contains(q)
        }
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: 0xEEF4FF), Color(hex: 0xF7F9FD)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            circleDecorations

            VStack(spacing: 0) {
                // Header
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -12)

                // Summary pills
                summaryRow
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: appeared)

                // Filter chips
                filterBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.10), value: appeared)

                // Search (if enough cases)
                if store.cases.count > 4 {
                    searchBar
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .opacity(appeared ? 1 : 0)
                }

                // Content
                if store.cases.isEmpty && store.hasLoaded {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    caseList
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Delete this case?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible, presenting: pendingDelete) { item in
            Button("Delete Case", role: .destructive) { Task { await store.delete(item.id) } }
        } message: { _ in
            Text("This permanently deletes the case, bill details, findings, letters and timeline.")
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) { appeared = true }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("My Cases")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(BFColor.text1)
            Spacer()
            // Circular + button
            Button {
                if !session.isPremium && store.active.count >= 1 {
                    router.requirePremium(.cases)
                } else {
                    router.startCapture()
                }
            } label: {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: 0x2E7DF6), BFColor.navy],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: Color(hex: 0x2E7DF6).opacity(0.35), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New case")
        }
    }

    // MARK: - Summary row (circular stat pills)

    private var summaryRow: some View {
        HStack(spacing: 10) {
            statPill(value: "\(store.active.count)",   label: "Active",   color: BFColor.blue)
            statPill(value: "\(store.resolved.count)", label: "Resolved", color: BFColor.green)
            if store.totalSavings.value > 0 {
                statPill(value: store.totalSavings.formatted, label: "Saved", color: BFColor.amber)
            }
        }
    }

    private func statPill(value: String, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 32, height: 32)
                .overlay {
                    Text(value)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                        .minimumScaleFactor(0.7)
                }
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BFColor.text2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    // MARK: - Filter chips

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases) { f in
                let count = f == .active ? store.active.count : f == .resolved ? store.resolved.count : store.closed.count
                let isActive = filter == f
                Button {
                    Haptics.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { filter = f }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isActive ? .white.opacity(0.25) : f.tint.opacity(0.12))
                            .frame(width: 22, height: 22)
                            .overlay {
                                Image(systemName: f.icon)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(isActive ? .white : f.tint)
                            }
                        Text("\(f.rawValue) \(count)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isActive ? .white : BFColor.text2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isActive
                        ? AnyShapeStyle(LinearGradient(colors: [f.tint, f.tint.opacity(0.8)],
                                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Color.white))
                    .clipShape(Capsule())
                    .shadow(color: isActive ? f.tint.opacity(0.3) : .black.opacity(0.04),
                            radius: isActive ? 8 : 3, y: isActive ? 3 : 1)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(BFColor.blueSoft)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BFColor.blue)
                }
            TextField("Search providers...", text: $search)
                .font(.system(size: 15))
                .textInputAutocapitalization(.never)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Circle()
                        .fill(BFColor.line)
                        .frame(width: 20, height: 20)
                        .overlay {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(BFColor.text3)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Case list

    private var caseList: some View {
        Group {
            if case let .failed(error) = store.state, store.cases.isEmpty {
                ErrorStateView(error: error) { Task { await store.load(force: true) } }
                Spacer()
            } else if !store.hasLoaded {
                SkeletonList(rows: 4).padding(.horizontal, 20)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                            Button { router.push(.caseDetail(item.id)) } label: { CaseCard(item: item) }
                                .buttonStyle(.pressable)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 16)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8)
                                    .delay(0.15 + Double(i) * 0.05), value: appeared)
                                .contextMenu {
                                    Button(role: .destructive) { pendingDelete = item } label: {
                                        Label("Delete Case", systemImage: "trash")
                                    }
                                }
                        }
                        if items.isEmpty {
                            Text(search.isEmpty
                                 ? "No \(filter.rawValue.lowercased()) cases."
                                 : "No matches for \u{201C}\(search)\u{201D}.")
                                .font(.system(size: 15))
                                .foregroundStyle(BFColor.text3)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        }
                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
                .scrollIndicators(.hidden)
                .refreshable { await store.load(force: true) }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(BFColor.blueSoft)
                    .frame(width: 100, height: 100)
                Circle()
                    .fill(BFColor.bluePale)
                    .frame(width: 130, height: 130)
                    .overlay { Circle().strokeBorder(BFColor.line, lineWidth: 1) }
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(BFColor.blue)
            }
            VStack(spacing: 8) {
                Text("No Cases Yet")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(BFColor.text1)
                Text("Scan your first medical bill to get started.\nWe'll check for errors and help you take action.")
                    .font(.system(size: 15))
                    .foregroundStyle(BFColor.text3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            Button { router.startCapture() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 15, weight: .bold))
                    Text("Scan Your First Bill")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(LinearGradient(colors: [Color(hex: 0x2E7DF6), BFColor.navy],
                                           startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
                .shadow(color: Color(hex: 0x2E7DF6).opacity(0.35), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
        }
        .padding(32)
    }

    // MARK: - Background circles

    private var circleDecorations: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0x2E7DF6).opacity(0.05))
                .frame(width: 280, height: 280)
                .offset(x: 160, y: -140)
            Circle()
                .fill(Color(hex: 0x00BFA5).opacity(0.06))
                .frame(width: 220, height: 220)
                .offset(x: -120, y: 400)
        }
    }
}
