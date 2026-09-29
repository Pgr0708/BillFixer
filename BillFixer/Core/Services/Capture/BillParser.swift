import Foundation

/// Deterministic extraction of bill fields from OCR rows. No ML, no network — every value is
/// shown to the user for review before anything is analyzed (docs/analysis/BILL_ANALYSIS.md).
nonisolated enum BillParser {
    private static let labels: [(BillField, [String])] = [
        (.patientResponsibility, ["patient responsibility", "patient resp", "your responsibility", "amount you owe", "you owe", "patient portion"]),
        (.currentBalance, ["balance due", "amount due", "current balance", "please pay", "total due", "pay this amount", "new balance", "patient balance"]),
        (.insurancePayment, ["insurance payment", "insurance paid", "paid by insurance", "plan paid", "ins payment", "insurance pmt"]),
        (.adjustments, ["adjustment", "discount", "contractual", "write off", "write-off"]),
        (.previousPayments, ["previous payment", "payments received", "patient payment", "you paid", "payment received"]),
        (.totalCharges, ["total charges", "total billed", "total amount billed", "gross charges", "statement total", "total charge", "charges total"]),
    ]
    private static let facilityWords = ["hospital", "medical", "center", "clinic", "health", "healthcare", "physicians", "surgery",
                                        "radiology", "laboratory", "labs", "emergency", "urgent care", "memorial", "regional", "university"]
    private static let noiseWords = ["statement", "invoice", "page", "patient name", "guarantor", "remit", "billing", "questions", "pay online"]

    static func parse(_ result: OCRResult) -> BillDraft {
        var draft = BillDraft()
        let rows = result.rows
        var confidence: [BillField: Double] = [:]
        var consumedRows = Set<Int>()

        // 1. Labelled amounts ("Balance due  $1,234.56", or label on one row and amount on the next).
        for (field, keys) in labels {
            for (i, row) in rows.enumerated() where keys.contains(where: row.text.lowercased().contains) {
                var amount = TextPatterns.amounts(in: row.text).last
                var conf = row.confidence
                if amount == nil, i + 1 < rows.count, TextPatterns.letterCount(rows[i + 1].text) < 4 {
                    amount = TextPatterns.amounts(in: rows[i + 1].text).last
                    conf = min(conf, rows[i + 1].confidence) * 0.9
                }
                guard let amount else { continue }
                set(&draft, field, amount.magnitude.apiString)
                confidence[field] = conf
                consumedRows.insert(i)
                break
            }
        }

        // 2. Dates.
        for (i, row) in rows.enumerated() {
            let lower = row.text.lowercased()
            let dates = TextPatterns.dates(in: row.text)
            guard !dates.isEmpty else { continue }
            if draft.billDate == nil, ["statement date", "bill date", "billing date", "date issued", "invoice date", "date of statement"].contains(where: lower.contains) {
                draft.billDate = dates.first; confidence[.billDate] = row.confidence; consumedRows.insert(i)
            } else if draft.serviceDateStart == nil, ["date of service", "dates of service", "service date", "dos", "admit", "visit date"].contains(where: lower.contains) {
                draft.serviceDateStart = dates.first
                draft.serviceDateEnd = dates.count > 1 ? dates[1] : dates.first
                confidence[.serviceDate] = row.confidence
                consumedRows.insert(i)
            }
        }

        // 3. Account number & insurer.
        for row in rows {
            if draft.accountNumber.isEmpty, let r = row.text.range(of: #"(account|acct)\s*(number|no\.?|#)?\s*[:#]?\s*"#, options: [.regularExpression, .caseInsensitive]) {
                let tail = row.text[r.upperBound...].trimmed
                if let token = tail.split(separator: " ").first.map(String.init),
                   token.range(of: #"^[A-Za-z0-9-]{4,20}$"#, options: .regularExpression) != nil, token.contains(where: \.isNumber) {
                    draft.accountNumber = token; confidence[.accountNumber] = row.confidence
                }
            }
            if draft.insurerName.isEmpty, let r = row.text.range(of: #"(primary insurance|insurance carrier|insurance|payer|health plan)\s*[:]\s*"#, options: [.regularExpression, .caseInsensitive]) {
                let name = TextPatterns.description(of: String(row.text[r.upperBound...]))
                if TextPatterns.letterCount(name) >= 3 { draft.insurerName = String(name.prefix(120)); confidence[.insurerName] = row.confidence }
            }
        }

        // 4. Provider: the first facility-looking line near the top of page 1.
        let top = rows.prefix(while: { $0.page == 0 }).prefix(14)
        if let row = top.first(where: { r in
            let l = r.text.lowercased()
            return facilityWords.contains(where: l.contains) && !noiseWords.contains(where: l.contains) && TextPatterns.amounts(in: r.text).isEmpty
        }) ?? top.first(where: { r in
            TextPatterns.letterCount(r.text) >= 6 && r.text.split(separator: " ").count >= 2
                && !noiseWords.contains(where: r.text.lowercased().contains) && TextPatterns.amounts(in: r.text).isEmpty
                && TextPatterns.dates(in: r.text).isEmpty
        }) {
            draft.providerName = String(TextPatterns.description(of: row.text).prefix(120))
            confidence[.providerName] = row.confidence * (facilityWords.contains(where: row.text.lowercased().contains) ? 1 : 0.7)
        }

        // 5. Line items: rows with a description + an amount + (a code or a date), not already used as a label.
        for (i, row) in rows.enumerated() where !consumedRows.contains(i) {
            if let item = lineItem(from: row) { draft.lineItems.append(item) }
        }
        if draft.lineItems.count > 400 { draft.lineItems = Array(draft.lineItems.prefix(400)) }

        // 6. Fill gaps from line items, marked as inferred (low confidence) so the user checks them.
        if draft.totalCharges.isEmpty, draft.lineItems.count >= 2 {
            draft.totalCharges = draft.lineItemsTotal.apiString
            confidence[.totalCharges] = 0.4
        }
        if draft.serviceDateStart == nil {
            let dates = draft.lineItems.compactMap(\.dateOfService).sorted()
            draft.serviceDateStart = dates.first
            draft.serviceDateEnd = dates.last
            if !dates.isEmpty { confidence[.serviceDate] = 0.55 }
        }
        if draft.currentBalance.isEmpty, draft.patientResponsibility.isEmpty,
           let biggest = rows.suffix(12).flatMap({ TextPatterns.amounts(in: $0.text) }).max() {
            draft.currentBalance = biggest.magnitude.apiString
            confidence[.currentBalance] = 0.35
        }

        draft.lowConfidence = Set(confidence.filter { $0.value < 0.6 }.map(\.key))
        draft.ocrConfidence = result.averageConfidence
        return draft
    }

    static func lineItem(from row: OCRRow) -> LineItemDraft? {
        let text = row.text
        let amounts = TextPatterns.amounts(in: text)
        guard let total = amounts.last, let firstMoney = TextPatterns.firstMoneyRange(in: text) else { return nil }
        let beforeMoney = String(text[..<firstMoney.lowerBound])
        let code = TextPatterns.matches(TextPatterns.code, in: beforeMoney).first?.0
        let date = TextPatterns.dates(in: text).first
        guard code != nil || date != nil else { return nil }
        let description = TextPatterns.description(of: beforeMoney)
            .replacingOccurrences(of: #"\s\d{1,3}$"#, with: "", options: .regularExpression)   // trailing qty
        guard TextPatterns.letterCount(description) >= 3 else { return nil }
        let lower = description.lowercased()
        if ["total", "balance", "payment", "adjust", "subtotal"].contains(where: lower.hasPrefix) { return nil }

        var qty = "1"
        if let m = beforeMoney.range(of: #"\s(\d{1,3})\s*$"#, options: .regularExpression) {
            let n = beforeMoney[m].trimmed
            if let v = Int(n), v > 0, v < 100 { qty = n }
        }
        return LineItemDraft(code: code ?? "", description: String(description.prefix(200)), dateOfService: date,
                             quantity: qty, unitPrice: amounts.count >= 2 ? amounts[amounts.count - 2].magnitude.apiString : "",
                             total: total.apiString, confidence: row.confidence)
    }

    private static func set(_ d: inout BillDraft, _ f: BillField, _ v: String) {
        switch f {
        case .totalCharges: d.totalCharges = v
        case .insurancePayment: d.insurancePayment = v
        case .adjustments: d.adjustments = v
        case .previousPayments: d.previousPayments = v
        case .patientResponsibility: d.patientResponsibility = v
        case .currentBalance: d.currentBalance = v
        default: break
        }
    }
}
