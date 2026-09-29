import Foundation

/// Deterministic extraction of Explanation of Benefits totals. Reviewed by the user before submit.
nonisolated enum EOBParser {
    private static let labels: [(EOBField, [String])] = [
        (.patientResponsibility, ["patient responsibility", "what you owe", "you may owe", "your responsibility", "amount you owe", "member responsibility", "your share"]),
        (.allowedAmount, ["allowed amount", "amount allowed", "plan allowed", "approved amount", "negotiated", "plan discount price"]),
        (.insurerPayment, ["plan paid", "paid by plan", "insurance paid", "amount paid", "plan payment", "we paid", "paid to provider", "benefit paid"]),
        (.deductibleApplied, ["deductible"]),
        (.copay, ["copay", "co-pay", "copayment"]),
        (.coinsurance, ["coinsurance", "co-insurance"]),
        (.billedAmount, ["amount billed", "billed amount", "provider charges", "total charges", "billed charges", "charged"]),
    ]
    private static let insurers = ["aetna", "cigna", "united", "unitedhealthcare", "humana", "kaiser", "anthem", "blue cross", "blue shield",
                                   "bcbs", "molina", "centene", "ambetter", "oscar", "wellcare", "health net", "highmark", "medicare", "medicaid", "tricare"]

    static func parse(_ result: OCRResult) -> EOBDraft {
        var d = EOBDraft()
        var conf: [EOBField: Double] = [:]
        let rows = result.rows

        for (field, keys) in labels {
            // Prefer a "total" row when an EOB lists several claim lines.
            let candidates = rows.enumerated().filter { keys.contains(where: $0.element.text.lowercased().contains) }
            let pick = candidates.first { $0.element.text.lowercased().contains("total") } ?? candidates.first
            guard let (i, row) = pick else { continue }
            var amount = TextPatterns.amounts(in: row.text).last
            var c = row.confidence
            if amount == nil, i + 1 < rows.count { amount = TextPatterns.amounts(in: rows[i + 1].text).last; c *= 0.9 }
            guard let amount else { continue }
            let v = amount.magnitude.apiString
            switch field {
            case .patientResponsibility: d.patientResponsibility = v
            case .allowedAmount: d.allowedAmount = v
            case .insurerPayment: d.insurerPayment = v
            case .deductibleApplied: d.deductibleApplied = v
            case .copay: d.copay = v
            case .coinsurance: d.coinsurance = v
            case .billedAmount: d.billedAmount = v
            default: break
            }
            conf[field] = c
        }

        for row in rows {
            let lower = row.text.lowercased()
            if d.claimNumber.isEmpty, let r = row.text.range(of: #"claim\s*(number|no\.?|#|id)?\s*[:#]?\s*"#, options: [.regularExpression, .caseInsensitive]) {
                let token = row.text[r.upperBound...].trimmed.split(separator: " ").first.map(String.init) ?? ""
                if token.range(of: #"^[A-Za-z0-9-]{5,30}$"#, options: .regularExpression) != nil, token.contains(where: \.isNumber) { d.claimNumber = token }
            }
            if d.networkStatus == .unknown {
                if ["out-of-network", "out of network", "non-network", "non-participating", "nonparticipating"].contains(where: lower.contains) {
                    d.networkStatus = .outOfNetwork
                } else if ["in-network", "in network", "participating provider", "network provider"].contains(where: lower.contains) {
                    d.networkStatus = .inNetwork
                }
            }
            if d.serviceDateStart == nil, ["date of service", "service date", "dates of service"].contains(where: lower.contains) {
                d.serviceDateStart = TextPatterns.dates(in: row.text).first
            }
            if d.eobDate == nil, ["statement date", "date processed", "processed on", "date issued"].contains(where: lower.contains) {
                d.eobDate = TextPatterns.dates(in: row.text).first
            }
            if d.providerName.isEmpty, let r = row.text.range(of: #"(provider|rendering provider|facility)\s*(name)?\s*[:]\s*"#, options: [.regularExpression, .caseInsensitive]) {
                d.providerName = String(TextPatterns.description(of: String(row.text[r.upperBound...])).prefix(120))
            }
        }

        if let row = rows.prefix(20).first(where: { r in insurers.contains(where: r.text.lowercased().contains) }) {
            d.insurerName = String(TextPatterns.description(of: row.text).prefix(120))
            conf[.insurerName] = row.confidence
        }

        d.lowConfidence = Set(conf.filter { $0.value < 0.6 }.map(\.key))
        return d
    }
}
