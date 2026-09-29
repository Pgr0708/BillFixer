import SwiftUI

/// Screen 25 — all findings, strongest first; free tier sees one and an unlock card.
struct FindingsListView: View {
    let caseId: String
    @Environment(\.services) private var services
    @Environment(AppRouter.self) private var router
    @State private var model: FindingsModel?
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Background
            ScenicBackground(scene: .finding)
            circleDecorations

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let model {
                        switch model.state {
                        case .loaded:
                            let locked = model.sorted.filter(\.locked).count

                            // Circular summary header
                            summaryHeader(model: model)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : -12)

                            // Free plan banner
                            if locked > 0 {
                                lockedBanner(locked: locked)
                                    .opacity(appeared ? 1 : 0)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.06), value: appeared)
                            }

                            if model.sorted.isEmpty {
                                emptyState
                                    .opacity(appeared ? 1 : 0)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: appeared)
                            }

                            ForEach(Array(model.sorted.enumerated()), id: \.element.id) { i, f in
                                Button {
                                    if f.locked { router.requirePremium(.findings) }
                                    else { router.push(.finding(caseId: caseId, finding: f)) }
                                } label: { FindingCard(finding: f) }
                                .buttonStyle(.pressable)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 20)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8)
                                    .delay(0.12 + Double(i) * 0.06), value: appeared)
                            }

                        case let .failed(e):
                            ErrorStateView(error: e) { Task { await model.load() } }
                        default:
                            SkeletonList(rows: 4)
                        }
                    }
                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .refreshable { await model?.load() }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Findings")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) { appeared = true }
        }
        .task {
            if model == nil { model = FindingsModel(caseId: caseId, services: services) }
            await model?.load()
        }
    }

    // MARK: - Summary header row

    private func summaryHeader(model: FindingsModel) -> some View {
        let strong  = model.sorted.filter { $0.severity == .strong  && !$0.locked }.count
        let likely  = model.sorted.filter { $0.severity == .likely  && !$0.locked }.count
        let possible = model.sorted.filter { $0.severity == .possible && !$0.locked }.count

        return HStack(spacing: 10) {
            if strong  > 0 { severityPill("\(strong) Strong",   color: BFColor.red) }
            if likely  > 0 { severityPill("\(likely) Likely",   color: BFColor.amber) }
            if possible > 0 { severityPill("\(possible) Possible", color: BFColor.blue) }
        }
    }

    private func severityPill(_ text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Locked banner

    private func lockedBanner(locked: Int) -> some View {
        Button { router.requirePremium(.findings) } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color(hex: 0xFFC554).opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(light: 0xB45309, dark: 0xFFCB5C))
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(locked) more finding\(locked == 1 ? "" : "s") on this bill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(light: 0x78350F, dark: 0xFFE2A6))
                    Text("Upgrade to see every issue we found")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(light: 0x92400E, dark: 0xFFD27A))
                }
                Spacer()
                Circle()
                    .fill(Color(hex: 0xFEF3C7))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(light: 0xB45309, dark: 0xFFCB5C))
                    }
            }
            .padding(14)
            .background(Color(hex: 0xFEF3C7))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(hex: 0xFCD34D).opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(BFColor.greenSoft).frame(width: 110, height: 110)
                Circle().fill(BFColor.tealSoft).frame(width: 80, height: 80)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(BFColor.green)
            }
            VStack(spacing: 8) {
                Text("Looks clean")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(BFColor.text1)
                Text("We didn't find errors in the details you confirmed.\nYou can still request an itemized bill to double-check.")
                    .font(.system(size: 15))
                    .foregroundStyle(BFColor.text3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Background circles

    private var circleDecorations: some View {
        ZStack {
            Circle().fill(BFColor.amberSoft).frame(width: 260).offset(x: 150, y: -130)
            Circle().fill(BFColor.tealSoft).frame(width: 200).offset(x: -120, y: 450)
        }
    }
}
