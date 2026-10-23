import SwiftUI

/// K24: small layout helpers so big text (Dynamic Type, accessibility sizes) never squeezes a word letter by letter.
extension Color {
    /// Warning text that stays readable: plain `.orange` on white or on a light orange row fails contrast (about 2.2:1).
    static let parchiWarning = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.72, blue: 0.35, alpha: 1)
            : UIColor(red: 0.62, green: 0.28, blue: 0.0, alpha: 1)
    })
}

/// Side by side at normal sizes; stacked top to bottom at accessibility sizes (so the text gets the full width).
struct AdaptiveStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var verticalAlignment: VerticalAlignment = .top
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: spacing) { content }
        } else {
            HStack(alignment: verticalAlignment, spacing: spacing) { content }
        }
    }
}

extension View {
    /// Bottom-bar buttons: the label may grow with the text setting, but not so far that the bar covers half the screen.
    func barButtonText() -> some View {
        self.dynamicTypeSize(...DynamicTypeSize.accessibility1).lineLimit(2).multilineTextAlignment(.center)
    }
}
