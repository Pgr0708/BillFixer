import Foundation

nonisolated enum APIError: Error, Sendable, Equatable {
    case offline
    case timeout
    case network(String)
    case unauthorized(code: String, message: String)
    case premiumRequired(feature: String)
    case rateLimited(retryAfter: Int?)
    case validation(message: String, fields: [String: [String]])
    case conflict(code: String, message: String)
    case notFound(message: String)
    case server(status: Int, code: String, message: String)
    case decoding(String)
    case cancelled

    /// Short headline for a toast.
    var title: String {
        switch self {
        case .offline: "You’re offline"
        case .timeout: "Taking too long"
        case .network: "Connection problem"
        case .unauthorized: "Please sign in again"
        case .premiumRequired: "Premium feature"
        case .rateLimited: "Slow down a moment"
        case .validation: "Check your details"
        case .conflict: "Can’t do that yet"
        case .notFound: "Not found"
        case .server: "Something went wrong"
        case .decoding: "Unexpected response"
        case .cancelled: "Cancelled"
        }
    }

    /// Plain-language explanation with a recovery hint.
    var message: String {
        switch self {
        case .offline: "Check your internet connection and try again."
        case .timeout: "The server didn’t respond in time. Please try again."
        case .network: "We couldn’t reach Bill Fixer. Please try again."
        case let .unauthorized(_, message): message
        case let .premiumRequired(feature): "Upgrade to Premium to use \(feature)."
        case let .rateLimited(retry): retry.map { "Please wait \($0 < 60 ? "\($0) seconds" : "\($0 / 60) minutes") and try again." } ?? "Please wait a moment and try again."
        case let .validation(message, fields): fields.values.first?.first ?? message
        case let .conflict(_, message): message
        case let .notFound(message): message
        case let .server(_, _, message): message
        case .decoding: "Please update the app or try again later."
        case .cancelled: ""
        }
    }

    var isRetryable: Bool {
        switch self {
        case .offline, .timeout, .network, .rateLimited: true
        case let .server(status, _, _): status >= 500
        default: false
        }
    }
}

extension Error {
    /// Any error as an APIError (so views have one type to present).
    var asAPIError: APIError {
        if let e = self as? APIError { return e }
        if self is CancellationError { return .cancelled }
        if let u = self as? URLError { return APIError.from(u) }
        return .network(localizedDescription)
    }
}

extension APIError {
    static func from(_ error: URLError) -> APIError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff: .offline
        case .timedOut: .timeout
        case .cancelled: .cancelled
        default: .network(error.localizedDescription)
        }
    }
}

/// `{ "error": { "code", "message", "details", "requestId" } }`
nonisolated struct ServerErrorEnvelope: Decodable, Sendable {
    struct Body: Decodable, Sendable {
        let code: String
        let message: String
        let details: Details?
        let requestId: String?
    }
    struct Details: Decodable, Sendable {
        let fields: [String: [String]]?
        let feature: String?
        let retryAfterSeconds: Int?
    }
    let error: Body
}
