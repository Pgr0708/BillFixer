import Foundation

protocol CaseServicing {
    func list() async throws -> [CaseSummary]
    func cachedList() async -> [CaseSummary]?
    func create(title: String, billDate: String?, serviceType: String?) async throws -> String
    func detail(_ caseId: String) async throws -> CaseDetailResponse
    func update(_ caseId: String, _ patch: PatchCaseRequest) async throws
    func delete(_ caseId: String) async throws
    func addDocument(_ caseId: String, _ doc: CreateDocumentRequest) async throws -> String?
    func submitBill(_ caseId: String, _ bill: BillSubmission) async throws
    func submitEOB(_ caseId: String, _ eob: EOBSubmission) async throws
    func submitGFE(_ caseId: String, _ gfe: GFESubmission) async throws
    func deadlines(_ caseId: String) async throws -> [Deadline]
    func addDeadline(_ caseId: String, _ body: CreateDeadlineRequest) async throws
    func updateDeadline(_ caseId: String, _ deadlineId: String, _ body: PatchDeadlineRequest) async throws
    func deleteDeadline(_ caseId: String, _ deadlineId: String) async throws
    func events(_ caseId: String) async throws -> [CaseEvent]
    func addNote(_ caseId: String, _ label: String) async throws
    func resolve(_ caseId: String, _ body: ResolveCaseRequest) async throws -> Money?
}

struct CaseService: CaseServicing {
    var api: APIClient = .shared
    var cache: DiskCache = .shared

    func list() async throws -> [CaseSummary] {
        let r: CasesResponse = try await api.send(.get("cases"))
        await cache.save(r, key: "cases")
        return r.cases
    }

    func cachedList() async -> [CaseSummary]? { await cache.load(CasesResponse.self, key: "cases")?.cases }

    func create(title: String, billDate: String?, serviceType: String?) async throws -> String {
        let r: CaseCreated = try await api.send(.post("cases", CreateCaseRequest(title: title, billDate: billDate, serviceType: serviceType), idempotent: true))
        return r.caseId
    }

    func detail(_ caseId: String) async throws -> CaseDetailResponse { try await api.send(.get("cases/\(caseId)")) }
    func update(_ caseId: String, _ patch: PatchCaseRequest) async throws { try await api.send(.patch("cases/\(caseId)", patch)) }
    func delete(_ caseId: String) async throws { try await api.send(.delete("cases/\(caseId)")) }

    func addDocument(_ caseId: String, _ doc: CreateDocumentRequest) async throws -> String? {
        let r: IDResponse = try await api.send(.post("cases/\(caseId)/documents", doc, idempotent: true))
        return r.documentId
    }

    func submitBill(_ caseId: String, _ bill: BillSubmission) async throws { try await api.send(.post("cases/\(caseId)/bill", bill, idempotent: true)) }
    func submitEOB(_ caseId: String, _ eob: EOBSubmission) async throws { try await api.send(.post("cases/\(caseId)/eob", eob, idempotent: true)) }
    func submitGFE(_ caseId: String, _ gfe: GFESubmission) async throws { try await api.send(.post("cases/\(caseId)/gfe", gfe, idempotent: true)) }

    func deadlines(_ caseId: String) async throws -> [Deadline] {
        let r: DeadlinesResponse = try await api.send(.get("cases/\(caseId)/deadlines"))
        return r.deadlines
    }
    func addDeadline(_ caseId: String, _ body: CreateDeadlineRequest) async throws { try await api.send(.post("cases/\(caseId)/deadlines", body)) }
    func updateDeadline(_ caseId: String, _ deadlineId: String, _ body: PatchDeadlineRequest) async throws {
        try await api.send(.patch("cases/\(caseId)/deadlines/\(deadlineId)", body))
    }
    func deleteDeadline(_ caseId: String, _ deadlineId: String) async throws { try await api.send(.delete("cases/\(caseId)/deadlines/\(deadlineId)")) }

    func events(_ caseId: String) async throws -> [CaseEvent] {
        let r: EventsResponse = try await api.send(.get("cases/\(caseId)/events"))
        return r.events
    }
    func addNote(_ caseId: String, _ label: String) async throws { try await api.send(.post("cases/\(caseId)/events", CreateNoteRequest(label: label))) }

    func resolve(_ caseId: String, _ body: ResolveCaseRequest) async throws -> Money? {
        let r: ResolveResponse = try await api.send(.post("cases/\(caseId)/resolve", body))
        return r.verifiedSavings
    }
}
