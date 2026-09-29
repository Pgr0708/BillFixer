//
//  Requests.swift
//  Request bodies. Keys match the backend's strict (unknown-key-rejecting) validators exactly.
//

import Foundation

nonisolated struct AppleSignInRequest: Encodable, Sendable {
    let identityToken: String
    let authorizationCode: String?
    let nonce: String
    let displayName: String?
}
nonisolated struct RegisterRequest: Encodable, Sendable { let email: String; let password: String; let displayName: String? }
nonisolated struct LoginRequest: Encodable, Sendable { let email: String; let password: String }
nonisolated struct RefreshRequest: Encodable, Sendable { let refreshToken: String }
nonisolated struct ForgotPasswordRequest: Encodable, Sendable { let email: String }
nonisolated struct ResetPasswordRequest: Encodable, Sendable { let email: String; let code: String; let newPassword: String }
nonisolated struct PatchMeRequest: Encodable, Sendable { let displayName: String }
nonisolated struct ChangeEmailRequest: Encodable, Sendable { let email: String; let currentPassword: String? }

nonisolated struct CreateCaseRequest: Encodable, Sendable { let title: String; let billDate: String?; let serviceType: String? }
nonisolated struct PatchCaseRequest: Encodable, Sendable {
    var title: String? = nil
    var status: String? = nil
    var currentBalance: Money? = nil
    var notes: String? = nil
}
nonisolated struct CreateDocumentRequest: Encodable, Sendable {
    let type: String
    let source: String
    let pageCount: Int
    let ocrConfidence: Double?
    let sha256: String?
}

nonisolated struct LineItemSubmission: Encodable, Sendable {
    let lineNumber: Int
    let code: String?
    let description: String
    let dateOfService: String?
    let quantity: String
    let unitPrice: Money?
    let totalAmount: Money
    let adjustment: Money?
    let isUserEdited: Bool
    let ocrConfidence: Double?
}

nonisolated struct BillSubmission: Encodable, Sendable {
    let documentId: String?
    let providerId: String?
    let providerName: String
    let accountNumber: String?
    let billDate: String?
    let serviceDateStart: String?
    let serviceDateEnd: String?
    let insurerName: String?
    let totalCharges: Money?
    let insurancePayment: Money?
    let adjustments: Money?
    let previousPayments: Money?
    let patientResponsibility: Money?
    let currentBalance: Money?
    let isItemized: Bool
    let ocrConfidence: Double?
    let lineItems: [LineItemSubmission]
}

nonisolated struct EOBSubmission: Encodable, Sendable {
    let documentId: String?
    let claimNumber: String?
    let eobDate: String?
    let insurerName: String?
    let serviceDateStart: String?
    let serviceDateEnd: String?
    let providerName: String?
    let networkStatus: String
    let billedAmount: Money?
    let allowedAmount: Money?
    let insurerPayment: Money?
    let deductibleApplied: Money?
    let copay: Money?
    let coinsurance: Money?
    let patientResponsibility: Money?
}

nonisolated struct GFESubmission: Encodable, Sendable {
    let providerName: String?
    let estimateDate: String?
    let totalEstimate: Money
}

nonisolated struct AnalysisContext: Encodable, Sendable, Hashable {
    var wasEmergency: Bool? = nil
    var hasInsurance: Bool? = nil
    var outOfNetwork: Bool? = nil
    var householdSize: Int? = nil
    var annualIncome: Money? = nil
    var state: String? = nil
}
nonisolated struct AnalyzeRequest: Encodable, Sendable { let context: AnalysisContext }

nonisolated struct PatchFindingRequest: Encodable, Sendable { let status: String }
nonisolated struct CreateLetterRequest: Encodable, Sendable {
    let type: String?
    let findingId: String?
    let recipientName: String?
    let recipientType: String
}
nonisolated struct PatchLetterRequest: Encodable, Sendable { let content: String }
nonisolated struct MarkSentRequest: Encodable, Sendable { let sentAt: String? }
nonisolated struct CreateScriptRequest: Encodable, Sendable { let findingId: String?; let callTarget: String; let issueType: String }
nonisolated struct CreateDeadlineRequest: Encodable, Sendable { let type: String; let label: String; let dueDate: String; let notifyDays: [Int]? }
nonisolated struct PatchDeadlineRequest: Encodable, Sendable { var label: String? = nil; var dueDate: String? = nil; var isCompleted: Bool? = nil }
nonisolated struct CreateNoteRequest: Encodable, Sendable { let label: String }
nonisolated struct ResolveCaseRequest: Encodable, Sendable { let resolution: String; let finalBalance: Money; let notes: String? }
nonisolated struct FPLEstimateRequest: Encodable, Sendable { let householdSize: Int; let annualIncome: Money; let state: String? }
nonisolated struct EmptyBody: Encodable, Sendable {}
