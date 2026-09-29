//
//  APIModels.swift
//  Wire types for the BillFixer API. `nonisolated` so they can be decoded off the main actor.
//

import Foundation
import SwiftUI

/// Decodes unknown enum values to a fallback instead of failing the whole response.
nonisolated protocol ResilientEnum: RawRepresentable, Codable, Sendable where RawValue == String {
    static var fallback: Self { get }
}
extension ResilientEnum {
    nonisolated init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? Self.fallback
    }
}

// MARK: - Auth & account

nonisolated struct User: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let email: String?
    let displayName: String?
    let hasPassword: Bool?
    let signInMethod: String?
    let createdAt: Date?

    var firstName: String {
        let name = displayName?.split(separator: " ").first.map(String.init)
        return name ?? email?.split(separator: "@").first.map(String.init) ?? "there"
    }
    var initial: String { String(firstName.prefix(1)).uppercased() }
}

nonisolated struct AuthSession: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: User
}

nonisolated struct TokenPair: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

nonisolated enum Tier: String, ResilientEnum { case free, premium; static let fallback = Tier.free }

nonisolated struct SubscriptionStatus: Codable, Sendable, Hashable {
    let tier: Tier
    let productId: String?
    let expiresAt: Date?
    let isInGracePeriod: Bool
    static let free = SubscriptionStatus(tier: .free, productId: nil, expiresAt: nil, isInGracePeriod: false)
}

nonisolated struct MeResponse: Codable, Sendable {
    let user: User
    let subscription: SubscriptionStatus
}

nonisolated struct UserEnvelope: Codable, Sendable { let user: User }
nonisolated struct MessageResponse: Codable, Sendable { let message: String? }

// MARK: - Cases

nonisolated enum CaseStatus: String, ResilientEnum, CaseIterable, Identifiable {
    case draft, active, awaitingResponse = "awaiting_response", resolved, closed
    static let fallback = CaseStatus.active
    var id: String { rawValue }
    var title: String {
        switch self {
        case .draft: "Draft"
        case .active: "Active"
        case .awaitingResponse: "Awaiting reply"
        case .resolved: "Resolved"
        case .closed: "Closed"
        }
    }
}

nonisolated struct NextDeadline: Codable, Sendable, Hashable {
    let label: String
    let dueDate: String
    let type: String
}

nonisolated struct CaseSummary: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let title: String
    let status: CaseStatus
    let providerName: String?
    let serviceType: String?
    let billDate: String?
    let originalBalance: Money?
    let currentBalance: Money?
    let verifiedSavings: Money?
    let potentialSavings: Money?
    let findingCount: Int
    let nextDeadline: NextDeadline?
    let lastAnalyzedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    var displayName: String { providerName ?? title }
    var isOpen: Bool { [.draft, .active, .awaitingResponse].contains(status) }
}

nonisolated struct CasesResponse: Codable, Sendable { let cases: [CaseSummary] }
nonisolated struct CaseCreated: Codable, Sendable { let caseId: String; let `case`: CaseSummary? }

nonisolated struct CaseDetail: Codable, Sendable, Hashable {
    let id: String
    let title: String
    let status: CaseStatus
    let providerName: String?
    let serviceType: String?
    let billDate: String?
    let originalBalance: Money?
    let currentBalance: Money?
    let verifiedSavings: Money?
    let potentialSavings: Money?
    let findingCount: Int
    let nextDeadline: NextDeadline?
    let notes: String?
    let insurerName: String?
    let providerId: String?
    let finalBalance: Money?
    let lastAnalyzedAt: Date?
    let createdAt: Date?
}

nonisolated struct DocumentInfo: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let type: String
    let source: String
    let pageCount: Int
    let ocrConfidence: Double?
    let createdAt: Date?
}

nonisolated struct Deadline: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let type: String
    let label: String
    let dueDate: String
    let isCompleted: Bool
    let completedAt: Date?
    let notifyDays: [Int]
}

nonisolated struct ScriptSummary: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let callTarget: String
    let issueType: String
    let createdAt: Date?
}

nonisolated struct CaseDetailResponse: Codable, Sendable {
    let detail: CaseDetail
    let documents: [DocumentInfo]
    let deadlines: [Deadline]
    let letters: [LetterSummary]
    let scripts: [ScriptSummary]
    enum CodingKeys: String, CodingKey { case detail = "case", documents, deadlines, letters, scripts }
}

nonisolated struct CaseEvent: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let type: String
    let label: String
    let isUserLog: Bool
    let occurredAt: Date?
}
nonisolated struct EventsResponse: Codable, Sendable { let events: [CaseEvent] }
nonisolated struct DeadlinesResponse: Codable, Sendable { let deadlines: [Deadline] }
nonisolated struct IDResponse: Codable, Sendable {
    let billId: String?; let eobId: String?; let gfeId: String?; let documentId: String?; let deadlineId: String?
}
nonisolated struct ResolveResponse: Codable, Sendable { let verifiedSavings: Money? }

// MARK: - Findings

nonisolated enum Severity: String, ResilientEnum, CaseIterable {
    case strong, likely, possible, informational
    static let fallback = Severity.informational
    var rank: Int { Severity.allCases.firstIndex(of: self) ?? 3 }
    var title: String { rawValue.capitalized }
}

nonisolated enum Confidence: String, ResilientEnum {
    case high, medium, low
    static let fallback = Confidence.low
    var title: String { "\(rawValue.capitalized) confidence" }
}

nonisolated enum FindingStatus: String, ResilientEnum {
    case open, dismissed, fixed, partiallyFixed = "partially_fixed", denied, wrong
    static let fallback = FindingStatus.open
}

nonisolated struct Evidence: Codable, Sendable, Hashable {
    let sourceType: String
    let label: String
    let value: String?
    let url: String?
}

nonisolated struct Finding: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let type: String
    let severity: Severity
    let confidence: Confidence
    let title: String
    let explanation: String
    let whatYouCanDo: String?
    let counterCase: String?
    let amountFlagged: Money?
    let amountReference: Money?
    let amountDifference: Money?
    let recommendedAction: String?
    let deadlineDate: String?
    let status: FindingStatus
    let locked: Bool
    let evidence: [Evidence]

    var kind: FindingKind { FindingKind(rawValue: type) ?? .informational }
}

nonisolated struct FirstAction: Codable, Sendable, Hashable {
    let findingId: String
    let action: String?
    let title: String
}

nonisolated struct FindingsSummary: Codable, Sendable, Hashable {
    let total: Int
    let bySeverity: [String: Int]
    let potentialSavings: Money?
    let potentialSavingsLocked: Bool
    let recommendedFirstAction: FirstAction?

    func count(_ s: Severity) -> Int { bySeverity[s.rawValue] ?? 0 }
}

nonisolated struct FindingsResponse: Codable, Sendable {
    let findings: [Finding]
    let summary: FindingsSummary
}

// MARK: - Jobs

nonisolated enum StepStatus: String, ResilientEnum { case pending, running, complete, failed; static let fallback = StepStatus.pending }

nonisolated struct JobStep: Codable, Sendable, Hashable, Identifiable {
    let key: String
    let label: String
    let status: StepStatus
    var id: String { key }
}

nonisolated struct JobStatus: Codable, Sendable {
    let jobId: String?
    let type: String?
    let status: String
    let progress: Double
    let steps: [JobStep]
    let resultType: String?
    let resultId: String?
    let errorCode: String?

    var isFinished: Bool { status == "complete" || status == "failed" }
}

nonisolated struct JobCreated: Codable, Sendable {
    let jobId: String
    let estimatedSeconds: Int?
}

// MARK: - Letters & scripts

nonisolated enum LetterType: String, ResilientEnum, CaseIterable, Identifiable {
    case itemizedBillRequest = "itemized_bill_request", duplicateDispute = "duplicate_dispute",
         eobMismatchDispute = "eob_mismatch_dispute", cashPriceAdjustment = "cash_price_adjustment",
         financialAssistance = "financial_assistance", gfeDispute = "gfe_dispute", insuranceAppeal = "insurance_appeal",
         collectionsDispute = "collections_dispute", paymentPlanRequest = "payment_plan_request", nsaDispute = "nsa_dispute"
    static let fallback = LetterType.itemizedBillRequest
    var id: String { rawValue }
    var title: String {
        switch self {
        case .itemizedBillRequest: "Request itemized bill"
        case .duplicateDispute: "Dispute duplicate charge"
        case .eobMismatchDispute: "EOB mismatch dispute"
        case .cashPriceAdjustment: "Ask for cash price"
        case .financialAssistance: "Financial assistance"
        case .gfeDispute: "Good Faith Estimate dispute"
        case .insuranceAppeal: "Insurance claim review"
        case .collectionsDispute: "Collections dispute"
        case .paymentPlanRequest: "Payment plan request"
        case .nsaDispute: "No Surprises Act request"
        }
    }
    var recipientType: String {
        switch self {
        case .insuranceAppeal, .nsaDispute: "insurer"
        case .collectionsDispute: "collections"
        default: "provider"
        }
    }
}

nonisolated struct Letter: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let caseId: String
    let findingId: String?
    let type: LetterType
    let subject: String?
    let content: String
    let recipientName: String?
    let recipientType: String
    let version: Int
    let isFallback: Bool
    let sentAt: Date?
    let createdAt: Date?
}

nonisolated struct LetterSummary: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let caseId: String
    let findingId: String?
    let type: LetterType
    let subject: String?
    let recipientName: String?
    let recipientType: String
    let version: Int
    let sentAt: Date?
    let createdAt: Date?
}

nonisolated struct MarkSentResponse: Codable, Sendable { let sentAt: Date? }

nonisolated struct ScriptBranch: Codable, Sendable, Hashable, Identifiable {
    let trigger: String
    let response: String
    let followUp: String?
    let childBranches: [ScriptBranch]?
    var id: String { trigger }
}

nonisolated struct PhoneScript: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let callTarget: String
    let issueType: String
    let openingStatement: String
    let branches: [ScriptBranch]
    let doNotSay: [String]?
    let postCallChecklist: [String]
}

nonisolated struct ScriptContent: Codable, Sendable, Hashable {
    let openingStatement: String
    let branches: [ScriptBranch]
    let doNotSay: [String]?
    let postCallChecklist: [String]
}

nonisolated struct LibraryScript: Codable, Sendable, Hashable, Identifiable {
    let key: String
    let title: String
    let callTarget: String
    let branchCount: Int
    let tag: String?
    let locked: Bool
    let script: ScriptContent
    var id: String { key }
}
nonisolated struct ScriptLibraryResponse: Codable, Sendable { let scripts: [LibraryScript] }

// MARK: - Reference

nonisolated struct Provider: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let facilityName: String?
    let address: String?
    let city: String?
    let state: String?
    let zip: String?
    let phone: String?
    let hospitalType: String?
    let taxStatus: String
    let hasMRF: Bool
    let hasFAP: Bool
    var location: String { [city, state].compactMap { $0 }.joined(separator: ", ") }
}
nonisolated struct ProviderSearchResponse: Codable, Sendable { let results: [Provider] }

nonisolated struct FinancialAssistanceInfo: Codable, Sendable, Hashable {
    let providerId: String
    let providerName: String
    let taxStatus: String
    let fapUrl: String?
    let applicationUrl: String?
    let applicationPhone: String?
    let incomeThresholdFpl: Double?
    let freeCareThresholdFpl: Double?
    let requiredDocs: [String]
    let allowsRetroactive: Bool?
}

nonisolated struct RightInfo: Codable, Sendable, Hashable, Identifiable {
    let key: String
    let title: String
    let summary: String
    let appliesWhen: [String]
    let whatToDo: [String]
    let citation: String
    let sourceUrl: String
    let letterType: LetterType?
    var id: String { key }
}
nonisolated struct RightsResponse: Codable, Sendable { let rights: [RightInfo] }

nonisolated struct FPLEstimate: Codable, Sendable, Hashable {
    let year: Int
    let region: String
    let householdSize: Int
    let guideline: Money
    let fplPercent: Int
    let sourceUrl: String?
}
