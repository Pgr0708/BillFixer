import SwiftUI
import Observation

/// Shared case list for Home and the Cases tab (one fetch, both screens stay in sync).
@MainActor
@Observable
final class CasesStore {
    private(set) var cases: [CaseSummary] = []
    private(set) var state: LoadState<Void> = .idle
    private(set) var isStale = false
    private let service: CaseServicing
    private var loadTask: Task<Void, Never>?

    convenience init() { self.init(service: CaseService()) }
    init(service: CaseServicing) { self.service = service }

    var active: [CaseSummary] { cases.filter { [.draft, .active, .awaitingResponse].contains($0.status) } }
    var resolved: [CaseSummary] { cases.filter { $0.status == .resolved } }
    var closed: [CaseSummary] { cases.filter { $0.status == .closed } }
    var totalSavings: Money { cases.compactMap(\.verifiedSavings).reduce(.zero, +) }
    var potentialSavings: Money { active.compactMap(\.potentialSavings).reduce(.zero, +) }
    var hasLoaded: Bool { if case .loaded = state { true } else { !cases.isEmpty } }

    func load(force: Bool = false) async {
        if let loadTask, !force { return await loadTask.value }
        if cases.isEmpty, let cached = await service.cachedList() {
            cases = cached
            isStale = true
        }
        if cases.isEmpty { state = .loading }
        let task = Task {
            do {
                let fresh = try await service.list()
                withAnimation(BFMotion.gentle) { cases = fresh }
                isStale = false
                state = .loaded(())
            } catch {
                let e = error.asAPIError
                if e == .cancelled { return }
                state = cases.isEmpty ? .failed(e) : .loaded(())
                isStale = !cases.isEmpty
            }
        }
        loadTask = task
        await task.value
        loadTask = nil
    }

    func delete(_ id: String) async {
        let backup = cases
        withAnimation(BFMotion.standard) { cases.removeAll { $0.id == id } }
        do {
            try await service.delete(id)
            await ReminderScheduler.cancel(caseId: id)
            await DiskCache.shared.remove("case-\(id)")
            Toast.success("Case deleted", "All documents and letters were removed.")
        } catch {
            withAnimation { cases = backup }
            Toast.error(error)
        }
    }

    func reset() { cases = []; state = .idle }
}
