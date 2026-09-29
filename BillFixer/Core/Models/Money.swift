//
//  Money.swift
//  Exact currency value (ADR-004: Decimal, never Double). Travels to/from the API as a string.
//

import Foundation

nonisolated struct Money: Codable, Hashable, Comparable, Sendable {
    let value: Decimal

    static let zero = Money(0)
    private static let posix = Locale(identifier: "en_US_POSIX")
    private static let usd = Locale(identifier: "en_US")

    init(_ value: Decimal) { self.value = value }
    init(cents: Int) { self.value = Decimal(cents) / 100 }

    /// Parses what people and OCR produce: "$1,234.56", "1234.5", "(12.00)", "12.00-", "12.00 CR".
    init?(parsing raw: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        var negative = false
        if s.hasPrefix("(") && s.hasSuffix(")") { negative = true; s = String(s.dropFirst().dropLast()) }
        if s.hasSuffix("-") { negative = true; s.removeLast() }
        if s.uppercased().hasSuffix("CR") { negative = true; s = String(s.dropLast(2)) }
        if s.hasPrefix("-") { negative = true; s.removeFirst() }
        s = s.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "").replacingOccurrences(of: " ", with: "")
        guard s.range(of: #"^\d{1,9}(\.\d{1,2})?$"#, options: .regularExpression) != nil,
              let d = Decimal(string: s, locale: Money.posix) else { return nil }
        self.value = negative ? -d : d
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self), let m = Money(parsing: s) { self = m; return }
        if let d = try? c.decode(Decimal.self) { self.value = d; return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid money value")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(apiString)
    }

    /// "1234.56" — what the API expects.
    var apiString: String {
        value.formatted(.number.precision(.fractionLength(2)).grouping(.never).locale(Money.posix))
    }

    /// "$1,234.56"
    var formatted: String { value.formatted(.currency(code: "USD").locale(Money.usd)) }

    /// "$892" when there are no cents, otherwise "$892.50".
    var formattedCompact: String {
        value == value.rounded(0)
            ? value.formatted(.currency(code: "USD").precision(.fractionLength(0)).locale(Money.usd))
            : formatted
    }

    var isNegative: Bool { value < 0 }
    var magnitude: Money { Money(value < 0 ? -value : value) }
    var doubleValue: Double { NSDecimalNumber(decimal: value).doubleValue } // display animation only

    static func + (a: Money, b: Money) -> Money { Money(a.value + b.value) }
    static func - (a: Money, b: Money) -> Money { Money(a.value - b.value) }
    static func < (a: Money, b: Money) -> Bool { a.value < b.value }
}

extension Decimal {
    nonisolated func rounded(_ scale: Int) -> Decimal {
        var input = self
        var result = Decimal()
        NSDecimalRound(&result, &input, scale, .plain)
        return result
    }
}
