import SwiftUI

/// Full-bleed painted backgrounds — a different scene per screen (no two screens share one).
/// Layers: soft gradient base → bright glow orbs → circle motifs (rings, discs, dot clusters) → bottom wave.
/// Everything is drawn in one Canvas pass (no blur filters), so it stays cheap while scrolling.
struct ScenicBackground: View {
    enum Scene: Int, CaseIterable {
        case home, cases, learn, settings, results, capture, rights, analysis, letter, auth, finding, success, script, assistance
    }
    let scene: Scene
    @Environment(\.colorScheme) private var scheme

    private struct Glow { let x: CGFloat; let y: CGFloat; let r: CGFloat; let color: UInt32 }
    /// Decorative circle: filled disc, outlined ring, or a small dot. Positions are fractions of the screen.
    private enum Motif { case disc(CGFloat, CGFloat, CGFloat, UInt32), ring(CGFloat, CGFloat, CGFloat, UInt32, CGFloat), dots(CGFloat, CGFloat, UInt32) }

    private var palette: (light: [UInt32], dark: [UInt32], glows: [Glow], motifs: [Motif]) {
        switch scene {
        case .home: ([0xE4EEFF, 0xF3F8FF, 0xEAFBF7], [0x0B1636, 0x0A1024, 0x0B1E2A],
            [Glow(x: 0.95, y: 0.0, r: 0.7, color: 0x4F8BFF), Glow(x: 0.0, y: 0.38, r: 0.55, color: 0x19D3B5), Glow(x: 0.8, y: 0.85, r: 0.5, color: 0x8B7BFF)],
            [.disc(0.88, 0.06, 0.2, 0x4F8BFF), .ring(0.88, 0.06, 0.3, 0x4F8BFF, 1.5), .ring(0.05, 0.42, 0.16, 0x19D3B5, 2), .dots(0.12, 0.2, 0x4F8BFF), .disc(0.95, 0.62, 0.08, 0xFFC554)])
        case .cases: ([0xDFF8F2, 0xF2FBFF, 0xEEF3FF], [0x07202A, 0x0A1024, 0x10183A],
            [Glow(x: 0.1, y: 0.0, r: 0.65, color: 0x19D3B5), Glow(x: 1.0, y: 0.45, r: 0.55, color: 0x4F8BFF), Glow(x: 0.2, y: 0.95, r: 0.45, color: 0x8B7BFF)],
            [.disc(0.1, 0.04, 0.18, 0x19D3B5), .ring(0.92, 0.28, 0.22, 0x4F8BFF, 2), .ring(0.92, 0.28, 0.14, 0x4F8BFF, 1), .dots(0.8, 0.12, 0x19D3B5), .disc(0.06, 0.7, 0.07, 0x8B7BFF)])
        case .learn: ([0xEEE8FF, 0xF8F4FF, 0xFFEEF4], [0x16113A, 0x0D0F2A, 0x1E1030],
            [Glow(x: 0.9, y: 0.02, r: 0.65, color: 0x9B8CFF), Glow(x: 0.0, y: 0.55, r: 0.55, color: 0xFF7AA8), Glow(x: 0.9, y: 0.9, r: 0.45, color: 0x4F8BFF)],
            [.disc(0.92, 0.05, 0.22, 0x9B8CFF), .ring(0.08, 0.3, 0.2, 0xFF7AA8, 2), .dots(0.75, 0.24, 0x9B8CFF), .ring(0.9, 0.7, 0.12, 0x4F8BFF, 1.5), .disc(0.12, 0.84, 0.06, 0xFFC554)])
        case .settings: ([0xE7EEFF, 0xF4F7FE, 0xF0F4FF], [0x0C1430, 0x0A1024, 0x0C1430],
            [Glow(x: 0.5, y: -0.05, r: 0.75, color: 0x7FA6FF), Glow(x: 0.0, y: 0.8, r: 0.45, color: 0x19D3B5)],
            [.ring(0.85, 0.08, 0.26, 0x7FA6FF, 2), .ring(0.85, 0.08, 0.17, 0x7FA6FF, 1), .disc(0.06, 0.55, 0.1, 0x19D3B5), .dots(0.2, 0.1, 0x7FA6FF)])
        case .results: ([0xE3EEFF, 0xFFF7E8, 0xFFF1E0], [0x0B1636, 0x1A1426, 0x241A10],
            [Glow(x: 0.1, y: 0.05, r: 0.6, color: 0x4F8BFF), Glow(x: 0.95, y: 0.45, r: 0.6, color: 0xFFB93B), Glow(x: 0.2, y: 0.9, r: 0.4, color: 0xFF7A7A)],
            [.disc(0.9, 0.1, 0.16, 0xFFB93B), .ring(0.9, 0.1, 0.26, 0xFFB93B, 2), .ring(0.1, 0.6, 0.15, 0x4F8BFF, 1.5), .dots(0.15, 0.08, 0x4F8BFF), .disc(0.85, 0.82, 0.07, 0xFF7A7A)])
        case .capture: ([0xE6F4FF, 0xEAFBF7, 0xDDF7F0], [0x0A1A33, 0x0A1024, 0x082622],
            [Glow(x: 0.95, y: 0.1, r: 0.6, color: 0x19D3B5), Glow(x: 0.0, y: 0.7, r: 0.55, color: 0x4F8BFF)],
            [.ring(0.9, 0.12, 0.2, 0x19D3B5, 2), .disc(0.9, 0.12, 0.1, 0x19D3B5), .ring(0.08, 0.78, 0.22, 0x4F8BFF, 1.5), .dots(0.72, 0.4, 0x19D3B5), .disc(0.1, 0.35, 0.06, 0x8B7BFF)])
        case .rights: ([0xEDE7FF, 0xE8F0FF, 0xF5F0FF], [0x150F3A, 0x0B1636, 0x0A1024],
            [Glow(x: 0.0, y: 0.0, r: 0.7, color: 0x8B7BFF), Glow(x: 1.0, y: 0.55, r: 0.55, color: 0x4F8BFF)],
            [.disc(0.08, 0.06, 0.2, 0x8B7BFF), .ring(0.08, 0.06, 0.32, 0x8B7BFF, 1.5), .ring(0.94, 0.5, 0.16, 0x4F8BFF, 2), .dots(0.8, 0.15, 0x8B7BFF), .disc(0.9, 0.86, 0.08, 0xFFC554)])
        case .analysis: ([0xDEEAFF, 0xEEF6FF, 0xDFF8F2], [0x08183A, 0x0A1024, 0x07242A],
            [Glow(x: 0.5, y: 0.08, r: 0.75, color: 0x4F8BFF), Glow(x: 0.9, y: 0.8, r: 0.45, color: 0x19D3B5), Glow(x: 0.0, y: 0.5, r: 0.4, color: 0x8B7BFF)],
            [.ring(0.5, 0.1, 0.34, 0x4F8BFF, 1.5), .ring(0.5, 0.1, 0.24, 0x4F8BFF, 1), .disc(0.9, 0.82, 0.12, 0x19D3B5), .dots(0.1, 0.4, 0x8B7BFF)])
        case .letter: ([0xFFF2DA, 0xFFF9EF, 0xEEF3FF], [0x241A0C, 0x14121E, 0x0A1024],
            [Glow(x: 0.9, y: 0.0, r: 0.6, color: 0xFFB93B), Glow(x: 0.0, y: 0.6, r: 0.45, color: 0x7FA6FF)],
            [.disc(0.9, 0.04, 0.18, 0xFFB93B), .ring(0.9, 0.04, 0.28, 0xFFB93B, 1.5), .ring(0.06, 0.62, 0.14, 0x7FA6FF, 2), .dots(0.2, 0.12, 0xFFB93B)])
        case .auth: ([0xDCEAFF, 0xEDF6FF, 0xFFFFFF], [0x0B1B45, 0x0A1024, 0x0A1024],
            [Glow(x: 0.1, y: 0.1, r: 0.7, color: 0x4F8BFF), Glow(x: 1.0, y: 0.3, r: 0.5, color: 0x19D3B5), Glow(x: 0.5, y: 1.0, r: 0.5, color: 0x8B7BFF)],
            [.ring(0.5, 0.2, 0.3, 0x4F8BFF, 1.5), .ring(0.5, 0.2, 0.42, 0x4F8BFF, 1), .disc(0.1, 0.1, 0.12, 0x19D3B5), .disc(0.92, 0.36, 0.06, 0xFFC554), .dots(0.82, 0.08, 0x4F8BFF)])
        case .finding: ([0xFFE5E5, 0xFFF3EA, 0xF6F8FE], [0x2A1020, 0x1A1024, 0x0A1024],
            [Glow(x: 1.0, y: 0.0, r: 0.6, color: 0xFF6B6B), Glow(x: 0.0, y: 0.5, r: 0.45, color: 0xFFB93B)],
            [.disc(0.92, 0.05, 0.16, 0xFF6B6B), .ring(0.92, 0.05, 0.26, 0xFF6B6B, 1.5), .ring(0.05, 0.52, 0.13, 0xFFB93B, 2), .dots(0.8, 0.3, 0xFF6B6B)])
        case .success: ([0xD9F9E9, 0xEFFFF8, 0xE6FFF9], [0x07261C, 0x0A1024, 0x07242A],
            [Glow(x: 0.5, y: 0.2, r: 0.8, color: 0x3BDC93), Glow(x: 0.0, y: 0.9, r: 0.4, color: 0x19D3B5)],
            [.ring(0.5, 0.28, 0.38, 0x3BDC93, 1.5), .ring(0.5, 0.28, 0.5, 0x3BDC93, 1), .disc(0.1, 0.1, 0.08, 0xFFC554), .dots(0.85, 0.12, 0x19D3B5)])
        case .script: ([0xDDF3FF, 0xF2F6FF, 0xF1ECFF], [0x08223A, 0x0A1024, 0x16123A],
            [Glow(x: 0.0, y: 0.05, r: 0.6, color: 0x38BDF8), Glow(x: 1.0, y: 0.5, r: 0.55, color: 0x9B8CFF)],
            [.disc(0.06, 0.08, 0.16, 0x38BDF8), .ring(0.06, 0.08, 0.26, 0x38BDF8, 1.5), .ring(0.95, 0.55, 0.16, 0x9B8CFF, 2), .dots(0.85, 0.2, 0x38BDF8)])
        case .assistance: ([0xDDF8E9, 0xF3FCF6, 0xFFF4DE], [0x07261C, 0x0A1024, 0x241A0C],
            [Glow(x: 1.0, y: 0.05, r: 0.6, color: 0x3BDC93), Glow(x: 0.0, y: 0.55, r: 0.5, color: 0xFFB93B)],
            [.disc(0.92, 0.06, 0.18, 0x3BDC93), .ring(0.92, 0.06, 0.28, 0x3BDC93, 1.5), .ring(0.06, 0.58, 0.15, 0xFFB93B, 2), .dots(0.2, 0.15, 0x3BDC93), .disc(0.88, 0.8, 0.07, 0x4F8BFF)])
        }
    }

    var body: some View {
        let dark = scheme == .dark
        let p = palette
        let glowAlpha = dark ? 0.42 : 0.5
        let discAlpha = dark ? 0.22 : 0.2
        let ringAlpha = dark ? 0.35 : 0.3
        ZStack {
            LinearGradient(colors: (dark ? p.dark : p.light).map { Color(hex: $0) }, startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                let d = max(size.width, size.height)
                func circle(_ c: CGPoint, _ r: CGFloat) -> Path { Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)) }

                for g in p.glows {
                    let c = CGPoint(x: g.x * size.width, y: g.y * size.height), r = g.r * d
                    ctx.fill(circle(c, r), with: .radialGradient(Gradient(colors: [Color(hex: g.color, opacity: glowAlpha), Color(hex: g.color, opacity: 0)]),
                                                                 center: c, startRadius: 0, endRadius: r))
                }
                for m in p.motifs {
                    switch m {
                    case let .disc(x, y, r, color):
                        let c = CGPoint(x: x * size.width, y: y * size.height), rr = r * size.width
                        ctx.fill(circle(c, rr), with: .linearGradient(Gradient(colors: [Color(hex: color, opacity: discAlpha * 1.4), Color(hex: color, opacity: discAlpha * 0.3)]),
                                                                    startPoint: CGPoint(x: c.x - rr, y: c.y - rr), endPoint: CGPoint(x: c.x + rr, y: c.y + rr)))
                    case let .ring(x, y, r, color, width):
                        ctx.stroke(circle(CGPoint(x: x * size.width, y: y * size.height), r * size.width),
                                   with: .color(Color(hex: color, opacity: ringAlpha)), lineWidth: width)
                    case let .dots(x, y, color):
                        for i in 0..<3 { for j in 0..<3 {
                            let c = CGPoint(x: x * size.width + CGFloat(i) * 12, y: y * size.height + CGFloat(j) * 12)
                            ctx.fill(circle(c, 2.2), with: .color(Color(hex: color, opacity: ringAlpha * 1.4)))
                        } }
                    }
                }
                var wave = Path()
                wave.move(to: CGPoint(x: 0, y: size.height * 0.84))
                wave.addCurve(to: CGPoint(x: size.width, y: size.height * 0.8),
                              control1: CGPoint(x: size.width * 0.35, y: size.height * 0.76),
                              control2: CGPoint(x: size.width * 0.65, y: size.height * 0.9))
                wave.addLine(to: CGPoint(x: size.width, y: size.height))
                wave.addLine(to: CGPoint(x: 0, y: size.height))
                ctx.fill(wave, with: .color(.white.opacity(dark ? 0.025 : 0.4)))
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
