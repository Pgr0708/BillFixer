import SwiftUI

/// Board screens 06 (light) / 23 (dark).
struct HomeView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(CasesStore.self) private var store
    @State private var showReminders = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header.staggeredAppear(0)
                if !session.isPremium {
                    PlanBanner(text: "Free Plan — 1 finding preview per bill") { router.requirePremium(.general) }
                        .staggeredAppear(1)
                }
                scanCard.staggeredAppear(2)
                quickActions.staggeredAppear(3)
                if store.totalSavings.value > 0 || store.potentialSavings.value > 0 { savingsCard.staggeredAppear(4) }
                casesSection.staggeredAppear(5)
                learnCard.staggeredAppear(6)
            }
            .padding(.horizontal, BFSpacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .refreshable { await store.load(force: true); await session.refresh() }
        .scenicBackground(.home)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showReminders) { RemindersSheet(cases: store.active) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { router.tab = .settings } label: { Avatar(initial: session.user?.initial ?? "") }
                .buttonStyle(.pressable)
                .accessibilityLabel("Account")
            VStack(alignment: .leading, spacing: 2) {
                Text(DateHelpers.greeting()).font(.system(size: 14, weight: .medium)).foregroundStyle(BFColor.text3)
                Text(session.user?.firstName ?? "there").font(BFFont.title2(22)).foregroundStyle(BFColor.text1).lineLimit(1)
            }
            Spacer()
            IconButton(symbol: store.active.contains { $0.nextDeadline != nil } ? "bell.badge.fill" : "bell.fill",
                       tint: BFColor.navy, label: "Reminders") { showReminders = true }
        }
    }

    private var scanCard: some View {
        Button { router.startCapture() } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Scan a Medical Bill").font(BFFont.title2(21)).foregroundStyle(.white)
                    Text("Photo, PDF or Camera").font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                        Text("Read on your iPhone. Private by design.")
                    }
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(BFColor.teal2).padding(.top, 6)
                }
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .bold)).foregroundStyle(BFColor.navy)
                    .frame(width: 60, height: 60)
                    .background(.white, in: Circle())
                    .bfShadow(.float)
            }
            .padding(20)
            .background {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous).fill(BFGradient.navy)
                    Circle().fill(BFColor.teal.opacity(0.25)).frame(width: 160).offset(x: 50, y: -60)
                    Circle().fill(Color(hex: 0x5B9BFF).opacity(0.25)).frame(width: 110).offset(x: -150, y: 60)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .bfShadow(.navyButton)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Scan a medical bill. Photo, PDF or camera.")
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            quick("Scan Bill", "doc.viewfinder", BFColor.blue, BFColor.blueSoft) { router.startCapture(.camera) }
            quick("Add EOB", "doc.text.fill", BFColor.teal, BFColor.tealSoft) { router.startCapture(.photos) }
            quick("Import PDF", "arrow.down.doc.fill", BFColor.violet, BFColor.violetSoft) { router.startCapture(.pdf) }
        }
    }

    private func quick(_ title: String, _ symbol: String, _ tint: Color, _ fill: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                IconTile(symbol: symbol, tint: tint, fill: fill, size: 46)
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(BFColor.text1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(BFColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(BFColor.line.opacity(0.7)))
            .bfShadow(.subtle)
        }
        .buttonStyle(.pressable)
    }

    private var savingsCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Saved so far").overlineStyle()
                CountUpMoney(money: store.totalSavings, font: BFFont.money(26), color: BFColor.green)
            }
            Spacer()
            Rectangle().fill(BFColor.line).frame(width: 1, height: 40)
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text("Possible savings").overlineStyle()
                CountUpMoney(money: store.potentialSavings, font: BFFont.money(26), color: BFColor.amber)
            }
            Spacer()
        }
        .cardStyle(padding: 18, radius: 20)
    }

    @ViewBuilder
    private var casesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Your Cases", actionTitle: store.cases.isEmpty ? nil : "See All") { router.tab = .cases }
            if store.cases.isEmpty {
                switch store.state {
                case .loading, .idle: SkeletonList(rows: 2)
                case let .failed(error): ErrorStateView(error: error) { Task { await store.load(force: true) } }.cardStyle()
                case .loaded:
                    ActionRow(symbol: "folder.badge.plus", title: "No cases yet", subtitle: "Scan your first bill — we’ll check it for errors.")
                        .onTapGesture { router.startCapture() }
                }
            } else {
                ForEach(Array(store.cases.prefix(3).enumerated()), id: \.element.id) { i, item in
                    Button { router.push(.caseDetail(item.id)) } label: { CaseCard(item: item) }
                        .buttonStyle(.pressable)
                        .staggeredAppear(i + 5)
                }
            }
        }
    }

    private var learnCard: some View {
        Button { router.push(.rights(caseId: nil), on: .learn) } label: {
            ActionRow(symbol: "building.columns.fill", title: "Know your rights",
                      subtitle: "No Surprises Act, financial assistance and more", tint: BFColor.violet, fill: BFColor.violetSoft)
        }
        .buttonStyle(.pressable)
    }
}

/// Bell → upcoming deadlines across open cases.
private struct RemindersSheet: View {
    let cases: [CaseSummary]
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    private var upcoming: [(CaseSummary, NextDeadline)] {
        cases.compactMap { c in c.nextDeadline.map { (c, $0) } }.sorted { $0.1.dueDate < $1.1.dueDate }
    }

    var body: some View {
        NavigationStack {
            Group {
                if upcoming.isEmpty {
                    EmptyStateView(title: "All caught up", message: "Deadlines you add to a case — like the 120-day dispute window — show up here.") {
                        IconTile(symbol: "bell.slash.fill", tint: BFColor.blue, fill: BFColor.blueSoft, size: 80, radius: 26)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List(upcoming, id: \.0.id) { item in
                        Button {
                            dismiss()
                            router.push(.caseDetail(item.0.id))
                        } label: {
                            HStack(spacing: 12) {
                                IconTile(symbol: "calendar.badge.clock", tint: BFColor.red, fill: BFColor.redSoft, size: 40)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.1.label).font(.system(size: 15, weight: .semibold)).foregroundStyle(BFColor.text1)
                                    Text(item.0.displayName).font(.system(size: 13)).foregroundStyle(BFColor.text3)
                                }
                                Spacer()
                                Text(DateHelpers.dueLabel(item.1.dueDate)).font(.system(size: 12, weight: .bold))
                                    .foregroundStyle((DateHelpers.daysUntil(item.1.dueDate) ?? 99) <= 3 ? BFColor.red : BFColor.text2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
