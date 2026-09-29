//
//  Typography.swift
//  Fonts bundled in /fonts (registered in Info.plist → UIAppFonts). Each bundled face ships in one
//  weight, so custom faces carry headings and the system font carries body text — which also keeps
//  Dynamic Type and accessibility sizes working everywhere.
//

import SwiftUI

enum BFFontName {
    static let display = "Montserrat-ExtraBold"      // wordmark, hero titles
    static let title = "Poppins-SemiBold"            // screen & onboarding titles
    static let label = "DMSans-Bold"                 // buttons, section labels
    static let warm = "Nunito-ExtraBold"             // empty states, success moments
    static let money = "SpaceGrotesk-Bold"           // hero amounts
    static let serifDisplay = "DMSerifDisplay-Regular" // rights / legal headings
    static let serifBold = "Lora-Bold"               // letter subject lines
}

enum BFFont {
    // Custom faces scale with Dynamic Type via `relativeTo:`.
    static func display(_ size: CGFloat = 44) -> Font { .custom(BFFontName.display, size: size, relativeTo: .largeTitle) }
    static func title(_ size: CGFloat = 28) -> Font { .custom(BFFontName.title, size: size, relativeTo: .title) }
    static func title2(_ size: CGFloat = 22) -> Font { .custom(BFFontName.title, size: size, relativeTo: .title2) }
    static func title3(_ size: CGFloat = 18) -> Font { .custom(BFFontName.title, size: size, relativeTo: .title3) }
    static func label(_ size: CGFloat = 16) -> Font { .custom(BFFontName.label, size: size, relativeTo: .headline) }
    static func warm(_ size: CGFloat = 26) -> Font { .custom(BFFontName.warm, size: size, relativeTo: .title) }
    static func money(_ size: CGFloat = 34) -> Font { .custom(BFFontName.money, size: size, relativeTo: .largeTitle) }
    static func serifDisplay(_ size: CGFloat = 26) -> Font { .custom(BFFontName.serifDisplay, size: size, relativeTo: .title) }
    static func serifBold(_ size: CGFloat = 16) -> Font { .custom(BFFontName.serifBold, size: size, relativeTo: .headline) }

    // System faces.
    static let headline = Font.system(.headline, design: .default).weight(.semibold)
    static let body = Font.system(.body)
    static let bodyMedium = Font.system(.body).weight(.medium)
    static let callout = Font.system(.callout)
    static let subheadline = Font.system(.subheadline)
    static let caption = Font.system(.caption).weight(.medium)
    static let caption2 = Font.system(.caption2).weight(.semibold)
    static let mono = Font.system(.body, design: .monospaced).weight(.semibold)
    static let monoSmall = Font.system(.footnote, design: .monospaced).weight(.medium)
    static let letter = Font.system(.callout, design: .serif)
    static let evidence = Font.system(.subheadline, design: .serif)
    static let overline = Font.system(.caption2, design: .default).weight(.heavy)
}

extension View {
    /// Small uppercase tracked label used for section headers and evidence captions.
    func overlineStyle(_ color: Color = BFColor.text3) -> some View {
        font(BFFont.overline).tracking(1.2).textCase(.uppercase).foregroundStyle(color)
    }
}
