import SwiftUI

enum ParchiTheme {
    // Sampled from the user's approved logo; no provisional teal palette.
    static let cream = Color(red: 246/255, green: 229/255, blue: 199/255)
    static let paper = Color(red: 249/255, green: 232/255, blue: 206/255)
    static let orange = Color(red: 204/255, green: 46/255, blue: 17/255)
    static let yellow = Color(red: 241/255, green: 145/255, blue: 22/255)
    static let ink = Color(red: 73/255, green: 37/255, blue: 16/255)
    static let muted = Color(red: 120/255, green: 84/255, blue: 58/255)
    static let line = Color(red: 213/255, green: 186/255, blue: 146/255)
    static let field = Color(red: 1, green: 250/255, blue: 237/255).opacity(0.65)
}

struct ParchiLogo: View {
    var size: CGFloat = 144
    var body: some View {
        Image("ParchiLogo").resizable().scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("Parchi")
    }
}

struct ParchiPrimaryButton: View {
    let title: String
    var symbol = "arrow.right"
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(title).font(.body.weight(.semibold))
                Image(systemName: symbol).accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 28)
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
        .buttonStyle(.plain).foregroundStyle(ParchiTheme.paper)
        .background(ParchiTheme.orange, in: RoundedRectangle(cornerRadius: 15))
    }
}

struct ParchiFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(.horizontal, 14).padding(.vertical, 15)
            .frame(minHeight: 54)
            .background(ParchiTheme.field, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(ParchiTheme.line))
    }
}

struct FieldError: View {
    let message: String?
    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.circle")
                .font(.footnote).foregroundStyle(ParchiTheme.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
