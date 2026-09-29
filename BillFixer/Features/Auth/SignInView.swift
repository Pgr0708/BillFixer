import AuthenticationServices
import SwiftUI

/// Board screen 05.
struct SignInView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.colorScheme) private var scheme
    @State private var model: AuthViewModel?
    @State private var showEmail = false
    @State private var link: WebLink?
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            LogoMark(size: 76).staggeredAppear(0)
            Text("BillFixer").font(BFFont.display(34)).foregroundStyle(scheme == .dark ? Color.white : BFColor.navy)
                .padding(.top, 14).staggeredAppear(1)
            Text("Your medical bill, decoded.").font(.system(size: 16, weight: .medium)).foregroundStyle(BFColor.text2).padding(.top, 4).staggeredAppear(2)
            Spacer(minLength: 12)
            HospitalScene().staggeredAppear(3)
            Spacer(minLength: 12)

            VStack(spacing: 12) {
                if let model {
                    SignInWithAppleButton(.continue, onRequest: model.prepare) { result in
                        Task { await model.complete(result) }
                    }
                    .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
                    .frame(height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .disabled(model.isWorking)
                    .accessibilityLabel("Continue with Apple")
                }
                BFButton(title: "Continue with Email", icon: "envelope.fill", kind: .outline) { showEmail = true }
            }
            .padding(.horizontal, 24)
            .staggeredAppear(4)

            legal.padding(.top, 16).padding(.bottom, 10)
        }
        .scenicBackground(.auth)
        .loadingOverlay(model?.isWorking == true, "Signing you in…")
        .sheet(isPresented: $showEmail) {
            if let model { EmailAuthSheet(model: model) }
        }
        .webSheet($link)
        .onAppear { if model == nil { model = AuthViewModel(session: session) } }
    }

    private var legal: some View {
        VStack(spacing: 2) {
            Text("By continuing, you agree to our").foregroundStyle(BFColor.text3)
            HStack(spacing: 4) {
                Button("Terms of Service") { link = .terms }
                Text("and").foregroundStyle(BFColor.text3)
                Button("Privacy Policy") { link = .privacy }
            }
            .foregroundStyle(BFColor.blue)
        }
        .font(.system(size: 12, weight: .medium))
        .multilineTextAlignment(.center)
    }
}
