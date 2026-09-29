import SwiftUI

/// Brand mark: the real app icon (Assets › AppLogo, a copy of AppIcon — iOS can't load the AppIcon set in code),
/// with the iOS icon corner shape. `tile` adds the floating shadow used on hero screens.
struct LogoMark: View {
    var size: CGFloat = 72
    var tile = true

    var body: some View {
        Image("AppLogo")
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous).strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
            .shadow(color: .black.opacity(tile ? 0.2 : 0.08), radius: tile ? size * 0.18 : size * 0.06, y: tile ? size * 0.08 : size * 0.02)
            .accessibilityHidden(true)
    }
}

struct DocumentShape: Shape {
    func path(in r: CGRect) -> Path {
        let fold = r.width * 0.3
        var p = Path()
        p.move(to: CGPoint(x: r.minX + 6, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - fold, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + fold))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 6))
        p.addQuadCurve(to: CGPoint(x: r.maxX - 6, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + 6, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - 6), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + 6))
        p.addQuadCurve(to: CGPoint(x: r.minX + 6, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        p.closeSubpath()
        return p
    }
}

/// Floating badge used around illustrations (camera, coin, warning, mail…).
struct FloatingBadge: View {
    let symbol: String
    var tint: Color = BFColor.blue
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(BFColor.surface, in: Circle())
            .overlay(Circle().strokeBorder(tint.opacity(0.3), lineWidth: 1.5))
            .bfShadow(.card)
            .accessibilityHidden(true)
    }
}

/// "No Cases Yet" folder.
struct FolderIllustration: View {
    var body: some View {
        ZStack {
            Circle().fill(BFColor.blueSoft).frame(width: 190, height: 190)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: 0xFFC554)).frame(width: 150, height: 104).offset(y: 14)
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: 0xFFC554)).frame(width: 64, height: 24).offset(x: -43, y: 2)
                DocumentShape().fill(.white).frame(width: 96, height: 90).offset(y: -4).bfShadow(.card)
                    .overlay(alignment: .top) {
                        VStack(spacing: 6) { ForEach(0..<3, id: \.self) { i in Capsule().fill(BFColor.line).frame(width: [60, 48, 54][i], height: 6) } }
                            .padding(.top, 14)
                    }
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0xFFD27A), Color(hex: 0xF5A623)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 158, height: 82).offset(y: 44)
            }
            .offset(y: -6)
            Image(systemName: "sparkle").font(.system(size: 22)).foregroundStyle(BFColor.teal).offset(x: 86, y: -70)
            Image(systemName: "sparkle").font(.system(size: 14)).foregroundStyle(BFColor.blue).offset(x: -90, y: -40)
        }
        .frame(width: 220, height: 210)
        .accessibilityHidden(true)
    }
}

/// Green check burst for success moments; rings pulse out once.
struct SuccessBurst: View {
    @State private var pop = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle().stroke(BFColor.green.opacity(0.25 - Double(i) * 0.07), lineWidth: 2)
                    .frame(width: 120 + CGFloat(i) * 44, height: 120 + CGFloat(i) * 44)
                    .scaleEffect(pop ? 1 : 0.6)
                    .opacity(pop ? 1 : 0)
            }
            ForEach(0..<8, id: \.self) { i in
                Capsule().fill(i.isMultiple(of: 2) ? BFColor.teal : BFColor.amber)
                    .frame(width: 5, height: 14)
                    .offset(y: pop ? -104 : -60)
                    .rotationEffect(.degrees(Double(i) * 45))
                    .opacity(pop ? 1 : 0)
            }
            Circle().fill(BFGradient.green).frame(width: 110, height: 110)
                .bfShadow(BFShadow(color: BFColor.green.opacity(0.4), radius: 22, y: 10))
                .overlay(Image(systemName: "checkmark").font(.system(size: 48, weight: .heavy)).foregroundStyle(.white))
                .scaleEffect(pop ? 1 : 0.4)
        }
        .frame(width: 240, height: 240)
        .onAppear {
            Haptics.success()
            if reduceMotion { pop = true } else { withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) { pop = true } }
        }
        .accessibilityHidden(true)
    }
}

/// Sign-in hero: stylized hospital with a cross, clouds and trees.
struct HospitalScene: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Ellipse().fill(BFColor.tealSoft).frame(width: 300, height: 60).offset(y: 18)
            HStack(alignment: .bottom, spacing: 0) {
                building(width: 70, height: 110, color: Color(hex: 0xB9D3FF))
                ZStack(alignment: .top) {
                    building(width: 120, height: 170, color: .white)
                    RoundedRectangle(cornerRadius: 10).fill(BFColor.red.opacity(0.9)).frame(width: 36, height: 36)
                        .overlay(Image(systemName: "cross.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(.white))
                        .offset(y: 16)
                }
                building(width: 80, height: 130, color: Color(hex: 0xD4E5FF))
            }
            HStack { tree; Spacer(); tree }.frame(width: 300)
            Image(systemName: "cloud.fill").font(.system(size: 36)).foregroundStyle(.white).offset(x: -110, y: -170).floating(amplitude: 4)
            Image(systemName: "cloud.fill").font(.system(size: 26)).foregroundStyle(.white.opacity(0.9)).offset(x: 120, y: -150).floating(amplitude: 3, duration: 4)
        }
        .frame(height: 220)
        .accessibilityHidden(true)
    }

    private func building(width: CGFloat, height: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(color)
            .frame(width: width, height: height)
            .overlay(alignment: .center) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(12), spacing: 8), count: max(Int(width / 26), 2)), spacing: 10) {
                    ForEach(0..<(max(Int(width / 26), 2) * max(Int(height / 30), 2)), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x8FB5FF).opacity(0.6)).frame(width: 12, height: 12)
                    }
                }
                .padding(.top, 50)
            }
            .bfShadow(.subtle)
    }

    private var tree: some View {
        VStack(spacing: -4) {
            Circle().fill(BFColor.teal.opacity(0.85)).frame(width: 34, height: 34)
            Rectangle().fill(Color(hex: 0x8A6A4A)).frame(width: 5, height: 18)
        }
    }
}

struct CrownBadge: View {
    var body: some View {
        ZStack {
            Circle().fill(BFGradient.premium).frame(width: 96, height: 96)
                .bfShadow(.gold)
            Image(systemName: "crown.fill").font(.system(size: 42, weight: .bold)).foregroundStyle(.white)
            Image(systemName: "sparkle").font(.system(size: 16)).foregroundStyle(Color(hex: 0xFFC554)).offset(x: 58, y: -40)
            Image(systemName: "sparkle").font(.system(size: 10)).foregroundStyle(.white.opacity(0.8)).offset(x: -56, y: -30)
        }
        .floating(amplitude: 5)
        .accessibilityHidden(true)
    }
}
