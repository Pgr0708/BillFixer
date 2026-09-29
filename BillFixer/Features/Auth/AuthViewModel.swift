import AuthenticationServices
import OSLog
import SwiftUI
import Observation

@MainActor
@Observable
final class AuthViewModel {
    enum Mode: String, CaseIterable, Identifiable { case signIn = "Sign In", register = "Create Account"; var id: String { rawValue } }

    var mode: Mode = .signIn
    var name = ""
    var email = ""
    var password = ""
    var errors: [String: String] = [:]
    var isWorking = false
    var shake = 0
    private var currentNonce: String?

    private let session: AppSession
    init(session: AppSession) { self.session = session }

    // MARK: Apple

    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Nonce.random()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Nonce.sha256(nonce)
    }

    func complete(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            Toast.error("Apple sign in failed", error.localizedDescription)
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken, let token = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                Toast.error("Apple sign in failed", "Missing identity token. Please try again.")
                return
            }
            let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
            let fullName = credential.fullName.map { PersonNameComponentsFormatter.localizedString(from: $0, style: .default) }?.trimmed
            isWorking = true
            defer { isWorking = false }
            do {
                let user = try await session.auth.signInWithApple(identityToken: token, authorizationCode: code, nonce: nonce,
                                                                  displayName: fullName?.isEmpty == false ? fullName : nil)
                await session.didSignIn(user)
                Toast.success("Welcome, \(user.firstName)!")
            } catch {
                AppLog.auth.error("Apple sign in failed")
                Toast.error(error)
            }
        }
    }

    // MARK: Email

    func submitEmail() async -> Bool {
        errors = [:]
        if let e = Validation.email(email) { errors["email"] = e }
        if mode == .register {
            if let e = Validation.newPassword(password) { errors["password"] = e }
        } else if password.isEmpty {
            errors["password"] = "Enter your password"
        }
        guard errors.isEmpty else { shake += 1; Haptics.error(); return false }

        isWorking = true
        defer { isWorking = false }
        do {
            let user = mode == .register
                ? try await session.auth.register(email: email.trimmed.lowercased(), password: password, displayName: name.trimmed.isEmpty ? nil : name.trimmed)
                : try await session.auth.login(email: email.trimmed.lowercased(), password: password)
            password = ""
            await session.didSignIn(user)
            Toast.success(mode == .register ? "Account created" : "Welcome back, \(user.firstName)!")
            return true
        } catch let error as APIError {
            if case let .validation(_, fields) = error, !fields.isEmpty {
                for (k, v) in fields { errors[k] = v.first }
            } else if case let .unauthorized(_, message) = error {
                errors["password"] = message
            } else if case let .conflict(_, message) = error {
                errors["email"] = message
            } else {
                Toast.error(error)
            }
            shake += 1
            Haptics.error()
            return false
        } catch {
            Toast.error(error)
            return false
        }
    }
}
