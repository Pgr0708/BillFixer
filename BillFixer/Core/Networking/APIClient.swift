//
//  APIClient.swift
//  Single entry point for every backend call (AGENTS.md rule 2). Runs on its own actor, off the main thread.
//

import Foundation

extension Notification.Name {
    static let sessionExpired = Notification.Name("BillFixer.sessionExpired")
}

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let baseURL: URL
    private let tokens: TokenStore
    private var refreshTask: Task<String, Error>?
    private let maxRetries = 2

    init(baseURL: URL = AppConfig.apiBaseURL, tokens: TokenStore = .shared) {
        self.baseURL = baseURL
        self.tokens = tokens
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = false          // fail fast; the UI shows an offline state instead
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 90
        config.httpMaximumConnectionsPerHost = 6
        config.requestCachePolicy = .useProtocolCachePolicy
        config.urlCache = URLCache(memoryCapacity: 8 * 1024 * 1024, diskCapacity: 40 * 1024 * 1024)
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "X-Client": "ios/\(AppConfig.appVersion)",
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: Public

    func send<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type = T.self) async throws -> T {
        let data = try await perform(endpoint)
        do {
            return try JSONCoding.decoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    func send(_ endpoint: Endpoint) async throws {
        _ = try await perform(endpoint)
    }

    /// Sign-out: drop HTTP-cached responses too.
    func clearHTTPCache() { session.configuration.urlCache?.removeAllCachedResponses() }

    // MARK: Core

    private func makeRequest(_ ep: Endpoint) async throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(ep.path), resolvingAgainstBaseURL: false)!
        if !ep.query.isEmpty { components.queryItems = ep.query }
        var request = URLRequest(url: components.url!, timeoutInterval: ep.timeout)
        request.httpMethod = ep.method.rawValue
        if let body = ep.body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let key = ep.idempotencyKey { request.setValue(key, forHTTPHeaderField: "Idempotency-Key") }
        if ep.requiresAuth {
            guard let token = await tokens.accessToken() else {
                throw APIError.unauthorized(code: "AUTH_REQUIRED", message: "Please sign in to continue.")
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func perform(_ ep: Endpoint, attempt: Int = 0, refreshed: Bool = false) async throws -> Data {
        try Task.checkCancellation()
        let request = try await makeRequest(ep)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            let apiError = APIError.from(error)
            if apiError != .cancelled, apiError != .offline, ep.isRetrySafe, attempt < maxRetries {
                try await backoff(attempt, retryAfter: nil)
                return try await perform(ep, attempt: attempt + 1, refreshed: refreshed)
            }
            throw apiError
        } catch is CancellationError {
            throw APIError.cancelled
        }

        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        if (200..<300).contains(status) { return data }

        let error = Self.parseError(data: data, status: status, headers: http)

        if status == 401, ep.requiresAuth {
            if !refreshed, case let .unauthorized(code, _) = error, code == "TOKEN_EXPIRED" || code == "TOKEN_INVALID" {
                _ = try await refreshAccessToken()
                return try await perform(ep, attempt: attempt, refreshed: true)
            }
            await endSession()
            throw error
        }

        if [408, 429, 502, 503, 504].contains(status), ep.isRetrySafe, attempt < maxRetries {
            var retryAfter: Int? = nil
            if case let .rateLimited(seconds) = error { retryAfter = seconds }
            if retryAfter == nil || retryAfter! <= 10 {
                try await backoff(attempt, retryAfter: retryAfter)
                return try await perform(ep, attempt: attempt + 1, refreshed: refreshed)
            }
        }
        throw error
    }

    private func backoff(_ attempt: Int, retryAfter: Int?) async throws {
        let base = retryAfter.map { Double($0) } ?? (0.5 * pow(2, Double(attempt)))
        let jitter = Double.random(in: 0...0.3)
        try await Task.sleep(for: .seconds(min(base + jitter, 10)))
    }

    // MARK: Session

    /// Single-flight refresh: concurrent 401s share one refresh request.
    func refreshAccessToken() async throws -> String {
        if let task = refreshTask { return try await task.value }
        let task = Task { try await self.performRefresh() }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func performRefresh() async throws -> String {
        guard let refresh = await tokens.refreshToken() else {
            await endSession()
            throw APIError.unauthorized(code: "AUTH_REQUIRED", message: "Please sign in to continue.")
        }
        let ep = try Endpoint.post("auth/refresh", RefreshRequest(refreshToken: refresh), auth: false)
        do {
            let pair: TokenPair = try await send(ep)
            await tokens.save(access: pair.accessToken, refresh: pair.refreshToken)
            return pair.accessToken
        } catch let error as APIError {
            if case .unauthorized = error { await endSession() }
            throw error
        }
    }

    private func endSession() async {
        await tokens.clear()
        await MainActor.run { NotificationCenter.default.post(name: .sessionExpired, object: nil) }
    }

    // MARK: Errors

    private static func parseError(data: Data, status: Int, headers: HTTPURLResponse?) -> APIError {
        let envelope = try? JSONCoding.decoder().decode(ServerErrorEnvelope.self, from: data)
        let code = envelope?.error.code ?? "HTTP_\(status)"
        let message = envelope?.error.message ?? HTTPURLResponse.localizedString(forStatusCode: status).capitalized
        switch status {
        case 401: return .unauthorized(code: code, message: message)
        case 402: return .premiumRequired(feature: envelope?.error.details?.feature ?? "this feature")
        case 404: return .notFound(message: message)
        case 409: return .conflict(code: code, message: message)
        case 400, 413, 422: return .validation(message: message, fields: envelope?.error.details?.fields ?? [:])
        case 429:
            let header = headers?.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            return .rateLimited(retryAfter: envelope?.error.details?.retryAfterSeconds ?? header)
        case 503 where code == "TIMEOUT": return .timeout
        default: return .server(status: status, code: code, message: message)
        }
    }
}
