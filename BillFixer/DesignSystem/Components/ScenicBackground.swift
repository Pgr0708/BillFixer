import SwiftUI

/// Full-bleed painted backgrounds — a different scene per screen (design direction: no two screens share one).
/// Drawn with Canvas radial gradients (no blur passes), so they're cheap to render and scroll over.
struct ScenicBackground: View {
    enum Scene {
        case home, cases, learn, settings, results, capture, rights, analysis, letter, auth, finding, success, script, assistance
    }
    let scene: Scene
    @Environment(\.colorScheme) private var scheme

    private struct Blob { let x: CGFloat; let y: CGFloat; let r: CGFloat; let color: Color }

    private var base: [Color] {
        let dark = scheme == .dark
        switch scene {
        case .home: return dark ? [Color(hex: 0x0D1117), Color(hex: 0x0F1726)] : [Color(hex: 0xEEF4FF), Color(hex: 0xF7F9FD)]
        case .cases: return dark ? [Color(hex: 0x0D1117), Color(hex: 0x111A24)] : [Color(hex: 0xF0FAF8), Color(hex: 0xF7F9FD)]
        case .learn: return dark ? [Color(hex: 0x100F1C), Color(hex: 0x0D1117)] : [Color(hex: 0xF4F1FF), Color(hex: 0xF8F9FE)]
        case .settings: return dark ? [Color(hex: 0x0D1117), Color(hex: 0x0D1117)] : [Color(hex: 0xF3F6FB), Color(hex: 0xF7F9FD)]
        case .results: return dark ? [Color(hex: 0x0B1322), Color(hex: 0x0D1117)] : [Color(hex: 0xEAF3FF), Color(hex: 0xFFF8EC)]
        case .capture: return dark ? [Color(hex: 0x0D1117), Color(hex: 0x0E1A1E)] : [Color(hex: 0xF5FAFF), Color(hex: 0xEFFAF7)]
        case .rights: return dark ? [Color(hex: 0x0E1220), Color(hex: 0x0D1117)] : [Color(hex: 0xF3F0FF), Color(hex: 0xEEF6FF)]
        case .analysis: return dark ? [Color(hex: 0x0A1628), Color(hex: 0x0D1117)] : [Color(hex: 0xE9F2FF), Color(hex: 0xF1FBF9)]
        case .letter: return dark ? [Color(hex: 0x14120E), Color(hex: 0x0D1117)] : [Color(hex: 0xFFF9EF), Color(hex: 0xF7F9FD)]
        case .auth: return dark ? [Color(hex: 0x0B1B35), Color(hex: 0x0D1117)] : [Color(hex: 0xE8F1FE), Color(hex: 0xFFFFFF)]
        case .finding: return dark ? [Color(hex: 0x1A1012), Color(hex: 0x0D1117)] : [Color(hex: 0xFFF3F2), Color(hex: 0xF7F9FD)]
        case .success: return dark ? [Color(hex: 0x0C1C16), Color(hex: 0x0D1117)] : [Color(hex: 0xE9FBF2), Color(hex: 0xF4FFFB)]
        case .script: return dark ? [Color(hex: 0x0D1622), Color(hex: 0x0D1117)] : [Color(hex: 0xEFF9FF), Color(hex: 0xF7F4FF)]
        case .assistance: return dark ? [Color(hex: 0x0F1A14), Color(hex: 0x0D1117)] : [Color(hex: 0xF0FBF4), Color(hex: 0xFFF9EE)]
        }
    }

    private var blobs: [Blob] {
        switch scene {
        case .home: [Blob(x: 0.9, y: 0.02, r: 0.7, color: Color(hex: 0x5B9BFF)), Blob(x: 0.0, y: 0.35, r: 0.55, color: Color(hex: 0x22D3BB))]
        case .cases: [Blob(x: 0.1, y: 0.0, r: 0.65, color: Color(hex: 0x22D3BB)), Blob(x: 1.0, y: 0.5, r: 0.5, color: Color(hex: 0x5B9BFF))]
        case .learn: [Blob(x: 0.85, y: 0.05, r: 0.65, color: Color(hex: 0x9B8CFF)), Blob(x: 0.05, y: 0.6, r: 0.5, color: Color(hex: 0xFF8FB1))]
        case .settings: [Blob(x: 0.5, y: -0.05, r: 0.7, color: Color(hex: 0x8FB5FF))]
        case .results: [Blob(x: 0.1, y: 0.05, r: 0.6, color: Color(hex: 0x5B9BFF)), Blob(x: 0.95, y: 0.45, r: 0.55, color: Color(hex: 0xFFC554))]
        case .capture: [Blob(x: 0.95, y: 0.1, r: 0.6, color: Color(hex: 0x22D3BB)), Blob(x: 0.0, y: 0.7, r: 0.5, color: Color(hex: 0x5B9BFF))]
        case .rights: [Blob(x: 0.0, y: 0.0, r: 0.7, color: Color(hex: 0x7C6BFF)), Blob(x: 1.0, y: 0.55, r: 0.5, color: Color(hex: 0x2E7DF6))]
        case .analysis: [Blob(x: 0.5, y: 0.1, r: 0.75, color: Color(hex: 0x2E7DF6)), Blob(x: 0.9, y: 0.8, r: 0.45, color: Color(hex: 0x22D3BB))]
        case .letter: [Blob(x: 0.9, y: 0.0, r: 0.6, color: Color(hex: 0xFFC554)), Blob(x: 0.0, y: 0.6, r: 0.45, color: Color(hex: 0x8FB5FF))]
        case .auth: [Blob(x: 0.1, y: 0.1, r: 0.7, color: Color(hex: 0x5B9BFF)), Blob(x: 1.0, y: 0.3, r: 0.5, color: Color(hex: 0x22D3BB))]
        case .finding: [Blob(x: 1.0, y: 0.0, r: 0.6, color: Color(hex: 0xF87171)), Blob(x: 0.0, y: 0.5, r: 0.45, color: Color(hex: 0xFFC554))]
        case .success: [Blob(x: 0.5, y: 0.2, r: 0.8, color: Color(hex: 0x3BDC93)), Blob(x: 0.0, y: 0.9, r: 0.4, color: Color(hex: 0x22D3BB))]
        case .script: [Blob(x: 0.0, y: 0.05, r: 0.6, color: Color(hex: 0x38BDF8)), Blob(x: 1.0, y: 0.5, r: 0.5, color: Color(hex: 0x9B8CFF))]
        case .assistance: [Blob(x: 1.0, y: 0.05, r: 0.6, color: Color(hex: 0x3BDC93)), Blob(x: 0.0, y: 0.55, r: 0.5, color: Color(hex: 0xFFC554))]
        }
    }

    var body: some View {
        let intensity = scheme == .dark ? 0.22 : 0.34
        ZStack {
            LinearGradient(colors: base, startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                let d = max(size.width, size.height)
                for b in blobs {
                    let center = CGPoint(x: b.x * size.width, y: b.y * size.height)
                    let radius = b.r * d
                    ctx.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                             with: .radialGradient(Gradient(colors: [b.color.opacity(intensity), b.color.opacity(0)]),
                                                   center: center, startRadius: 0, endRadius: radius))
                }
                // A soft wave near the bottom ties the scene together.
                var wave = Path()
                wave.move(to: CGPoint(x: 0, y: size.height * 0.82))
                wave.addCurve(to: CGPoint(x: size.width, y: size.height * 0.78),
                              control1: CGPoint(x: size.width * 0.35, y: size.height * 0.74),
                              control2: CGPoint(x: size.width * 0.65, y: size.height * 0.88))
                wave.addLine(to: CGPoint(x: size.width, y: size.height))
                wave.addLine(to: CGPoint(x: 0, y: size.height))
                ctx.fill(wave, with: .color((scheme == .dark ? Color.white : Color.white).opacity(scheme == .dark ? 0.015 : 0.35)))
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

extension View {
    func scenicBackground(_ scene: ScenicBackground.Scene) -> some View {
        background(ScenicBackground(scene: scene))
    }
}
