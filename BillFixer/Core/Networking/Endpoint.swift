import Foundation

nonisolated enum HTTPMethod: String, Sendable { case get = "GET", post = "POST", patch = "PATCH", delete = "DELETE" }

nonisolated struct Endpoint: Sendable {
    var method: HTTPMethod
    var path: String
    var query: [URLQueryItem] = []
    var body: Data? = nil
    var requiresAuth = true
    var idempotencyKey: String? = nil
    var timeout: TimeInterval = 30

    static func get(_ path: String, query: [URLQueryItem] = [], auth: Bool = true) -> Endpoint {
        Endpoint(method: .get, path: path, query: query, requiresAuth: auth)
    }

    static func delete(_ path: String, auth: Bool = true) -> Endpoint {
        Endpoint(method: .delete, path: path, requiresAuth: auth)
    }

    static func delete<B: Encodable>(_ path: String, _ body: B, auth: Bool = true) throws -> Endpoint {
        Endpoint(method: .delete, path: path, body: try JSONCoding.encoder().encode(body), requiresAuth: auth)
    }

    /// `idempotent: true` attaches an Idempotency-Key so the POST can be safely retried.
    static func post<B: Encodable>(_ path: String, _ body: B, auth: Bool = true, idempotent: Bool = false) throws -> Endpoint {
        Endpoint(method: .post, path: path, body: try JSONCoding.encoder().encode(body), requiresAuth: auth,
                 idempotencyKey: idempotent ? UUID().uuidString : nil)
    }

    static func patch<B: Encodable>(_ path: String, _ body: B) throws -> Endpoint {
        Endpoint(method: .patch, path: path, body: try JSONCoding.encoder().encode(body))
    }

    /// Safe to retry automatically: reads, deletes, patches, and keyed POSTs.
    var isRetrySafe: Bool { method != .post || idempotencyKey != nil }
}
