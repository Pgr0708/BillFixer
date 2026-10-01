import Foundation

protocol ContentServicing {
    func requestLetter(_ caseId: String, _ body: CreateLetterRequest) async throws -> JobCreated
    func letter(_ caseId: String, _ letterId: String) async throws -> Letter
    func updateLetter(_ caseId: String, _ letterId: String, content: String) async throws -> Letter
    func markSent(_ caseId: String, _ letterId: String) async throws -> Date?
    func requestScript(_ caseId: String, _ body: CreateScriptRequest) async throws -> JobCreated
    func script(_ caseId: String, _ scriptId: String) async throws -> PhoneScript
    func library() async throws -> [LibraryScript]
    func job(_ jobId: String) async throws -> JobStatus
}

struct ContentService: ContentServicing {
    var api: APIClient = .shared
    var cache: DiskCache = .shared

    func requestLetter(_ caseId: String, _ body: CreateLetterRequest) async throws -> JobCreated {
        try await api.send(.post("cases/\(caseId)/letters", body, idempotent: true))
    }
    // Letters and scripts stay readable offline (e.g. on the phone with a billing office).
    func letter(_ caseId: String, _ letterId: String) async throws -> Letter {
        try await cache.fetch("letter-\(letterId)") { try await api.send(.get("cases/\(caseId)/letters/\(letterId)")) }
    }
    func updateLetter(_ caseId: String, _ letterId: String, content: String) async throws -> Letter {
        let letter: Letter = try await api.send(.patch("cases/\(caseId)/letters/\(letterId)", PatchLetterRequest(content: content)))
        await cache.save(letter, key: "letter-\(letterId)")
        return letter
    }
    func markSent(_ caseId: String, _ letterId: String) async throws -> Date? {
        let body = MarkSentRequest(sentAt: Date().formatted(.iso8601))
        let r: MarkSentResponse = try await api.send(.post("cases/\(caseId)/letters/\(letterId)/mark-sent", body))
        return r.sentAt
    }
    func requestScript(_ caseId: String, _ body: CreateScriptRequest) async throws -> JobCreated {
        try await api.send(.post("cases/\(caseId)/scripts", body, idempotent: true))
    }
    func script(_ caseId: String, _ scriptId: String) async throws -> PhoneScript {
        try await cache.fetch("script-\(scriptId)") { try await api.send(.get("cases/\(caseId)/scripts/\(scriptId)")) }
    }
    func library() async throws -> [LibraryScript] {
        let r: ScriptLibraryResponse = try await cache.fetch("script-library", maxAge: 86_400) { try await api.send(.get("scripts/library")) }
        return r.scripts
    }
    func job(_ jobId: String) async throws -> JobStatus { try await api.send(.get("jobs/\(jobId)")) }
}
