import Foundation

/// Client-side checks that mirror the backend validators, so users see errors before a round trip.
nonisolated enum Validation {
    static func email(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return "Enter your email" }
        return t.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]{2,}$"#, options: .regularExpression) == nil ? "Enter a valid email" : nil
    }

    static func newPassword(_ s: String) -> String? {
        if s.count < 8 { return "Use at least 8 characters" }
        if s.count > 128 { return "Use at most 128 characters" }
        return nil
    }

    static func resetCode(_ s: String) -> String? {
        s.range(of: #"^\d{6}$"#, options: .regularExpression) == nil ? "Enter the 6-digit code" : nil
    }

    static func required(_ s: String, _ field: String) -> String? {
        s.trimmingCharacters(in: .whitespaces).isEmpty ? "\(field) is required" : nil
    }

    static func stateCode(_ s: String) -> String? {
        s.isEmpty || s.range(of: #"^[A-Za-z]{2}$"#, options: .regularExpression) != nil ? nil : "Use a 2-letter state code"
    }
}
