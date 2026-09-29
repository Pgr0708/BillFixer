import SwiftUI

/// Board screen 17.
struct AllSetView: View {
    let onStart: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            SuccessBurst()
            Text("You’re All Set!").font(BFFont.warm(32)).foregroundStyle(BFColor.text1)
            Text("Welcome to BillFixer Premium").font(BFFont.body).foregroundStyle(BFColor.text2)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(["Your subscription is active", "All features unlocked", "Start scanning your first bill"].enumerated()), id: \.offset) { i, t in
                    Label(t, systemImage: "checkmark.circle.fill").font(.system(size: 16, weight: .medium)).foregroundStyle(BFColor.text1)
                        .symbolRenderingMode(.multicolor)
                        .staggeredAppear(i + 3)
                }
            }
            .cardStyle(padding: 18, radius: 20)
            .padding(.horizontal, 8)
            Spacer()
            BFButton(title: "Start Scanning", icon: "doc.viewfinder", kind: .navy, action: onStart)
            Button("Maybe later", action: onClose).font(BFFont.label(14)).foregroundStyle(BFColor.text2)
        }
        .padding(BFSpacing.screen)
        .scenicBackground(.success)
    }
}
