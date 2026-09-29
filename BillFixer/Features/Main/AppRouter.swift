import SwiftUI
import Observation

/// Every push destination in the app. Values, not views — so deep links and state restoration stay simple.
enum Route: Hashable {
    case caseDetail(String)
    case results(String)
    case findings(String)
    case finding(caseId: String, finding: Finding)
    case letter(caseId: String, letterId: String)
    case newLetter(caseId: String, findingId: String?, type: LetterType)
    case script(caseId: String, scriptId: String)
    case newScript(caseId: String, findingId: String?, callTarget: String, issueType: String)
    case libraryScript(LibraryScript)
    case rights(caseId: String?)
    case right(RightInfo, caseId: String?)
    case assistance(caseId: String?)
    case timeline(String)
    case account
}

enum PaywallReason: String, Identifiable {
    case findings, letters, scripts, cases, general
    var id: String { rawValue }
    var headline: String {
        switch self {
        case .findings: "See every finding"
        case .letters: "Send a ready-made letter"
        case .scripts: "Call with confidence"
        case .cases: "Track all your bills"
        case .general: "Go Premium"
        }
    }
}

@MainActor
@Observable
final class AppRouter {
    var tab: AppTab = .home
    var paths: [AppTab: NavigationPath] = [.home: NavigationPath(), .cases: NavigationPath(), .learn: NavigationPath(), .settings: NavigationPath()]
    var isCapturePresented = false
    var captureSource: CaptureSource?
    var paywall: PaywallReason?
    var showAllSet = false

    func path(_ tab: AppTab) -> Binding<NavigationPath> {
        Binding(get: { self.paths[tab] ?? NavigationPath() }, set: { self.paths[tab] = $0 })
    }

    func push(_ route: Route, on tab: AppTab? = nil) {
        Haptics.tapLight()
        let t = tab ?? self.tab
        if t != self.tab { self.tab = t }
        paths[t, default: NavigationPath()].append(route)
    }

    func popToRoot(_ tab: AppTab? = nil) { paths[tab ?? self.tab] = NavigationPath() }

    /// After a new analysis: land on the Cases tab showing that case's results.
    func showResults(caseId: String) {
        tab = .cases
        paths[.cases] = NavigationPath([Route.caseDetail(caseId), Route.results(caseId)])
    }

    func startCapture(_ source: CaptureSource? = nil) {
        Haptics.tap()
        captureSource = source
        isCapturePresented = true
    }

    func requirePremium(_ reason: PaywallReason) {
        Haptics.warning()
        paywall = reason
    }
}
