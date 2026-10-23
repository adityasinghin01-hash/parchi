import SwiftUI

/// S0 first-run consent. Every sentence here must be something the code does; see PHASE4_INTEGRATION.md for the gate.
struct FirstRunConsentView: View {
    let consent: ConsentStore
    var onAgree: () -> Void = {}
    @State private var hindi = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 48)).foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text(hindi ? "आपका डेटा, आपके हाथ में" : "Your data stays yours").font(.largeTitle.bold())
                Picker("Language", selection: $hindi) {
                    Text("English").tag(false)
                    Text("हिन्दी").tag(true)
                }
                .pickerStyle(.segmented)

                ForEach(cards, id: \.symbol) { card in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: card.symbol).font(.title2).frame(width: 32).foregroundStyle(.tint).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(hindi ? card.hiTitle : card.title).font(.headline)
                            Text(hindi ? card.hiBody : card.body).foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityElement(children: .combine)
                }

                Button {
                    consent.agree()
                    onAgree()
                } label: {
                    Text(hindi ? "सहमत हूँ, आगे बढ़ें" : "Agree & continue")
                        .font(.title3.bold()).frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                Text(hindi ? "आप कभी भी सेटिंग्स से सब कुछ मिटा सकते हैं।" : "You can delete everything any time in Settings.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private struct Card { let symbol, title, body, hiTitle, hiBody: String }

    // Hindi lines are plain translations of the English; a native speaker should check them before release.
    private let cards: [Card] = [
        Card(symbol: "eye.slash",
             title: "The patient's name is blurred on your phone",
             body: "Before a parchi photo is sent anywhere, the name, age, phone number and address are blurred on this phone.",
             hiTitle: "मरीज़ का नाम आपके फ़ोन पर ही धुँधला होता है",
             hiBody: "पर्ची की फ़ोटो कहीं भेजने से पहले, नाम, उम्र, फ़ोन नंबर और पता इसी फ़ोन पर धुँधले कर दिए जाते हैं।"),
        Card(symbol: "server.rack",
             title: "Only the medicine part leaves the phone",
             body: "When the phone cannot read a line itself, only the cropped medicine area goes to our own computer (the Parchi lab server), not to an AI company.",
             hiTitle: "सिर्फ़ दवाओं वाला हिस्सा फ़ोन से बाहर जाता है",
             hiBody: "जब फ़ोन कोई पंक्ति खुद नहीं पढ़ पाता, तब केवल कटा हुआ दवाओं वाला हिस्सा हमारे अपने कंप्यूटर (Parchi लैब सर्वर) पर जाता है, किसी AI कंपनी को नहीं।"),
        Card(symbol: "internaldrive",
             title: "Your history stays on this phone",
             body: "Saved parchis, doses and settings are stored only on this phone. Test orders are kept on our lab computer under a random install key, never your name.",
             hiTitle: "आपका इतिहास इसी फ़ोन में रहता है",
             hiBody: "सेव की गई पर्चियाँ, खुराक और सेटिंग्स सिर्फ़ इसी फ़ोन में रहती हैं। टेस्ट ऑर्डर हमारे लैब कंप्यूटर पर एक random install key से रखे जाते हैं, आपके नाम से नहीं।"),
        Card(symbol: "trash",
             title: "Photo crops are deleted after 24 hours",
             body: "Photo crops and caches on this phone are deleted after 24 hours. Delete everything in Settings wipes the phone and asks our lab computer to delete this phone's test orders.",
             hiTitle: "फ़ोटो के हिस्से 24 घंटे में मिट जाते हैं",
             hiBody: "इस फ़ोन पर फ़ोटो के कटे हुए हिस्से और कैश 24 घंटे बाद मिटा दिए जाते हैं। सेटिंग्स में “Delete everything” फ़ोन का सारा डेटा मिटाता है और हमारे लैब कंप्यूटर से इस फ़ोन के टेस्ट ऑर्डर मिटाने को कहता है।"),
    ]
}
