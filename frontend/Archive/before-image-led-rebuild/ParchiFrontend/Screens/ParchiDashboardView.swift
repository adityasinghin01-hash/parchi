import SwiftUI

struct ParchiDashboardView: View {
    @Bindable var state: OnboardingState
    let chooseLocation: () -> Void
    let scan: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) { location; Spacer(); language }
                VStack(alignment: .leading, spacing: 12) { location; language }
            }
            VStack(alignment: .leading, spacing: 12) {
                Text(state.text("Hello", "नमस्ते") + ", " + state.displayName)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(ParchiTheme.orange)
                Text(state.text("Your care starts here.", "आपकी देखभाल यहीं से।"))
                    .font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("dashboard.title")
                Text(state.text("Add your prescription to find medicines and tests in one place.", "दवाइयाँ और जाँच एक जगह खोजने के लिए अपनी पर्ची जोड़ें।"))
                    .font(.subheadline).foregroundStyle(ParchiTheme.muted)
            }
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "doc.text.viewfinder").font(.largeTitle)
                    .foregroundStyle(ParchiTheme.orange).frame(width: 58, height: 58)
                    .background(ParchiTheme.yellow.opacity(0.22), in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityHidden(true)
                Text(state.text("GET STARTED", "शुरुआत करें"))
                    .font(.caption2.bold()).tracking(1.5).foregroundStyle(ParchiTheme.orange)
                Text(state.text("Scan or share parchi", "पर्ची स्कैन या शेयर करें"))
                    .font(.title2.bold()).accessibilityAddTraits(.isHeader)
                Text(state.text("Scan a prescription or add it from your photos", "पर्ची स्कैन करें या फ़ोटो से जोड़ें"))
                    .font(.subheadline).foregroundStyle(ParchiTheme.muted)
                ParchiPrimaryButton(title: state.text("Scan or share parchi", "पर्ची स्कैन या शेयर करें"), action: scan)
                    .accessibilityIdentifier("dashboard.scan")
            }
            .padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(ParchiTheme.field, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(ParchiTheme.line))
            VStack(alignment: .leading, spacing: 20) {
                Text(state.text("Recent parchis", "हाल की पर्चियाँ")).font(.headline).accessibilityAddTraits(.isHeader)
                VStack(spacing: 12) {
                    Image(systemName: "doc.text").font(.title2).accessibilityHidden(true)
                    Text(state.text("A fresh start.", "एक नई शुरुआत।")).font(.subheadline.bold())
                    Text(state.text("Your prescriptions will appear here once you add your first parchi.", "पहली पर्ची जोड़ने के बाद आपकी पर्चियाँ यहाँ दिखेंगी।"))
                        .font(.subheadline).multilineTextAlignment(.center)
                }
                .foregroundStyle(ParchiTheme.muted).padding(24).frame(maxWidth: .infinity)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(ParchiTheme.line, style: StrokeStyle(lineWidth: 1, dash: [4])))
            }
        }
    }
    private var location: some View {
        Button(action: chooseLocation) {
            HStack(spacing: 9) {
                Image(systemName: "mappin.circle.fill").font(.title2).foregroundStyle(ParchiTheme.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.text("YOUR LOCATION", "आपकी लोकेशन")).font(.caption2.bold()).foregroundStyle(ParchiTheme.muted)
                    Text(state.profileLocation.isEmpty ? state.text("Choose your location", "अपनी लोकेशन चुनें") : state.profileLocation)
                        .font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                }
                Image(systemName: "chevron.down").font(.caption).accessibilityHidden(true)
            }.frame(minHeight: 44)
        }.buttonStyle(.plain).accessibilityIdentifier("dashboard.location")
    }
    private var language: some View {
        Button {
            state.language = state.language == .english ? .hindi : .english
        } label: {
            Text("अ / A · \(state.language.title)").font(.caption)
                .padding(.horizontal, 12).frame(minHeight: 44)
                .overlay(Capsule().stroke(ParchiTheme.line))
        }.buttonStyle(.plain).accessibilityIdentifier("language.toggle")
    }
}
