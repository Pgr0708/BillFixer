import Foundation

/// Client-side checks that mirror the backend validators, so users see errors before a round trip.
nonisolated enum Validation {
    static func email(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return "Enter your email" }
        return t.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]{2,}$"#, options: .regularExpression) == nil ? "Enter a valid email" : nil
    }

    // Keep these in sync with backend/src/validators/index.js (newEmail, password).
    private static let emailPattern = #"^(?!\.)(?!.*\.\.)[a-z0-9._%+-]{1,64}(?<!\.)@(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,24}$"#
    private static let emailTypos = [
        "gmial.com": "gmail.com", "gmai.com": "gmail.com", "gamil.com": "gmail.com", "gmail.co": "gmail.com", "gmail.con": "gmail.com", "gnail.com": "gmail.com",
        "hotmial.com": "hotmail.com", "hotmail.co": "hotmail.com", "hotmai.com": "hotmail.com",
        "yahooo.com": "yahoo.com", "yaho.com": "yahoo.com", "yahoo.co": "yahoo.com", "yahoo.con": "yahoo.com",
        "outlok.com": "outlook.com", "outlook.co": "outlook.com", "iclod.com": "icloud.com", "icloud.co": "icloud.com", "icoud.com": "icloud.com",
    ]
    private static let commonPasswords: Set<String> = [
        "password", "password1", "password12", "password123", "passw0rd", "12345678", "123456789", "1234567890",
        "qwerty123", "qwertyuiop", "abc12345", "abcd1234", "iloveyou1", "welcome1", "welcome123", "letmein1", "admin123", "monkey123",
        "11111111", "1q2w3e4r", "1qaz2wsx", "football1", "baseball1", "sunshine1", "princess1", "billfixer1", "billfixer123",
    ]

    /// For sign up / change email — stricter than `email`, which sign-in uses so older accounts still work.
    static func newEmail(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespaces).lowercased()
        if t.isEmpty { return "Enter your email" }
        if t.count > 254 { return "Email is too long" }
        if t.range(of: emailPattern, options: .regularExpression) == nil { return "Enter a valid email, like name@example.com" }
        if let fix = t.split(separator: "@").last.flatMap({ emailTypos[String($0)] }) { return "Did you mean @\(fix)?" }
        return nil
    }

    /// Live checklist shown while creating a password.
    static func passwordRules(_ p: String, email: String) -> [(label: String, met: Bool)] {
        [("At least 8 characters", p.count >= 8 && p.count <= 128),
         ("A letter and a number", p.contains(where: \.isLetter) && p.contains(where: \.isNumber)),
         ("Not a common password", !p.isEmpty && !commonPasswords.contains(p.lowercased()) && !hasRepeats(p)),
         ("Doesn’t include your email", !p.isEmpty && !containsEmailName(p, email))]
    }

    static func newPassword(_ s: String, email: String = "") -> String? {
        if s.count < 8 { return "Use at least 8 characters" }
        if s.count > 128 { return "Use at most 128 characters" }
        if !s.contains(where: \.isLetter) || !s.contains(where: \.isNumber) { return "Use at least one letter and one number" }
        if s != s.trimmingCharacters(in: .whitespaces) { return "Remove spaces at the start or end" }
        if hasRepeats(s) { return "Avoid repeating the same character" }
        if commonPasswords.contains(s.lowercased()) { return "This password is too common. Pick something harder to guess" }
        if containsEmailName(s, email) { return "Don’t use your email in your password" }
        return nil
    }

    static func confirm(_ password: String, _ again: String) -> String? {
        again.isEmpty ? "Type your password again" : (again == password ? nil : "Passwords don’t match")
    }

    private static func hasRepeats(_ s: String) -> Bool { s.range(of: #"(.)\1{3,}"#, options: .regularExpression) != nil }

    private static func containsEmailName(_ p: String, _ email: String) -> Bool {
        let local = email.trimmingCharacters(in: .whitespaces).lowercased().split(separator: "@").first.map(String.init) ?? ""
        return local.count >= 4 && p.lowercased().contains(local)
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
