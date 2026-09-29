import Foundation

protocol SubscriptionServicing {
    func status() async throws -> SubscriptionStatus
    /// Asks the server to re-read the entitlement from RevenueCat right after a purchase/restore.
    func sync() async throws -> SubscriptionStatus
}

struct SubscriptionService: SubscriptionServicing {
    var api: APIClient = .shared
    func status() async throws -> SubscriptionStatus { try await api.send(.get("subscription/status")) }
    func sync() async throws -> SubscriptionStatus { try await api.send(.post("subscription/validate", EmptyBody())) }
}
