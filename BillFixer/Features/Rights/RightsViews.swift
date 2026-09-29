import SwiftUI

/// Screen 19.
struct RightsListView: View {
    let caseId: String?
    @Environment(\.services) private var services
    @Environment(AppRouter.self) private var router
    @State private var rights: LoadState<[RightInfo]> = .idle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your Rights May Apply").font(BFFont.serifDisplay(30)).foregroundStyle(BFColor.text1)
                Text("Federal protections for patients. Tap one to see when it applies and what to do.")
                    .font(BFFont.subheadline).foregroundStyle(BFColor.text2)
                switch rights {
                case let .loaded(list):
                    ForEach(Array(list.enumerated()), id: \.element.id) { i, r in
                        Button { router.push(.right(r, caseId: caseId)) } label: {
                            HStack(alignment: .top, spacing: 14) {
                                IconTile(symbol: symbol(r.key), tint: rightTint(i), fill: rightTint(i).opacity(0.14), size: 46)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(r.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(BFColor.text1)
                                    Text(r.summary).font(.system(size: 14)).foregroundStyle(BFColor.text2).lineLimit(3).multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(BFColor.text4)
                            }
                            .cardStyle(padding: 16, radius: 20)
                        }
                        .buttonStyle(.pressable)
                        .staggeredAppear(i)
                    }
                case let .failed(e): ErrorStateView(error: e) { Task { await load() } }
                default: SkeletonList(rows: 4)
                }
                Text("General information, not legal advice.").font(.system(size: 11)).foregroundStyle(BFColor.text3)
            }
            .padding(BFSpacing.screen)
        }
        .scenicBackground(.rights)
        .navigationBarTitleDisplayMode(.inline)
        .task { if rights.value == nil { await load() } }
    }

    private func load() async {
        do { rights = .loaded(try await services.reference.rights()) } catch { rights = .failed(error.asAPIError) }
    }
}

func symbol(_ key: String) -> String {
    switch key {
    case "no_surprises_act": "shield.lefthalf.filled"
    case "good_faith_estimate": "doc.text.magnifyingglass"
    case "financial_assistance": "heart.text.square.fill"
    case "itemized_bill": "list.bullet.rectangle.fill"
    case "eob_match": "arrow.left.arrow.right.square.fill"
    case "price_transparency": "building.2.fill"
    default: "building.columns.fill"
    }
}

private func rightTint(_ i: Int) -> Color { [BFColor.violet, BFColor.teal, BFColor.blue, BFColor.amber, BFColor.green, BFColor.red][i % 6] }

/// Screen 28.
struct RightDetailView: View {
    let right: RightInfo
    let caseId: String?
    @Environment(AppRouter.self) private var router
    @Environment(AppSession.self) private var session
    @State private var link: WebLink?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                IconTile(symbol: symbol(right.key), tint: .white, fill: BFColor.violet, size: 64, radius: 20).staggeredAppear(0)
                Text(right.title).font(BFFont.serifDisplay(30)).foregroundStyle(BFColor.text1).staggeredAppear(1)
                Text(right.summary).font(BFFont.body).foregroundStyle(BFColor.text2).lineSpacing(3).staggeredAppear(2)
                list("When it may apply", right.appliesWhen, "checkmark.circle.fill", BFColor.teal).staggeredAppear(3)
                list("What you can do", right.whatToDo, "arrow.right.circle.fill", BFColor.blue).staggeredAppear(4)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Source").overlineStyle()
                    Text(right.citation).font(BFFont.evidence).foregroundStyle(BFColor.text1)
                    if let l = WebLink.external(right.sourceUrl) {
                        Button { link = l } label: { Label("Read the official source", systemImage: "safari") }.font(BFFont.label(14))
                    }
                }
                .cardStyle(padding: 14, radius: 16)

                if right.key == "financial_assistance" {
                    BFButton(title: "Check If You May Qualify", icon: "heart.text.square", kind: .teal) { router.push(.assistance(caseId: caseId)) }
                }
                if let caseId, let type = right.letterType {
                    BFButton(title: "Generate \(type.title) Letter", icon: "envelope.fill", kind: .navy) {
                        guard session.isPremium else { return router.requirePremium(.letters) }
                        router.push(.newLetter(caseId: caseId, findingId: nil, type: type))
                    }
                }
                if right.key == "no_surprises_act" {
                    Link(destination: URL(string: "tel:18009853059")!) {
                        Label("No Surprises Help Desk: 1-800-985-3059", systemImage: "phone.fill").font(BFFont.label(14))
                    }
                }
            }
            .padding(BFSpacing.screen)
        }
        .scenicBackground(.rights)
        .navigationBarTitleDisplayMode(.inline)
        .webSheet($link)
    }

    private func list(_ title: String, _ items: [String], _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(BFFont.title3()).foregroundStyle(BFColor.text1)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: icon).foregroundStyle(color)
                    Text(item).font(.system(size: 15)).foregroundStyle(BFColor.text2)
                }
            }
        }
        .cardStyle(padding: 16, radius: 18)
    }
}
