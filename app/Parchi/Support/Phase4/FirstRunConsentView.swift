import SwiftUI

/// S0 first-run consent. Every sentence here must be something the code does; see PHASE4_INTEGRATION.md for the gate.
struct FirstRunConsentView: View {
    let consent: ConsentStore
    var onAgree: () -> Void = {}
    /// Shown as a smaller "Not now" button when the screen is a gate in front of a photo (nothing is read or kept if they decline).
    var onDecline: (() -> Void)? = nil
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
                    AdaptiveStack {
                        Image(systemName: card.symbol).font(.title2).frame(minWidth: 32).foregroundStyle(.tint).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(hindi ? card.hiTitle : card.title).font(.headline)
                            Text(hindi ? card.hiBody : card.body).foregroundStyle(.primary)   // K24: grey on the grey card failed contrast
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
                        .barButtonText()
                }
                .buttonStyle(.borderedProminent)
                if let onDecline {
                    Button(action: onDecline) {
                        Text(hindi ? "अभी नहीं" : "Not now").frame(maxWidth: .infinity, minHeight: 44)   // K24: the whole row is the tap area, not just the words
                    }
                }
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
             title: "We try to hide the patient's details",
             body: "We try to hide the name, age, phone and address we can find. Check the picture before you continue; if anything personal is still visible, close it and crop it first.",
             hiTitle: "हम मरीज़ की निजी जानकारी छिपाने की कोशिश करते हैं",
             hiBody: "हमें जो नाम, उम्र, फ़ोन नंबर और पता मिलता है, उसे हम छिपाने की कोशिश करते हैं। आगे बढ़ने से पहले तस्वीर जाँच लें; अगर कुछ निजी जानकारी अब भी दिख रही है, तो उसे बंद करें और पहले क्रॉप करें।"),
        // KR (G6, consent version 2): names Anthropic's Claude service; makes no claim about how long Anthropic keeps the picture.
        Card(symbol: "server.rack",
             title: "When connected, the picture is read by Anthropic's Claude",
             body: "When Parchi is connected to our lab server, tapping Use this photo sends the picture (with what we could hide, hidden) through our lab server to Anthropic's Claude service, which reads the medicines and tests. Anthropic's own terms apply to that copy. In the demo the picture stays on this phone.",
             hiTitle: "जुड़े होने पर तस्वीर Anthropic का Claude पढ़ता है",
             hiBody: "जब Parchi हमारे लैब सर्वर से जुड़ा हो, तब “Use this photo” दबाने पर तस्वीर (जो हिस्सा हम छिपा पाए, वह छिपा हुआ) हमारे लैब सर्वर के ज़रिए Anthropic की Claude सेवा को जाती है, जो दवाइयाँ और जाँचें पढ़ती है। उस कॉपी पर Anthropic की अपनी शर्तें लागू होती हैं। डेमो में तस्वीर इसी फ़ोन पर रहती है।"),
        Card(symbol: "internaldrive",
             title: "Your history stays on this phone",
             body: "Saved parchis, doses and settings are stored only on this phone. Test orders are kept on our lab computer under a random install key, never your name.",
             hiTitle: "आपका इतिहास इसी फ़ोन में रहता है",
             hiBody: "सेव की गई पर्चियाँ, खुराक और सेटिंग्स सिर्फ़ इसी फ़ोन में रहती हैं। टेस्ट ऑर्डर हमारे लैब कंप्यूटर पर एक random install key से रखे जाते हैं, आपके नाम से नहीं।"),
        Card(symbol: "trash",
             title: "Photo copies are removed after 24 hours",
             body: "Photo copies on this phone are removed the next time you open Parchi after 24 hours. Delete everything in Settings wipes the phone and asks our lab computer to delete this phone's test orders. Calendar events Parchi added stay until you delete them in the Calendar app.",
             hiTitle: "फ़ोटो की कॉपी 24 घंटे बाद मिटाई जाती हैं",
             hiBody: "इस फ़ोन पर फ़ोटो की कॉपी 24 घंटे के बाद, अगली बार Parchi खोलने पर मिटा दी जाती हैं। सेटिंग्स में “Delete everything” फ़ोन का सारा डेटा मिटाता है और हमारे लैब कंप्यूटर से इस फ़ोन के टेस्ट ऑर्डर मिटाने को कहता है। Parchi ने जो Calendar इवेंट जोड़े हैं, वे आप Calendar ऐप में खुद मिटाएँ।"),
    ]
}
