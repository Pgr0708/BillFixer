import Foundation

enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(APIError)

    var value: Value? { if case let .loaded(v) = self { v } else { nil } }
    var error: APIError? { if case let .failed(e) = self { e } else { nil } }
    var isLoading: Bool { if case .loading = self { true } else { false } }
}
