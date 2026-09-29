import Foundation

protocol ReferenceServicing {
    func rights() async throws -> [RightInfo]
    func fplEstimate(householdSize: Int, annualIncome: Money, state: String?) async throws -> FPLEstimate
    func searchProviders(_ query: String, state: String?) async throws -> [Provider]
    func financialAssistance(_ providerId: String) async throws -> FinancialAssistanceInfo
}

struct ReferenceService: ReferenceServicing {
    var api: APIClient = .shared

    func rights() async throws -> [RightInfo] {
        let r: RightsResponse = try await api.send(.get("reference/rights"))
        return r.rights
    }

    func fplEstimate(householdSize: Int, annualIncome: Money, state: String?) async throws -> FPLEstimate {
        let body = FPLEstimateRequest(householdSize: householdSize, annualIncome: annualIncome, state: state?.isEmpty == true ? nil : state?.uppercased())
        return try await api.send(.post("reference/fpl/estimate", body))
    }

    func searchProviders(_ query: String, state: String?) async throws -> [Provider] {
        var items = [URLQueryItem(name: "q", value: query)]
        if let state, !state.isEmpty { items.append(URLQueryItem(name: "state", value: state.uppercased())) }
        let r: ProviderSearchResponse = try await api.send(.get("providers/search", query: items))
        return r.results
    }

    func financialAssistance(_ providerId: String) async throws -> FinancialAssistanceInfo {
        try await api.send(.get("providers/\(providerId)/financial-assistance"))
    }
}
