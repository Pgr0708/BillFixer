import SwiftUI
import Observation

@MainActor
@Observable
final class FindingsModel {
    let caseId: String
    private(set) var state: LoadState<FindingsResponse> = .idle
    private let services: AppServices

    init(caseId: String, services: AppServices) {
        self.caseId = caseId
        self.services = services
    }

    var response: FindingsResponse? { state.value }
    var sorted: [Finding] {
        (response?.findings ?? []).sorted { ($0.locked ? 1 : 0, $0.severity.rank) < ($1.locked ? 1 : 0, $1.severity.rank) }
    }

    func load() async {
        if state.value == nil { state = .loading }
        do { state = .loaded(try await services.analysis.findings(caseId)) } catch {
            if state.value == nil { state = .failed(error.asAPIError) } else { Toast.error(error) }
        }
    }

    func update(_ finding: Finding, to status: FindingStatus) async -> Bool {
        do {
            try await services.analysis.updateFinding(caseId, finding.id, status: status)
            Toast.success(status == .wrong ? "Thanks — marked as incorrect" : "Finding updated")
            await load()
            return true
        } catch {
            Toast.error(error)
            return false
        }
    }
}
