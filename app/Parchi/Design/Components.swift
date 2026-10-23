import SwiftUI

// Shared Parchi components. Built from `frontend/web/components/*.js` + `styles/components.css`.
// Rules: Dynamic Type fonts, >= 44 pt targets, VoiceOver labels, Reduce Motion respected, never colour alone.

// MARK: - Buttons

/// Full-width orange button (web `.primary`). >= 52 pt high.
struct ParchiPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.headline())
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.Color.onAccent)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Theme.Color.accent)
                    .opacity(configuration.isPressed ? 0.85 : 1)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// Outlined / quiet button on cream (web `.secondary` / text buttons). >= 44 pt high.
struct ParchiSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.headline())
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.Color.accent)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(configuration.isPressed ? Theme.Color.paper : Theme.Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(Theme.Color.accent.opacity(0.6), lineWidth: 1.5)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == ParchiPrimaryButtonStyle {
    static var parchiPrimary: ParchiPrimaryButtonStyle { ParchiPrimaryButtonStyle() }
}

extension ButtonStyle where Self == ParchiSecondaryButtonStyle {
    static var parchiSecondary: ParchiSecondaryButtonStyle { ParchiSecondaryButtonStyle() }
}

// MARK: - Card

/// Rounded surface container (web `.card`). Children keep their own accessibility.
struct ParchiCard<Content: View>: View {
    let padding: CGFloat
    let content: () -> Content

    init(padding: CGFloat = Theme.Spacing.l, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.Color.line.opacity(0.6), lineWidth: 1)
        )
    }
}

// MARK: - Chip

enum ParchiChipTone: Sendable {
    case neutral, success, warning, danger

    var foreground: Color {
        switch self {
        case .neutral: return Theme.Color.muted
        case .success: return Theme.Color.success
        case .warning: return Theme.Color.warning
        case .danger: return Theme.Color.danger
        }
    }

    /// Icon so the tone is never carried by colour alone.
    var symbol: String? {
        switch self {
        case .neutral: return nil
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .danger: return "xmark.octagon.fill"
        }
    }
}

/// Small status pill (web `.status-pill`, `.j-status`).
struct ParchiChip: View {
    let text: String
    var tone: ParchiChipTone = .neutral
    var showsIcon: Bool = true

    init(text: String, tone: ParchiChipTone = .neutral, showsIcon: Bool = true) {
        self.text = text
        self.tone = tone
        self.showsIcon = showsIcon
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            if showsIcon, let symbol = tone.symbol {
                Image(systemName: symbol).imageScale(.small).accessibilityHidden(true)
            }
            Text(text)
        }
        .font(Theme.Font.caption())
        .foregroundStyle(tone.foreground)
        .padding(.horizontal, Theme.Spacing.s + 2)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Capsule().fill(tone.foreground.opacity(0.14)))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Sample badge

/// Small "Sample" tag for anything that is demo / sample data (product rule 2).
struct SampleBadge: View {
    var text: String = "Sample"

    var body: some View {
        Text(text)
            .font(Theme.Font.caption())
            .textCase(.uppercase)
            .foregroundStyle(Theme.Color.ink)
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, 2)
            .background(Capsule().fill(Theme.Color.gold.opacity(0.35)))
            .overlay(Capsule().strokeBorder(Theme.Color.gold, lineWidth: 1))
            .accessibilityLabel("\(text) data")
            .accessibilityIdentifier("sampleBadge")
    }
}

// MARK: - Header

/// Screen title block (web `.screen-title` / `.form-heading`).
struct ParchiHeader: View {
    let title: String
    var subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(Theme.Font.title())
                .foregroundStyle(Theme.Color.ink)
                .accessibilityAddTraits(.isHeader)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(Theme.Font.body())
                    .foregroundStyle(Theme.Color.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Tab bar

enum ParchiTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case home, parchis, care, account
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .parchis: return "Parchis"
        case .care: return "Care"
        case .account: return "Account"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house"
        case .parchis: return "doc.text"
        case .care: return "heart"
        case .account: return "person"
        }
    }
}

/// Bottom tab bar (web `tabs()`). A plain view: it only changes `selection` and calls `onSelect`;
/// the parent decides what to show. NOT a navigation container.
struct ParchiTabBar: View {
    @Binding var selection: ParchiTab
    var onSelect: ((ParchiTab) -> Void)?

    init(selection: Binding<ParchiTab>, onSelect: ((ParchiTab) -> Void)? = nil) {
        self._selection = selection
        self.onSelect = onSelect
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ParchiTab.allCases) { tab in
                let selected = tab == selection
                Button {
                    selection = tab
                    onSelect?(tab)
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: selected ? "\(tab.symbol).fill" : tab.symbol)
                            .imageScale(.large)
                            .accessibilityHidden(true)
                        Text(tab.title)
                            .font(Theme.Font.caption())
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Capsule()
                            .fill(selected ? Theme.Color.accent : Color.clear)
                            .frame(width: 18, height: 3)
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(selected ? Theme.Color.accent : Theme.Color.muted)
                    .frame(maxWidth: .infinity, minHeight: Theme.minTarget + 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
                .accessibilityIdentifier("tab_\(tab.rawValue)")
            }
        }
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.top, Theme.Spacing.xs)
        .background(
            Theme.Color.paper
                .shadow(color: Theme.Color.ink.opacity(0.08), radius: 6, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
    }
}

// MARK: - Logo

/// The transparent Parchi logo from `frontend/assets/parchi-logo-transparent.png`. Never recoloured, no tile.
struct LogoMark: View {
    var size: CGFloat = 44

    init(size: CGFloat = 44) {
        self.size = size
    }

    var body: some View {
        Image("ParchiLogo")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("Parchi")
            .accessibilityAddTraits(.isImage)
    }
}
