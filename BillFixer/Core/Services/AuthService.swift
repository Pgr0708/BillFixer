import Foundation

protocol AuthServicing {
    func signInWithApple(identityToken: String, authorizationCode: String?, nonce: String, displayName: String?) async throws -> User
    func register(email: String, password: String, displayName: String?) async throws -> User
    func login(email: String, password: String) async throws -> User
    func forgotPassword(email: String) async throws -> String?
    func resetPassword(email: String, code: String, newPassword: String) async throws -> User
    func me() async throws -> MeResponse
    func updateDisplayName(_ name: String) async throws -> User
    func logout() async
    func deleteAccount() async throws
    func hasSession() async -> Bool
}

struct AuthService: AuthServicing {
    var api: APIClient = .shared
    var tokens: TokenStore = .shared

    private func establish(_ session: AuthSession) async -> User {
        await tokens.save(access: session.accessToken, refresh: session.refreshToken)
        return session.user
    }

    func signInWithApple(identityToken: String, authorizationCode: String?, nonce: String, displayName: String?) async throws -> User {
        let body = AppleSignInRequest(identityToken: identityToken, authorizationCode: authorizationCode, nonce: nonce, displayName: displayName)
        return await establish(try await api.send(.post("auth/apple", body, auth: false)))
    }

    func register(email: String, password: String, displayName: String?) async throws -> User {
        let body = RegisterRequest(email: email, password: password, displayName: displayName)
        return await establish(try await api.send(.post("auth/register", body, auth: false)))
    }

    func login(email: String, password: String) async throws -> User {
        await establish(try await api.send(.post("auth/login", LoginRequest(email: email, password: password), auth: false)))
    }

    func forgotPassword(email: String) async throws -> String? {
        let r: MessageResponse = try await api.send(.post("auth/password/forgot", ForgotPasswordRequest(email: email), auth: false))
        return r.message
    }

    func resetPassword(email: String, code: String, newPassword: String) async throws -> User {
        let body = ResetPasswordRequest(email: email, code: code, newPassword: newPassword)
        return await establish(try await api.send(.post("auth/password/reset", body, auth: false)))
    }

    func me() async throws -> MeResponse { try await api.send(.get("me")) }

    func updateDisplayName(_ name: String) async throws -> User {
        let r: UserEnvelope = try await api.send(.patch("me", PatchMeRequest(displayName: name)))
        return r.user
    }

    /// Best effort: the local session is cleared even if the server can't be reached.
    func logout() async {
        if let refresh = await tokens.refreshToken() {
            try? await api.send(.delete("auth/session", RefreshRequest(refreshToken: refresh), auth: false))
        }
        await tokens.clear()
    }

    func deleteAccount() async throws {
        try await api.send(.delete("me"))
        await tokens.clear()
    }

    func hasSession() async -> Bool { await tokens.hasSession() }
}
