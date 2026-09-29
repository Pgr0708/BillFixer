import Foundation

protocol ReferenceServicing {
    func rights() async throws -> [RightInfo]
    func fplEstimate(householdSize: Int, annualIncome: Money, state: String?) async throws -> FPLEstimate
    func searchProviders(_ query: String, state: String?) async throws -> [Provider]
    func financialAssistance(_ providerId: String) async throws -> FinancialAssistanceInfo
    func financialProfile() async throws -> FinancialProfileResponse
    /// Saves the profile and re-checks the user's open cases. `recheckedCases` says how many.
    func saveFinancialProfile(householdSize: Int, annualIncome: Money, state: String?) async throws -> FinancialProfileResponse
    func deleteFinancialProfile() async throws
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

    func financialProfile() async throws -> FinancialProfileResponse { try await api.send(.get("me/financial-profile")) }

    func saveFinancialProfile(householdSize: Int, annualIncome: Money, state: String?) async throws -> FinancialProfileResponse {
        let body = FinancialProfileRequest(householdSize: householdSize, annualIncome: annualIncome.magnitude,
                                           state: (state?.isEmpty ?? true) ? nil : state?.uppercased())
        return try await api.send(Endpoint(method: .put, path: "me/financial-profile", body: try JSONCoding.encoder().encode(body)))
    }

    func deleteFinancialProfile() async throws { try await api.send(.delete("me/financial-profile")) }
}
