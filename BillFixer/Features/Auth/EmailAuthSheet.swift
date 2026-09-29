import SwiftUI

struct EmailAuthSheet: View {
    @Bindable var model: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showForgot = false
    @FocusState private var focus: Field?
    private enum Field { case name, email, password, confirm }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Mode", selection: $model.mode) {
                        ForEach(AuthViewModel.Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: model.mode) { _, _ in model.errors = [:]; model.confirmPassword = ""; Haptics.selection() }

                    Text(model.mode == .signIn ? "Welcome back" : "Create your account")
                        .font(BFFont.title(26)).foregroundStyle(BFColor.text1)

                    if model.mode == .register {
                        BFTextField(label: "Name (optional)", text: $model.name, prompt: "Alex Johnson", icon: "person",
                                    contentType: .name, error: model.errors["displayName"], autocapitalization: .words)
                            .focused($focus, equals: .name)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    BFTextField(label: "Email", text: $model.email, prompt: "you@example.com", icon: "envelope",
                                keyboard: .emailAddress, contentType: .emailAddress, error: model.errors["email"], autocapitalization: .never)
                        .focused($focus, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focus = .password }
                    BFTextField(label: "Password", text: $model.password, prompt: model.mode == .register ? "At least 8 characters" : "Your password",
                                icon: "lock", contentType: model.mode == .register ? .newPassword : .password, isSecure: true,
                                error: model.errors["password"], autocapitalization: .never)
                        .focused($focus, equals: .password)
                        .submitLabel(model.mode == .register ? .next : .go)
                        .onSubmit { if model.mode == .register { focus = .confirm } else { submit() } }

                    if model.mode == .register {
                        Group {
                            PasswordChecklist(password: model.password, email: model.email)
                            BFTextField(label: "Confirm password", text: $model.confirmPassword, prompt: "Type it again", icon: "lock.rotation",
                                        contentType: .newPassword, isSecure: true, error: model.errors["confirmPassword"], autocapitalization: .never)
                                .focused($focus, equals: .confirm)
                                .submitLabel(.go)
                                .onSubmit(submit)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if model.mode == .signIn {
                        Button("Forgot password?") { showForgot = true }
                            .font(BFFont.label(14)).foregroundStyle(BFColor.blue)
                    }

                    BFButton(title: model.mode == .signIn ? "Sign In" : "Create Account", kind: .navy, isLoading: model.isWorking, action: submit)
                        .shake(model.shake)
                        .padding(.top, 4)

                    Label("Your bills stay private. We never sell your data.", systemImage: "lock.shield.fill")
                        .font(.system(size: 13)).foregroundStyle(BFColor.text3)
                }
                .padding(24)
                .animation(BFMotion.gentle, value: model.mode)
                .animation(BFMotion.quick, value: model.errors)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(BFColor.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(BFColor.text3) }
                        .accessibilityLabel("Close")
                }
            }
            .sheet(isPresented: $showForgot) { ForgotPasswordSheet(email: model.email) }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
        .onAppear { focus = .email }
    }

    private func submit() {
        focus = nil
        Task { if await model.submitEmail() { dismiss() } }
    }
}

/// Live password rules; each turns green as it's met.
struct PasswordChecklist: View {
    let password: String
    let email: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Validation.passwordRules(password, email: email), id: \.label) { rule in
                Label(rule.label, systemImage: rule.met ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(rule.met ? BFColor.green : BFColor.text3)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityValue(rule.met ? "done" : "not yet")
            }
        }
        .animation(BFMotion.quick, value: password)
    }
}

struct ForgotPasswordSheet: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State var email: String
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var step = 0
    @State private var isWorking = false
    @State private var errors: [String: String] = [:]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                StepIndicator(steps: ["Email", "Reset"], current: step)
                Text(step == 0 ? "Reset your password" : "Check your email").font(BFFont.title(24)).foregroundStyle(BFColor.text1)
                Text(step == 0 ? "We’ll email you a 6-digit code." : "Enter the code we sent to \(email) and choose a new password.")
                    .font(BFFont.subheadline).foregroundStyle(BFColor.text2)
                if step == 0 {
                    BFTextField(label: "Email", text: $email, icon: "envelope", keyboard: .emailAddress, contentType: .emailAddress,
                                error: errors["email"], autocapitalization: .never)
                } else {
                    BFTextField(label: "6-digit code", text: $code, icon: "number", keyboard: .numberPad, contentType: .oneTimeCode, error: errors["code"])
                    BFTextField(label: "New password", text: $newPassword, icon: "lock", contentType: .newPassword, isSecure: true,
                                error: errors["newPassword"], autocapitalization: .never)
                    PasswordChecklist(password: newPassword, email: email)
                    BFTextField(label: "Confirm new password", text: $confirmPassword, icon: "lock.rotation", contentType: .newPassword, isSecure: true,
                                error: errors["confirmPassword"], autocapitalization: .never)
                }
                BFButton(title: step == 0 ? "Send Code" : "Reset Password", kind: .navy, isLoading: isWorking) { Task { await next() } }
                Spacer()
            }
            .padding(24)
            .animation(BFMotion.gentle, value: step)
            .animation(BFMotion.quick, value: errors)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    private func next() async {
        errors = [:]
        if step == 0 {
            if let e = Validation.email(email) { errors["email"] = e; Haptics.error(); return }
            isWorking = true
            defer { isWorking = false }
            do {
                let message = try await session.auth.forgotPassword(email: email.trimmed.lowercased())
                Toast.info("Code sent", message)
                step = 1
            } catch { Toast.error(error) }
        } else {
            if let e = Validation.resetCode(code) { errors["code"] = e }
            if let e = Validation.newPassword(newPassword, email: email) { errors["newPassword"] = e }
            if let e = Validation.confirm(newPassword, confirmPassword) { errors["confirmPassword"] = e }
            guard errors.isEmpty else { Haptics.error(); return }
            isWorking = true
            defer { isWorking = false }
            do {
                let user = try await session.auth.resetPassword(email: email.trimmed.lowercased(), code: code, newPassword: newPassword)
                await session.didSignIn(user)
                Toast.success("Password updated", "You’re signed in.")
                dismiss()
            } catch let error as APIError {
                if case let .validation(_, fields) = error, !fields.isEmpty { for (k, v) in fields { errors[k] = v.first } } else { Toast.error(error) }
            } catch { Toast.error(error) }
        }
    }
}
