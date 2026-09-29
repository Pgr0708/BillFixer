import SwiftUI
import Observation

@MainActor
@Observable
final class CaseDetailModel {
    let caseId: String
    private(set) var detail: CaseDetailResponse?
    private(set) var findings: FindingsResponse?
    private(set) var events: [CaseEvent] = []
    private(set) var state: LoadState<Void> = .idle
    private(set) var analysisRunning = false
    var isWorking = false

    private let services: AppServices

    init(caseId: String, services: AppServices) {
        self.caseId = caseId
        self.services = services
    }

    var info: CaseDetail? { detail?.detail }

    func load() async {
        if detail == nil {
            state = .loading
            if let cached = await DiskCache.shared.load(CaseDetailResponse.self, key: "case-\(caseId)") { detail = cached }
        }
        do {
            async let d = services.cases.detail(caseId)
            async let e = services.cases.events(caseId)
            let (fresh, ev) = try await (d, e)
            detail = fresh
            events = ev
            state = .loaded(())
            await DiskCache.shared.save(fresh, key: "case-\(caseId)")
            await ReminderScheduler.sync(caseId: caseId, provider: fresh.detail.providerName ?? fresh.detail.title, deadlines: fresh.deadlines)
            if fresh.detail.lastAnalyzedAt != nil {
                findings = try? await services.analysis.findings(caseId)
            } else {
                analysisRunning = (try? await services.analysis.status(caseId))?.isFinished == false
            }
        } catch {
            state = detail == nil ? .failed(error.asAPIError) : .loaded(())
            if detail != nil { Toast.error(error) }
        }
    }

    func updateBalance(_ money: Money) async -> Bool {
        await perform("Balance updated") { try await self.services.cases.update(self.caseId, PatchCaseRequest(currentBalance: money)) }
    }

    func setStatus(_ status: CaseStatus) async -> Bool {
        await perform(status == .closed ? "Case closed" : "Case reopened") {
            try await self.services.cases.update(self.caseId, PatchCaseRequest(status: status.rawValue))
        }
    }

    func rename(_ title: String) async -> Bool {
        await perform("Renamed") { try await self.services.cases.update(self.caseId, PatchCaseRequest(title: title)) }
    }

    func resolve(resolution: String, finalBalance: Money, notes: String?) async -> Money? {
        isWorking = true
        defer { isWorking = false }
        do {
            let savings = try await services.cases.resolve(caseId, ResolveCaseRequest(resolution: resolution, finalBalance: finalBalance, notes: notes))
            await load()
            return savings ?? .zero
        } catch {
            Toast.error(error)
            return nil
        }
    }

    func addDeadline(type: String, label: String, due: Date) async -> Bool {
        await perform("Deadline added", "We’ll remind you before it’s due.") {
            try await self.services.cases.addDeadline(self.caseId, CreateDeadlineRequest(type: type, label: label, dueDate: DateHelpers.dayString(due), notifyDays: [7, 1, 0]))
        }
    }

    func toggleDeadline(_ d: Deadline) async {
        _ = await perform(d.isCompleted ? "Marked not done" : "Marked done") {
            try await self.services.cases.updateDeadline(self.caseId, d.id, PatchDeadlineRequest(isCompleted: !d.isCompleted))
        }
    }

    func deleteDeadline(_ d: Deadline) async {
        _ = await perform("Deadline removed") { try await self.services.cases.deleteDeadline(self.caseId, d.id) }
    }

    func addNote(_ text: String) async -> Bool {
        await perform("Note added") { try await self.services.cases.addNote(self.caseId, text) }
    }

    private func perform(_ success: String, _ subtitle: String? = nil, _ op: @escaping () async throws -> Void) async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            try await op()
            Toast.success(success, subtitle)
            await load()
            return true
        } catch {
            Toast.error(error)
            return false
        }
    }
}
