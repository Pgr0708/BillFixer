import SwiftUI

/// Board screen 17 — You're All Set (post-paywall).
struct AllSetView: View {
    let onStart: () -> Void
    let onClose: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Navy gradient background
            LinearGradient(
                colors: [Color(hex: 0x050F20), Color(hex: 0x0B2B5C), Color(hex: 0x0A3060)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            // Circle decorations
            Circle().fill(Color(hex: 0x22D3BB).opacity(0.10)).frame(width: 320).blur(radius: 50).offset(x: 140, y: -200)
            Circle().fill(Color(hex: 0x2E7DF6).opacity(0.07)).frame(width: 260).blur(radius: 40).offset(x: -130, y: 350)

            VStack(spacing: 28) {
                Spacer()

                // ── Big green success circle ──────────────────────────────
                ZStack {
                    Circle().fill(BFColor.green.opacity(0.06)).frame(width: 160, height: 160)
                    Circle().fill(BFColor.green.opacity(0.12)).frame(width: 130, height: 130)
                    Circle()
                        .fill(LinearGradient(colors: [Color(hex: 0x22C07A), Color(hex: 0x16A364)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 96, height: 96)
                        .shadow(color: BFColor.green.opacity(0.45), radius: 20, y: 6)
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .black))
                        .foregroundStyle(.white)
                }
                .scaleEffect(appeared ? 1 : 0.5)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.65), value: appeared)

                // ── Headline ──────────────────────────────────────────────
                VStack(spacing: 8) {
                    Text("You're All Set!")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Welcome to BillFixer Premium")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.12), value: appeared)

                // ── Circular benefit list ─────────────────────────────────
                VStack(spacing: 0) {
                    ForEach(Array([
                        ("crown.fill",            Color(hex: 0xFFC554), "Your subscription is active"),
                        ("lock.open.fill",         BFColor.green,        "All features unlocked"),
                        ("doc.viewfinder",          BFColor.blue,         "Start scanning your first bill"),
                    ].enumerated()), id: \.offset) { i, item in
                        HStack(spacing: 14) {
                            Circle()
                                .fill(item.1.opacity(0.18))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Image(systemName: item.0)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(item.1)
                                }
                            Text(item.2)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                            Spacer()
                            Circle()
                                .fill(BFColor.green.opacity(0.2))
                                .frame(width: 24, height: 24)
                                .overlay {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(BFColor.green)
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .opacity(appeared ? 1 : 0)
                        .offset(x: appeared ? 0 : -20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2 + Double(i) * 0.07), value: appeared)
                        if i < 2 { Divider().background(.white.opacity(0.1)).padding(.leading, 70) }
                    }
                }
                .background(.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
                .padding(.horizontal, 4)

                Spacer()

                // ── CTA button ────────────────────────────────────────────
                Button(action: onStart) {
                    HStack(spacing: 10) {
                        Circle().fill(.white.opacity(0.2)).frame(width: 30, height: 30)
                            .overlay { Image(systemName: "doc.viewfinder").font(.system(size: 13, weight: .bold)).foregroundStyle(.white) }
                        Text("Start Scanning")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity).frame(height: 58)
                    .background(LinearGradient(colors: [BFColor.teal, Color(hex: 0x00897B)], startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
                    .shadow(color: BFColor.teal.opacity(0.4), radius: 16, y: 6)
                }
                .buttonStyle(.pressable)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.42), value: appeared)

                Button("Maybe later", action: onClose)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeIn(duration: 0.3).delay(0.5), value: appeared)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .preferredColorScheme(.dark)
        .onAppear { withAnimation { appeared = true } }
    }
}
