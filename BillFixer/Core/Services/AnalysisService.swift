import Foundation

protocol AnalysisServicing {
    func start(_ caseId: String, context: AnalysisContext) async throws -> JobCreated
    func status(_ caseId: String) async throws -> JobStatus
    func findings(_ caseId: String) async throws -> FindingsResponse
    func updateFinding(_ caseId: String, _ findingId: String, status: FindingStatus) async throws
    func job(_ jobId: String) async throws -> JobStatus
}

struct AnalysisService: AnalysisServicing {
    var api: APIClient = .shared

    func start(_ caseId: String, context: AnalysisContext) async throws -> JobCreated {
        try await api.send(.post("cases/\(caseId)/analyze", AnalyzeRequest(context: context), idempotent: true))
    }
    func status(_ caseId: String) async throws -> JobStatus { try await api.send(.get("cases/\(caseId)/analysis/status")) }
    func findings(_ caseId: String) async throws -> FindingsResponse { try await api.send(.get("cases/\(caseId)/findings")) }
    func updateFinding(_ caseId: String, _ findingId: String, status: FindingStatus) async throws {
        try await api.send(.patch("cases/\(caseId)/findings/\(findingId)", PatchFindingRequest(status: status.rawValue)))
    }
    func job(_ jobId: String) async throws -> JobStatus { try await api.send(.get("jobs/\(jobId)")) }
}

/// Polls a background job until it finishes. Starts fast, backs off to 2s, gives up after `timeout`.
enum JobPoller {
    static func wait(timeout: Duration = .seconds(120),
                     fetch: () async throws -> JobStatus,
                     onUpdate: (JobStatus) -> Void = { _ in }) async throws -> JobStatus {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        var delay = Duration.milliseconds(700)
        var transientFailures = 0
        while clock.now < deadline {
            try Task.checkCancellation()
            do {
                let status = try await fetch()
                transientFailures = 0
                onUpdate(status)
                if status.isFinished { return status }
            } catch let error as APIError where error.isRetryable && transientFailures < 5 {
                transientFailures += 1   // brief network blips shouldn't fail a 30s analysis
            }
            try await Task.sleep(for: delay)
            delay = min(delay * 1.4, .seconds(2))
        }
        throw APIError.timeout
    }
}
