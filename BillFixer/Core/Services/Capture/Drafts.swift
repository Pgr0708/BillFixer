import Foundation

/// Editable, reviewed-by-the-user versions of what OCR extracted. Amounts stay as text until submit,
/// then go through `Money(parsing:)` — the server re-validates everything.

nonisolated enum BillField: String, Sendable, Hashable, CaseIterable {
    case providerName, accountNumber, billDate, serviceDate, insurerName
    case totalCharges, insurancePayment, adjustments, previousPayments, patientResponsibility, currentBalance
}

nonisolated struct LineItemDraft: Identifiable, Hashable, Sendable {
    var id = UUID()
    var code = ""
    var description = ""
    var dateOfService: Date?
    var quantity = "1"
    var unitPrice = ""
    var total = ""
    var confidence = 1.0
    var isUserEdited = false

    var isLowConfidence: Bool { !isUserEdited && confidence < 0.6 }
    var totalMoney: Money? { Money(parsing: total) }
}

nonisolated struct BillDraft: Hashable, Sendable {
    var providerName = ""
    var accountNumber = ""
    var billDate: Date?
    var serviceDateStart: Date?
    var serviceDateEnd: Date?
    var insurerName = ""
    var totalCharges = ""
    var insurancePayment = ""
    var adjustments = ""
    var previousPayments = ""
    var patientResponsibility = ""
    var currentBalance = ""
    var lineItems: [LineItemDraft] = []
    var lowConfidence: Set<BillField> = []
    var ocrConfidence: Double?

    var lineItemsTotal: Money { lineItems.compactMap(\.totalMoney).reduce(.zero, +) }

    mutating func markEdited(_ field: BillField) { lowConfidence.remove(field) }

    /// First problem that would make the server reject the submission, phrased for the user.
    var validationError: String? {
        if providerName.trimmingCharacters(in: .whitespaces).isEmpty { return "Add the provider or hospital name." }
        let amounts: [(String, String)] = [("Total charges", totalCharges), ("Patient responsibility", patientResponsibility),
                                          ("Current balance", currentBalance)]
        for (name, value) in amounts where !value.isEmpty {
            guard let m = Money(parsing: value) else { return "\(name) isn’t a valid amount." }
            if m.isNegative { return "\(name) can’t be negative." }
        }
        for (name, value) in [("Insurance payment", insurancePayment), ("Adjustments", adjustments), ("Previous payments", previousPayments)]
            where !value.isEmpty && Money(parsing: value) == nil {
            return "\(name) isn’t a valid amount."
        }
        if currentBalance.isEmpty && patientResponsibility.isEmpty && totalCharges.isEmpty && lineItems.isEmpty {
            return "Add at least the amount you’re being asked to pay."
        }
        for (i, item) in lineItems.enumerated() {
            if item.description.trimmingCharacters(in: .whitespaces).isEmpty { return "Line \(i + 1) needs a description." }
            if item.totalMoney == nil { return "Line \(i + 1) needs a valid amount." }
        }
        if let s = serviceDateStart, let e = serviceDateEnd, s > e { return "Service start date must be before the end date." }
        return nil
    }

    func submission(documentId: String?) -> BillSubmission {
        func m(_ s: String) -> Money? { s.isEmpty ? nil : Money(parsing: s)?.magnitude }
        func signed(_ s: String) -> Money? { s.isEmpty ? nil : Money(parsing: s) }
        let items = lineItems.enumerated().map { i, item in
            LineItemSubmission(lineNumber: i + 1,
                               code: item.code.trimmed.isEmpty ? nil : item.code.trimmed.uppercased(),
                               description: String(item.description.trimmed.prefix(500)),
                               dateOfService: item.dateOfService.map(DateHelpers.dayString),
                               quantity: Self.quantity(item.quantity),
                               unitPrice: m(item.unitPrice),
                               totalAmount: item.totalMoney ?? .zero,
                               adjustment: nil,
                               isUserEdited: item.isUserEdited,
                               ocrConfidence: min(max(item.confidence, 0), 1))
        }
        return BillSubmission(documentId: documentId, providerId: nil,
                              providerName: String(providerName.trimmed.prefix(255)),
                              accountNumber: accountNumber.trimmed.isEmpty ? nil : String(accountNumber.trimmed.prefix(100)),
                              billDate: billDate.map(DateHelpers.dayString),
                              serviceDateStart: serviceDateStart.map(DateHelpers.dayString),
                              serviceDateEnd: (serviceDateEnd ?? serviceDateStart).map(DateHelpers.dayString),
                              insurerName: insurerName.trimmed.isEmpty ? nil : insurerName.trimmed,
                              totalCharges: m(totalCharges),
                              insurancePayment: signed(insurancePayment)?.magnitude,
                              adjustments: signed(adjustments)?.magnitude,
                              previousPayments: signed(previousPayments)?.magnitude,
                              patientResponsibility: m(patientResponsibility),
                              currentBalance: m(currentBalance),
                              isItemized: lineItems.count >= 2,
                              ocrConfidence: ocrConfidence.map { min(max($0, 0), 1) },
                              lineItems: items)
    }

    private static func quantity(_ s: String) -> String {
        let t = s.trimmed
        return t.range(of: #"^\d{1,5}(\.\d{1,3})?$"#, options: .regularExpression) != nil && t != "0" ? t : "1"
    }
}

nonisolated enum NetworkStatus: String, Sendable, CaseIterable, Identifiable {
    case inNetwork = "in", outOfNetwork = "out", unknown
    var id: String { rawValue }
    var title: String {
        switch self {
        case .inNetwork: "In-network"
        case .outOfNetwork: "Out-of-network"
        case .unknown: "Not sure"
        }
    }
}

nonisolated enum EOBField: String, Sendable, Hashable {
    case insurerName, claimNumber, billedAmount, allowedAmount, insurerPayment, deductibleApplied, copay, coinsurance, patientResponsibility
}

nonisolated struct EOBDraft: Hashable, Sendable {
    var insurerName = ""
    var claimNumber = ""
    var eobDate: Date?
    var providerName = ""
    var serviceDateStart: Date?
    var networkStatus: NetworkStatus = .unknown
    var billedAmount = ""
    var allowedAmount = ""
    var insurerPayment = ""
    var deductibleApplied = ""
    var copay = ""
    var coinsurance = ""
    var patientResponsibility = ""
    var lowConfidence: Set<EOBField> = []

    var validationError: String? {
        let all = [("Billed", billedAmount), ("Allowed", allowedAmount), ("Plan paid", insurerPayment), ("Deductible", deductibleApplied),
                   ("Copay", copay), ("Coinsurance", coinsurance), ("You may owe", patientResponsibility)]
        for (name, v) in all where !v.isEmpty && Money(parsing: v) == nil { return "\(name) isn’t a valid amount." }
        if patientResponsibility.isEmpty && allowedAmount.isEmpty { return "Add “What you owe” from your EOB." }
        return nil
    }

    func submission(documentId: String?) -> EOBSubmission {
        func m(_ s: String) -> Money? { s.isEmpty ? nil : Money(parsing: s)?.magnitude }
        return EOBSubmission(documentId: documentId,
                             claimNumber: claimNumber.trimmed.isEmpty ? nil : claimNumber.trimmed,
                             eobDate: eobDate.map(DateHelpers.dayString),
                             insurerName: insurerName.trimmed.isEmpty ? nil : insurerName.trimmed,
                             serviceDateStart: serviceDateStart.map(DateHelpers.dayString),
                             serviceDateEnd: serviceDateStart.map(DateHelpers.dayString),
                             providerName: providerName.trimmed.isEmpty ? nil : providerName.trimmed,
                             networkStatus: networkStatus.rawValue,
                             billedAmount: m(billedAmount), allowedAmount: m(allowedAmount), insurerPayment: m(insurerPayment),
                             deductibleApplied: m(deductibleApplied), copay: m(copay), coinsurance: m(coinsurance),
                             patientResponsibility: m(patientResponsibility))
    }
}

extension StringProtocol {
    nonisolated var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
