import SwiftUI
import UIKit

/// Parchi design tokens. Source: `frontend/web/styles/tokens.css` + the logo-sampled palette in
/// `frontend/SWIFT_HANDOFF.md` (cream #f6e5c7, paper #f9e8ce, orange #cc2e11, yellow #f19116, warm dark-brown text).
/// Light mode keeps the approved brand palette exactly; dark mode uses a warm dark-brown variant that stays readable.
enum Theme {
    enum Color {
        /// Page background. Light: cream #f6e5c7.
        static let cream = dynamic(light: 0xF6E5C7, dark: 0x1F150D)
        /// Slightly lighter sheet / grouped background. Light: paper #f9e8ce.
        static let paper = dynamic(light: 0xF9E8CE, dark: 0x2A1D12)
        /// Brand orange #cc2e11 (primary buttons, tint, links). Dark: brighter orange so text on dark brown stays readable.
        static let accent = dynamic(light: 0xCC2E11, dark: 0xEF6A43)
        /// Label colour on top of an `accent` fill (>= 4.5:1 in both modes).
        static let onAccent = dynamic(light: 0xFFFFFF, dark: 0x1F150D)
        /// Brand yellow #f19116 (icon tiles, highlights). Not for body text on cream.
        static let gold = dynamic(light: 0xF19116, dark: 0xF7A316)
        /// Main readable text: warm dark brown.
        static let ink = dynamic(light: 0x421C08, dark: 0xF6E5C7)
        /// Secondary text.
        static let muted = dynamic(light: 0x68553F, dark: 0xC9B18F)
        /// Card / row surface on top of cream.
        static let surface = dynamic(light: 0xFFF6E4, dark: 0x33241A)
        /// Hairlines and card borders.
        static let line = dynamic(light: 0xD5BA92, dark: 0x5A4632)
        /// Semantic status colours (text/icon colour; use with a label or icon, never colour alone).
        static let success = dynamic(light: 0x2A7432, dark: 0x8FD694)
        static let warning = dynamic(light: 0x8A5300, dark: 0xF2B04A)
        static let danger = dynamic(light: 0xB42308, dark: 0xFF8A75)

        static func dynamic(light: UInt32, dark: UInt32) -> SwiftUI.Color {
            SwiftUI.Color(UIColor { traits in
                themeUIColor(traits.userInterfaceStyle == .dark ? dark : light)
            })
        }
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 16
        static let sheet: CGFloat = 26
        static let chip: CGFloat = 999
    }

    /// Minimum tap target (tokens.css `--target-min`).
    static let minTarget: CGFloat = 44

    /// All fonts use Dynamic Type text styles so they scale with the user's text size.
    enum Font {
        static func largeTitle() -> SwiftUI.Font { .largeTitle.weight(.bold) }
        static func title() -> SwiftUI.Font { .title2.weight(.bold) }
        static func headline() -> SwiftUI.Font { .headline }
        static func body() -> SwiftUI.Font { .body }
        static func footnote() -> SwiftUI.Font { .footnote }
        static func caption() -> SwiftUI.Font { .caption.weight(.semibold) }
    }
}

private func themeUIColor(_ hex: UInt32) -> UIColor {
    UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
}
