#if DEBUG
import SwiftUI

/// Preview-only catalogue of every shared component (light, dark, large text). Not used by the app.
struct ThemeCatalogue: View {
    @State private var tab: ParchiTab = .home

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    HStack(spacing: Theme.Spacing.m) {
                        LogoMark(size: 56)
                        ParchiHeader(title: "Design catalogue", subtitle: "Every shared component in one place.")
                    }

                    swatches

                    ParchiCard {
                        HStack {
                            Text("Card title").font(Theme.Font.headline()).foregroundStyle(Theme.Color.ink)
                            Spacer()
                            SampleBadge()
                        }
                        Text("Body text inside a card uses Dynamic Type.")
                            .font(Theme.Font.body()).foregroundStyle(Theme.Color.muted)
                        HStack {
                            ParchiChip(text: "Neutral")
                            ParchiChip(text: "In stock", tone: .success)
                        }
                        HStack {
                            ParchiChip(text: "Waiting", tone: .warning)
                            ParchiChip(text: "Failed", tone: .danger)
                        }
                    }

                    Button("Primary action") {}.buttonStyle(.parchiPrimary)
                    Button("Primary disabled") {}.buttonStyle(.parchiPrimary).disabled(true)
                    Button("Secondary action") {}.buttonStyle(.parchiSecondary)
                    Button("Secondary disabled") {}.buttonStyle(.parchiSecondary).disabled(true)
                    Text("Footnote text").font(Theme.Font.footnote()).foregroundStyle(Theme.Color.muted)
                }
                .padding(Theme.Spacing.l)
            }
            ParchiTabBar(selection: $tab)
        }
        .background(Theme.Color.cream.ignoresSafeArea())
        .tint(Theme.Color.accent)
    }

    private var swatches: some View {
        let colours: [(String, Color)] = [
            ("cream", Theme.Color.cream), ("paper", Theme.Color.paper), ("surface", Theme.Color.surface),
            ("accent", Theme.Color.accent), ("gold", Theme.Color.gold), ("ink", Theme.Color.ink),
            ("muted", Theme.Color.muted), ("success", Theme.Color.success), ("warning", Theme.Color.warning),
            ("danger", Theme.Color.danger),
        ]
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))], spacing: Theme.Spacing.s) {
            ForEach(colours, id: \.0) { name, colour in
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 8).fill(colour).frame(height: 36)
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.Color.line))
                    Text(name).font(Theme.Font.caption()).foregroundStyle(Theme.Color.ink)
                }
            }
        }
    }
}

#Preview("Light") { ThemeCatalogue() }
#Preview("Dark") { ThemeCatalogue().preferredColorScheme(.dark) }
#Preview("Large text") { ThemeCatalogue().dynamicTypeSize(.accessibility2) }
#endif
