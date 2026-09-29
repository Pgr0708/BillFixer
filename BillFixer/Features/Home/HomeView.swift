import SwiftUI

// MARK: - Home Dashboard — matches Claude design (screen 06)
struct HomeView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(CasesStore.self) private var store
    @State private var showReminders = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            // ── Soft gradient background with circular decorations ───────
            homeBackground

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // 1. Header: avatar + greeting + bell
                    headerRow
                        .padding(.top, 8)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -12)

                    // 2. Free plan banner (if not premium)
                    if !session.isPremium {
                        freePlanBanner
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 16)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: appeared)
                    }

                    // 3. "Scan a Medical Bill" hero card
                    scanCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.10), value: appeared)

                    // 4. Quick actions grid
                    quickActionsRow
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: appeared)

                    // 5. Savings card (if any)
                    if store.totalSavings.value > 0 || store.potentialSavings.value > 0 {
                        savingsCard
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.18), value: appeared)
                    }

                    // 6. Cases section
                    casesSection
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.22), value: appeared)

                    // 7. Learn card
                    learnCard
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.27), value: appeared)

                    // Bottom padding above tab bar
                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .refreshable { await store.load(force: true); await session.refresh() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showReminders) { RemindersSheet(cases: store.active) }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                appeared = true
            }
        }
    }

    // MARK: - Background

    private var homeBackground: some View {
        ZStack {
            // Bright, vivid base gradient
            LinearGradient(
                colors: [Color(hex: 0xE0F7F4), Color(hex: 0xEBF4FF), Color(hex: 0xF5F0FF)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Top-right vivid teal circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0x00BFA5).opacity(0.30), Color.clear],
                        center: .center, startRadius: 0, endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: 160, y: -140)

            // Bottom-left vivid blue circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0x3B8BFF).opacity(0.18), Color.clear],
                        center: .center, startRadius: 0, endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: -140, y: 520)

            // Mid violet accent
            Circle()
                .fill(Color(hex: 0x8B5CF6).opacity(0.08))
                .frame(width: 220, height: 220)
                .offset(x: 120, y: 380)

            // Subtle stroke rings for depth
            Circle()
                .strokeBorder(Color(hex: 0x00BFA5).opacity(0.12), lineWidth: 1)
                .frame(width: 280)
                .offset(x: 140, y: -100)
            Circle()
                .strokeBorder(Color(hex: 0x3B8BFF).opacity(0.10), lineWidth: 1)
                .frame(width: 220)
                .offset(x: -100, y: 400)
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: 12) {
            // Avatar circle
            Button { router.tab = .settings } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x0B2B5C), Color(hex: 0x2E7DF6)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    Text(session.user?.initial ?? "U")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Account")

            VStack(alignment: .leading, spacing: 2) {
                Text(DateHelpers.greeting())
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(BFColor.text3)
                Text(session.user?.firstName ?? "there")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(BFColor.text1)
                    .lineLimit(1)
            }

            Spacer()

            // Bell / reminders
            Button { showReminders = true } label: {
                Circle()
                    .fill(Color.white)
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                    .overlay {
                        Image(systemName: store.active.contains { $0.nextDeadline != nil }
                              ? "bell.badge.fill" : "bell.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(
                                store.active.contains { $0.nextDeadline != nil } ? BFColor.red : BFColor.navy,
                                BFColor.navy
                            )
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reminders")
        }
    }

    // MARK: - Free Plan Banner

    private var freePlanBanner: some View {
        Button { router.requirePremium(.general) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FREE PLAN")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: 0xB45309))
                        .tracking(0.8)
                    Text("1 of 3 findings previewed")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x78350F))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: 0xB45309))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(hex: 0xFEF3C7))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color(hex: 0xFCD34D).opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Scan Hero Card

    private var scanCard: some View {
        Button { router.startCapture() } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("NEW CASE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .tracking(1.2)
                    Text("Scan a Medical Bill")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Photo, PDF or Camera")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                }
                Spacer()

                // Circle + button
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 56, height: 56)
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color(hex: 0x2E7DF6))
                }
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
            .background {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x2E7DF6), Color(hex: 0x0B2B5C)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    // Decorative circles inside card
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 140)
                        .offset(x: 40, y: -60)
                    Circle()
                        .fill(Color(hex: 0x00BFA5).opacity(0.15))
                        .frame(width: 90)
                        .offset(x: -120, y: 50)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .shadow(color: Color(hex: 0x0B2B5C).opacity(0.3), radius: 16, y: 8)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Scan a medical bill. Photo, PDF or camera.")
    }

    // MARK: - Quick Actions (4 icon tiles)

    private var quickActionsRow: some View {
        HStack(spacing: 12) {
            quickTile("Scan Bill",  "doc.viewfinder",       Color(hex: 0x2E7DF6), Color(hex: 0xEBF4FF))  { router.startCapture(.camera) }
            quickTile("Add EOB",    "doc.text.fill",        Color(hex: 0x00BFA5), Color(hex: 0xE0F7F4))  { router.startCapture(.photos) }
            quickTile("Import PDF", "arrow.down.doc.fill",  Color(hex: 0x8B5CF6), Color(hex: 0xF3EEFF))  { router.startCapture(.pdf) }
            quickTile("Help",       "questionmark.circle",  Color(hex: 0xF59E0B), Color(hex: 0xFFF8E1))  { router.tab = .learn }
        }
    }

    private func quickTile(_ title: String, _ symbol: String, _ tint: Color, _ fill: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    // Glow ring
                    Circle().fill(tint.opacity(0.12)).frame(width: 58, height: 58)
                    // Main icon circle
                    Circle()
                        .fill(fill)
                        .frame(width: 50, height: 50)
                        .shadow(color: tint.opacity(0.25), radius: 8, y: 3)
                    Image(systemName: symbol)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: 0x374151))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Savings Card

    private var savingsCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Saved so far")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BFColor.text3)
                    .tracking(0.5)
                CountUpMoney(money: store.totalSavings, font: BFFont.money(24), color: BFColor.green)
            }
            Spacer()
            Rectangle().fill(BFColor.line).frame(width: 1, height: 36)
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text("Possible savings")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BFColor.text3)
                    .tracking(0.5)
                CountUpMoney(money: store.potentialSavings, font: BFFont.money(24), color: BFColor.amber)
            }
            Spacer()
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    // MARK: - Cases Section

    @ViewBuilder
    private var casesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Cases")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(BFColor.text1)
                Spacer()
                if !store.cases.isEmpty {
                    Button("See All") { router.tab = .cases }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BFColor.blue)
                }
            }

            if store.cases.isEmpty {
                switch store.state {
                case .loading, .idle:
                    SkeletonList(rows: 2)
                case let .failed(error):
                    ErrorStateView(error: error) { Task { await store.load(force: true) } }
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                case .loaded:
                    emptyState
                }
            } else {
                ForEach(Array(store.cases.prefix(3).enumerated()), id: \.element.id) { i, item in
                    Button { router.push(.caseDetail(item.id)) } label: { CaseCard(item: item) }
                        .buttonStyle(.pressable)
                }
            }
        }
    }

    private var emptyState: some View {
        Button { router.startCapture() } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(BFColor.blueSoft)
                    .frame(width: 46, height: 46)
                    .overlay {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(BFColor.blue)
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text("No cases yet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BFColor.text1)
                    Text("Scan your first bill — we'll check it for errors.")
                        .font(.system(size: 13))
                        .foregroundStyle(BFColor.text3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(BFColor.text4)
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Learn Card

    private var learnCard: some View {
        Button { router.push(.rights(caseId: nil), on: .learn) } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(BFColor.violetSoft)
                    .frame(width: 46, height: 46)
                    .overlay {
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(BFColor.violet)
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Know your rights")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BFColor.text1)
                    Text("No Surprises Act, financial assistance and more")
                        .font(.system(size: 13))
                        .foregroundStyle(BFColor.text3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(BFColor.text4)
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reminders Sheet
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
                    EmptyStateView(title: "All caught up",
                                   message: "Deadlines you add to a case — like the 120-day dispute window — show up here.") {
                        Circle()
                            .fill(BFColor.blueSoft)
                            .frame(width: 80, height: 80)
                            .overlay {
                                Image(systemName: "bell.slash.fill")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundStyle(BFColor.blue)
                            }
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List(upcoming, id: \.0.id) { item in
                        Button {
                            dismiss()
                            router.push(.caseDetail(item.0.id))
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(BFColor.redSoft)
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        Image(systemName: "calendar.badge.clock")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(BFColor.red)
                                    }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.1.label)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(BFColor.text1)
                                    Text(item.0.displayName)
                                        .font(.system(size: 13))
                                        .foregroundStyle(BFColor.text3)
                                }
                                Spacer()
                                Text(DateHelpers.dueLabel(item.1.dueDate))
                                    .font(.system(size: 12, weight: .bold))
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
