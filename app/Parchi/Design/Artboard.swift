import SwiftUI
import UIKit

/// The HTML design is laid out on a 735-unit artboard: every CSS size is `calc(N * var(--u))` with `--u = width / 735`.
/// To port a screen EXACTLY, copy the numbers from the CSS / `frontend/specs/web/<route>.json` and multiply by the artboard unit:
///
///     @Environment(\.artboardUnit) private var u
///     Text("Parchi").font(.web(sizeU: 55, weight: 750)).padding(.top, 94 * u)
///
/// Wrap a screen's root in `.artboardScaled()` (once) so `u` equals the real screen width / 735 (390 pt wide -> 0.5306).
private struct ArtboardUnitKey: EnvironmentKey { static let defaultValue: CGFloat = 390.0 / 735.0 }

extension EnvironmentValues {
    var artboardUnit: CGFloat {
        get { self[ArtboardUnitKey.self] }
        set { self[ArtboardUnitKey.self] = newValue }
    }
}

private struct ArtboardScaled: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { geo in
            content.environment(\.artboardUnit, geo.size.width / 735)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
    }
}

extension View {
    /// Makes `@Environment(\.artboardUnit)` equal to this view's width / 735.
    func artboardScaled() -> some View { modifier(ArtboardScaled()) }
}

extension Font {
    /// Same family and weight the HTML renders. `sizeU` is the CSS `font-size` in artboard units (the spec's `type.sizeU`).
    /// `weight` is the CSS numeric weight (400, 500, 600, 650, 700, 750 ...); SF Pro is a variable font, so in-between weights work.
    /// Size follows the user's Dynamic Type setting (1.0 at the default size, so the default look matches the HTML exactly).
    static func web(sizeU: CGFloat, weight: Double = 400, italic: Bool = false, width: CGFloat = 390) -> Font {
        let base = sizeU * width / 735
        let scaled = base * UIFontMetrics.default.scaledValue(for: 17) / 17
        let font = UIFont.systemFont(ofSize: scaled, weight: UIFont.Weight(rawValue: cssWeightToUIKit(weight)))
        return Font(italic ? (font.withTraits(.traitItalic) ?? font) : font)
    }

    /// The HTML's editorial (headline) face is Georgia. Weight 700 uses Georgia-Bold.
    static func webSerif(sizeU: CGFloat, bold: Bool = true, italic: Bool = false, width: CGFloat = 390) -> Font {
        let base = sizeU * width / 735
        let scaled = base * UIFontMetrics.default.scaledValue(for: 17) / 17
        let name = bold ? (italic ? "Georgia-BoldItalic" : "Georgia-Bold") : (italic ? "Georgia-Italic" : "Georgia")
        return Font(UIFont(name: name, size: scaled) ?? UIFont.systemFont(ofSize: scaled, weight: bold ? .bold : .regular))
    }
}

private func cssWeightToUIKit(_ css: Double) -> CGFloat {
    let points: [(Double, Double)] = [(100, -0.8), (200, -0.6), (300, -0.4), (400, 0), (500, 0.23), (600, 0.3), (700, 0.4), (800, 0.56), (900, 0.62)]
    if css <= points.first!.0 { return CGFloat(points.first!.1) }
    for i in 1..<points.count where css <= points[i].0 {
        let (x0, y0) = points[i - 1], (x1, y1) = points[i]
        return CGFloat(y0 + (y1 - y0) * (css - x0) / (x1 - x0))
    }
    return CGFloat(points.last!.1)
}

private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        fontDescriptor.withSymbolicTraits(traits).map { UIFont(descriptor: $0, size: pointSize) }
    }
}

/// One illustration crop exactly as the HTML shows it: `asset` and the size in artboard units come from the spec's `art[]` entry.
struct WebArt: View {
    let asset: String
    let wu: CGFloat
    let hu: CGFloat
    @Environment(\.artboardUnit) private var u

    var body: some View {
        Image(asset).resizable().scaledToFit()
            .frame(width: wu * u, height: hu * u)
            .accessibilityHidden(true)
    }
}

extension Color {
    /// `rgb(66, 28, 8)` style values copied from the spec.
    static func web(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color { Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a) }
}
