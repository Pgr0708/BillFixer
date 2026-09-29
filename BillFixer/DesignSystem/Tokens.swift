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
    // Brand
    static let navy = Color(hex: 0x0B2B5C)
    static let navy2 = Color(hex: 0x123A7A)
    static let navyDeep = Color(hex: 0x07203F)
    static let blue = Color(light: 0x2E7DF6, dark: 0x5B9BFF)
    static let blue2 = Color(hex: 0x5B9BFF)
    static let teal = Color(light: 0x00BFA5, dark: 0x22D3BB)
    static let teal2 = Color(hex: 0x22D3BB)

    // Semantic
    static let green = Color(light: 0x22C07A, dark: 0x3BDC93)
    static let amber = Color(light: 0xF5A623, dark: 0xFFC554)
    static let amber2 = Color(hex: 0xFFC554)
    static let red = Color(light: 0xEF4444, dark: 0xF87171)
    static let violet = Color(light: 0x7C6BFF, dark: 0x9B8CFF)
    static let pink = Color(hex: 0xFF8FB1)

    // Tinted surfaces
    static let blueSoft = Color(light: 0xE8F1FE, dark: 0x16233A)
    static let bluePale = Color(light: 0xF4F8FF, dark: 0x111A2B)
    static let tealSoft = Color(light: 0xE2F9F5, dark: 0x0F2A27)
    static let greenSoft = Color(light: 0xE6F9EF, dark: 0x12281D)
    static let amberSoft = Color(light: 0xFFF5E2, dark: 0x2A2313)
    static let redSoft = Color(light: 0xFEF0F0, dark: 0x2A1618)
    static let violetSoft = Color(light: 0xF0EDFF, dark: 0x1E1B36)

    // Text
    static let text1 = Color(light: 0x14213D, dark: 0xE6EBF4)
    static let text2 = Color(light: 0x4A5A75, dark: 0xA9B4C7)
    static let text3 = Color(light: 0x8492AB, dark: 0x7C8899)
    static let text4 = Color(light: 0xB4BECE, dark: 0x4E5A6D)
    static let onBrand = Color.white

    // Surfaces
    static let background = Color(light: 0xF7F9FD, dark: 0x0D1117)
    static let surface = Color(light: 0xFFFFFF, dark: 0x161B26)
    static let surfaceRaised = Color(light: 0xFFFFFF, dark: 0x1C2230)
    static let line = Color(light: 0xE9EEF6, dark: 0x232B3A)
}

enum BFGradient {
    static let navy = LinearGradient(colors: [BFColor.navy2, BFColor.navy], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let splash = LinearGradient(stops: [
        .init(color: Color(hex: 0x0B2B5C), location: 0),
        .init(color: Color(hex: 0x123A7A), location: 0.36),
        .init(color: Color(hex: 0x1B62C4), location: 0.72),
        .init(color: Color(hex: 0x2E7DF6), location: 1),
    ], startPoint: .top, endPoint: .bottomTrailing)
    static let blue = LinearGradient(colors: [Color(hex: 0x5B9BFF), Color(hex: 0x2E7DF6)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let teal = LinearGradient(colors: [Color(hex: 0x22D3BB), Color(hex: 0x00BFA5)], startPoint: .topLeading, endPoint: .bottomTrailing)
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
