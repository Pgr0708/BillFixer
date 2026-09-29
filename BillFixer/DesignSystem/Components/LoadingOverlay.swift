import Lottie
import SwiftUI

/// Full-screen blocking loader for short operations (submitting a case, deleting an account).
struct LoadingOverlay: View {
    var message: String = "Please wait…"

    var body: some View {
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea()
            VStack(spacing: 10) {
                LottieView(animation: .named("Loading"))
                    .playing(loopMode: .loop)
                    .frame(width: 110, height: 110)
                Text(message).font(BFFont.label(15)).foregroundStyle(BFColor.text1).multilineTextAlignment(.center)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .bfShadow(.float)
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

extension View {
    func loadingOverlay(_ isPresented: Bool, _ message: String = "Please wait…") -> some View {
        overlay { if isPresented { LoadingOverlay(message: message) } }
            .animation(BFMotion.standard, value: isPresented)
    }
}
