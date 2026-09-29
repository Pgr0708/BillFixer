import SwiftUI

/// Screen 25 — all findings, strongest first; free tier sees one and an unlock card.
struct FindingsListView: View {
    let caseId: String
    @Environment(\.services) private var services
    @Environment(AppRouter.self) private var router
    @State private var model: FindingsModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let model {
                    switch model.state {
                    case .loaded:
                        let locked = model.sorted.filter(\.locked).count
                        if locked > 0 {
                            PlanBanner(text: "\(locked) more finding\(locked == 1 ? "" : "s") on this bill") { router.requirePremium(.findings) }
                        }
                        if model.sorted.isEmpty {
                            EmptyStateView(title: "Looks clean", message: "We didn’t find errors in the details you confirmed. You can still request an itemized bill to double-check.") {
                                SuccessBurst().scaleEffect(0.7).frame(height: 170)
                            }
                            .padding(.top, 30)
                        }
                        ForEach(Array(model.sorted.enumerated()), id: \.element.id) { i, f in
                            Button {
                                if f.locked { router.requirePremium(.findings) } else { router.push(.finding(caseId: caseId, finding: f)) }
                            } label: { FindingCard(finding: f) }
                            .buttonStyle(.pressable)
                            .staggeredAppear(i)
                        }
                    case let .failed(e): ErrorStateView(error: e) { Task { await model.load() } }
                    default: SkeletonList(rows: 4)
                    }
                }
            }
            .padding(BFSpacing.screen)
        }
        .refreshable { await model?.load() }
        .scenicBackground(.results)
        .navigationTitle("Findings")
        .task {
            if model == nil { model = FindingsModel(caseId: caseId, services: services) }
            await model?.load()
        }
    }
}
