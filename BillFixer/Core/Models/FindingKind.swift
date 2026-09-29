import Foundation

/// Finding types from the backend engine (docs/analysis/BILL_ANALYSIS.md).
nonisolated enum FindingKind: String, Sendable, CaseIterable {
    case duplicateCharge = "duplicate_charge"
    case billEobMismatch = "bill_eob_mismatch"
    case arithmeticError = "arithmetic_error"
    case quantityAnomaly = "quantity_anomaly"
    case serviceDateMismatch = "service_date_mismatch"
    case priceAboveCashPrice = "price_above_cash_price"
    case priceAboveNegotiatedRate = "price_above_negotiated_rate"
    case medicareBenchmark = "medicare_benchmark"
    case financialAssistanceEligible = "financial_assistance_eligible"
    case noSurprisesPossible = "no_surprises_possible"
    case gfeDisputeEligible = "gfe_dispute_eligible"
    case paidAmountMismatch = "paid_amount_mismatch"
    case balanceMismatch = "balance_mismatch"
    case itemizedBillMissing = "itemized_bill_missing"
    case informational

    /// Letter the "Generate letter" action should draft for this finding.
    var letterType: LetterType {
        switch self {
        case .duplicateCharge: .duplicateDispute
        case .billEobMismatch: .eobMismatchDispute
        case .paidAmountMismatch: .insuranceAppeal
        case .priceAboveCashPrice, .priceAboveNegotiatedRate: .cashPriceAdjustment
        case .financialAssistanceEligible: .financialAssistance
        case .gfeDisputeEligible: .gfeDispute
        case .noSurprisesPossible: .nsaDispute
        default: .itemizedBillRequest
        }
    }

    /// Rights-catalog entry to open for this finding, if any.
    var rightKey: String? {
        switch self {
        case .noSurprisesPossible: "no_surprises_act"
        case .gfeDisputeEligible: "good_faith_estimate"
        case .financialAssistanceEligible: "financial_assistance"
        case .itemizedBillMissing: "itemized_bill"
        case .billEobMismatch: "eob_match"
        case .priceAboveCashPrice, .priceAboveNegotiatedRate: "price_transparency"
        default: nil
        }
    }

    var callTarget: String {
        switch self {
        case .paidAmountMismatch, .noSurprisesPossible: "insurer"
        default: "provider_billing"
        }
    }
}
