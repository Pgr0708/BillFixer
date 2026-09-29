//
//  Tokens.swift
//  BillFixer — design tokens (mirror of the Figma styles: brand/*, semantic/*, text/*, surface/*).
//

import SwiftUI
import UIKit

extension Color {
    /// Adaptive color: `light` in light mode, `dark` in dark mode.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

/// Bill Fixer color system.
enum BFColor {
    // Brand — tuned brighter so accents read clearly on photos, gradients and dark surfaces
    static let navy = Color(hex: 0x0B2B5C)
    static let navy2 = Color(hex: 0x1A4A9A)
    static let navyDeep = Color(hex: 0x07203F)
    static let blue = Color(light: 0x2468FF, dark: 0x6FA8FF)
    static let blue2 = Color(hex: 0x6FA8FF)
    static let teal = Color(light: 0x00BFA5, dark: 0x2EE6C9)
    static let teal2 = Color(hex: 0x2EE6C9)

    // Semantic
    static let green = Color(light: 0x16B86A, dark: 0x4AE69B)
    static let amber = Color(light: 0xF59E0B, dark: 0xFFCB5C)
    static let amber2 = Color(hex: 0xFFCB5C)
    static let red = Color(light: 0xEF3B3B, dark: 0xFF7A7A)
    static let violet = Color(light: 0x6D5BFF, dark: 0xB3A6FF)
    static let pink = Color(hex: 0xFF7AA8)

    // Tinted surfaces — more saturated so icon circles and pills pop
    static let blueSoft = Color(light: 0xDDEAFF, dark: 0x1D3157)
    static let bluePale = Color(light: 0xEEF4FF, dark: 0x15213C)
    static let tealSoft = Color(light: 0xD3F7F0, dark: 0x113F3A)
    static let greenSoft = Color(light: 0xD9F6E7, dark: 0x163A2B)
    static let amberSoft = Color(light: 0xFFEFCF, dark: 0x3F3114)
    static let redSoft = Color(light: 0xFFE3E3, dark: 0x45202A)
    static let violetSoft = Color(light: 0xE8E3FF, dark: 0x2D2757)

    // Text
    static let text1 = Color(light: 0x101B36, dark: 0xF4F7FD)
    static let text2 = Color(light: 0x3E4D69, dark: 0xC3CEE2)
    static let text3 = Color(light: 0x74829E, dark: 0x97A4BE)
    static let text4 = Color(light: 0xAFBAD0, dark: 0x5C6A88)
    static let onBrand = Color.white

    // Surfaces — dark mode is deep navy (not grey-black), with lifted blue-tinted cards
    static let background = Color(light: 0xF5F8FE, dark: 0x0A1024)
    static let surface = Color(light: 0xFFFFFF, dark: 0x16203A)
    static let surfaceRaised = Color(light: 0xFFFFFF, dark: 0x1E2A4A)
    static let line = Color(light: 0xE3E9F4, dark: 0x2C3A5E)
}

enum BFGradient {
    static let navy = LinearGradient(colors: [Color(hex: 0x2560D0), Color(hex: 0x1A3F8C), BFColor.navy], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let aurora = LinearGradient(colors: [Color(hex: 0x2468FF), Color(hex: 0x6D5BFF), Color(hex: 0x00BFA5)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let violet = LinearGradient(colors: [Color(hex: 0xA08BFF), Color(hex: 0x6D5BFF)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let coral = LinearGradient(colors: [Color(hex: 0xFF9A7A), Color(hex: 0xEF3B3B)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let splash = LinearGradient(stops: [
        .init(color: Color(hex: 0x0B2B5C), location: 0),
        .init(color: Color(hex: 0x123A7A), location: 0.36),
        .init(color: Color(hex: 0x1B62C4), location: 0.72),
        .init(color: Color(hex: 0x2E7DF6), location: 1),
    ], startPoint: .top, endPoint: .bottomTrailing)
    static let blue = LinearGradient(colors: [Color(hex: 0x6FA8FF), Color(hex: 0x2468FF)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let teal = LinearGradient(colors: [Color(hex: 0x3BEBD0), Color(hex: 0x00B89E)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let amber = LinearGradient(colors: [Color(hex: 0xFFC554), Color(hex: 0xF5A623)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let green = LinearGradient(colors: [Color(hex: 0x3BDC93), Color(hex: 0x22C07A)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let premium = LinearGradient(colors: [Color(hex: 0xFFC554), Color(hex: 0xF5A623), Color(hex: 0xE89412)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let obsidian = LinearGradient(colors: [Color(hex: 0x0A0D14), Color(hex: 0x12161F), Color(hex: 0x1A1A28)], startPoint: .top, endPoint: .bottom)
    static let donut = AngularGradient(colors: [Color(hex: 0xEF4444), Color(hex: 0xF5A623), Color(hex: 0x2E7DF6), Color(hex: 0x00BFA5), Color(hex: 0xEF4444)], center: .center)
}

/// 4-pt spacing grid.
enum BFSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
    static let screen: CGFloat = 20
}

enum BFRadius {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
}

struct BFShadow {
    let color: Color
    let radius: CGFloat
    let y: CGFloat

    static let subtle = BFShadow(color: Color(hex: 0x102346, opacity: 0.05), radius: 3, y: 1)
    static let card = BFShadow(color: Color(hex: 0x102346, opacity: 0.07), radius: 14, y: 6)
    static let float = BFShadow(color: Color(hex: 0x102346, opacity: 0.14), radius: 24, y: 12)
    static let navyButton = BFShadow(color: Color(hex: 0x0B2B5C, opacity: 0.28), radius: 12, y: 6)
    static let glow = BFShadow(color: Color(hex: 0x00BFA5, opacity: 0.35), radius: 16, y: 0)
    static let gold = BFShadow(color: Color(hex: 0xF5A623, opacity: 0.35), radius: 18, y: 6)
}

extension View {
    func bfShadow(_ s: BFShadow) -> some View { shadow(color: s.color, radius: s.radius, x: 0, y: s.y) }
}
