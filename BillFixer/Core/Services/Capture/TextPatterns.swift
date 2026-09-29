import Foundation

/// Regex helpers shared by the bill and EOB parsers. Pure functions — unit tested.
nonisolated enum TextPatterns {
    /// Amounts with cents: $1,234.56 · 1234.56 · (12.00) · 12.00- · 12.00 CR
    static let money = try! NSRegularExpression(pattern: #"\(?-?\$?\s?\d{1,3}(?:,\d{3})*\.\d{2}\)?(?:\s?CR)?-?|\(?-?\$?\s?\d{4,7}\.\d{2}\)?"#)
    /// CPT (5 digits), HCPCS (letter + 4 digits), revenue codes (0 + 3 digits).
    static let code = try! NSRegularExpression(pattern: #"(?<![\d$.,/-])(\d{5}|[A-V]\d{4}|0\d{3})(?![\d.,/])"#)
    static let numericDate = try! NSRegularExpression(pattern: #"\b(\d{1,2})[/-](\d{1,2})[/-](\d{2}|\d{4})\b"#)
    static let isoDate = try! NSRegularExpression(pattern: #"\b(\d{4})-(\d{2})-(\d{2})\b"#)
    static let wordDate = try! NSRegularExpression(pattern: #"\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*\.?\s+(\d{1,2}),?\s+(\d{4})\b"#, options: .caseInsensitive)

    static func matches(_ re: NSRegularExpression, in s: String) -> [(String, Range<String.Index>)] {
        re.matches(in: s, range: NSRange(s.startIndex..., in: s)).compactMap { m in
            Range(m.range, in: s).map { (String(s[$0]), $0) }
        }
    }

    static func amounts(in s: String) -> [Money] {
        matches(money, in: s).compactMap { Money(parsing: $0.0) }
    }

    static func firstMoneyRange(in s: String) -> Range<String.Index>? { matches(money, in: s).first?.1 }

    static func dates(in s: String) -> [Date] {
        var out: [(Date, String.Index)] = []
        let cal = Calendar(identifier: .gregorian)
        for m in numericDate.matches(in: s, range: NSRange(s.startIndex..., in: s)) {
            guard let r = Range(m.range, in: s),
                  let mo = Int(sub(s, m.range(at: 1))), let d = Int(sub(s, m.range(at: 2))), var y = Int(sub(s, m.range(at: 3))) else { continue }
            if y < 100 { y += 2000 }
            if let date = valid(cal, y, mo, d) { out.append((date, r.lowerBound)) }
        }
        for m in isoDate.matches(in: s, range: NSRange(s.startIndex..., in: s)) {
            guard let r = Range(m.range, in: s),
                  let y = Int(sub(s, m.range(at: 1))), let mo = Int(sub(s, m.range(at: 2))), let d = Int(sub(s, m.range(at: 3))) else { continue }
            if let date = valid(cal, y, mo, d) { out.append((date, r.lowerBound)) }
        }
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        for m in wordDate.matches(in: s, range: NSRange(s.startIndex..., in: s)) {
            guard let r = Range(m.range, in: s),
                  let mo = months.firstIndex(of: String(sub(s, m.range(at: 1)).lowercased().prefix(3))),
                  let d = Int(sub(s, m.range(at: 2))), let y = Int(sub(s, m.range(at: 3))) else { continue }
            if let date = valid(cal, y, mo + 1, d) { out.append((date, r.lowerBound)) }
        }
        return out.sorted { $0.1 < $1.1 }.map(\.0)
    }

    private static func sub(_ s: String, _ r: NSRange) -> String { Range(r, in: s).map { String(s[$0]) } ?? "" }

    private static func valid(_ cal: Calendar, _ y: Int, _ m: Int, _ d: Int) -> Date? {
        guard (1990...2100).contains(y), (1...12).contains(m), (1...31).contains(d) else { return nil }
        var c = DateComponents(year: y, month: m, day: d)
        c.hour = 12
        guard let date = cal.date(from: c), cal.component(.day, from: date) == d else { return nil }
        return date
    }

    /// Strips amounts, dates and codes from a row to leave the human description.
    static func description(of s: String) -> String {
        var t = s
        for re in [money, numericDate, isoDate, wordDate, code] {
            t = re.stringByReplacingMatches(in: t, range: NSRange(t.startIndex..., in: t), withTemplate: " ")
        }
        return t.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " -:|*#.\t"))
    }

    static func letterCount(_ s: String) -> Int { s.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count }
}
