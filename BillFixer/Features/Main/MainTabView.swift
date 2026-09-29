import SwiftUI

struct MainTabView: View {
    @Environment(AppSession.self) private var session
    @State private var router = AppRouter()
    @State private var store = CasesStore()
    @State private var network = NetworkMonitor.shared

    var body: some View {
        Group {
            switch router.tab {
            case .home:     stack(.home)     { HomeView() }
            case .cases:    stack(.cases)    { CasesListView() }
            case .learn:    stack(.learn)    { LearnView() }
            case .settings: stack(.settings) { SettingsView() }
            case .scan:     EmptyView()
            }
        }
        .transition(.opacity)
        // Extra bottom inset — floating pill tab bar is ~90pt tall
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BFTabBar(
                selection: Binding(get: { router.tab }, set: { router.tab = $0 }),
                onScan: { router.startCapture() }
            )
        }
        .overlay(alignment: .top) {
            if !network.isOnline { OfflineBanner().padding(.top, 4) }
        }
        .animation(BFMotion.standard, value: network.isOnline)
        .ignoresSafeArea(.keyboard)
        .preferredColorScheme(.light)            // ← Force light mode globally
        .environment(router)
        .environment(store)
        .fullScreenCover(isPresented: $router.isCapturePresented) {
            CaptureFlowView(initialSource: router.captureSource) { caseId in
                router.isCapturePresented = false
                Task { await store.load(force: true) }
                if let caseId { router.showResults(caseId: caseId) }
            }
            .environment(router)
            .environment(session)
        }
        .sheet(item: $router.paywall) { reason in
            PaywallScreenView(reason: reason) {
                router.paywall = nil
                router.showAllSet = true
            }
            .environment(session)
        }
        .fullScreenCover(isPresented: $router.showAllSet) {
            AllSetView { router.showAllSet = false; router.startCapture() }
                onClose: { router.showAllSet = false }
        }
        .task { await store.load() }
        .onChange(of: router.tab) { _, _ in Haptics.selection() }
    }

    private func stack<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack(path: router.path(tab)) {
            content().navigationDestination(for: Route.self) { RouteView(route: $0) }
        }
    }
}

// MARK: - Route → View mapper
struct RouteView: View {
    let route: Route

    var body: some View {
        switch route {
        case let .caseDetail(id):                CaseDetailView(caseId: id)
        case let .results(id):                   ResultsOverviewView(caseId: id)
        case let .findings(id):                  FindingsListView(caseId: id)
        case let .finding(caseId, finding):      FindingDetailView(caseId: caseId, finding: finding)
        case let .letter(caseId, letterId):      LetterView(caseId: caseId, source: .existing(letterId))
        case let .newLetter(caseId, fid, type):  LetterView(caseId: caseId, source: .generate(findingId: fid, type: type))
        case let .script(caseId, scriptId):      PhoneScriptView(source: .existing(caseId: caseId, scriptId: scriptId))
        case let .newScript(caseId, fid, t, i):  PhoneScriptView(source: .generate(caseId: caseId, findingId: fid, callTarget: t, issueType: i))
        case let .libraryScript(script):         PhoneScriptView(source: .library(script))
        case let .rights(caseId):                RightsListView(caseId: caseId)
        case let .right(info, caseId):           RightDetailView(right: info, caseId: caseId)
        case let .assistance(caseId):            FinancialAssistanceView(caseId: caseId)
        case let .timeline(id):                  CaseTimelineView(caseId: id)
        case .account:                           AccountView()
        }
    }
}
