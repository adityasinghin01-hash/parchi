import Foundation

enum MessageLanguage: String, CaseIterable, Identifiable {
    case en, hi, hinglish
    var id: String { rawValue }
    var title: String {
        switch self {
        case .en: return "English"
        case .hi: return "हिन्दी"
        case .hinglish: return "Hinglish"
        }
    }

    private static let key = "parchi.message.language"
    /// Default Hinglish (Muradnagar / Meerut shops); remembered between launches.
    static var saved: MessageLanguage {
        get { MessageLanguage(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .hinglish }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}

enum MessageChannel: String { case sms, whatsapp }

struct FilledMessage: Equatable {
    var text: String
    /// Placeholders found in the template text that no value was given for (reported, never silently dropped).
    var unfilled: [String]
}

/// The 30 drafted messages in `message_templates.json` (copied from parchi-research/codex/templates, bundled with the app).
/// Placeholders are read from each template's `text`; the file's own `placeholders` list has a few mismatches and is ignored.
/// Drafts: no native-speaker review yet (see the file's `review_note`s).
struct MessageTemplates {
    struct Template: Decodable {
        var id: String
        var lang: String
        var channel: String
        var purpose: String
        var text: String
    }

    let templates: [Template]

    static let shared = MessageTemplates(bundle: .main)

    init(bundle: Bundle) {
        if let url = bundle.url(forResource: "message_templates", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([Template].self, from: data) {
            templates = list
        } else {
            templates = []
        }
    }

    init(templates: [Template]) { self.templates = templates }

    /// purpose: shop_ask | shop_thanks_not_needed | lab_booking_request | lab_fasting_reminder | refill_ask
    func template(purpose: String, language: MessageLanguage, channel: MessageChannel) -> Template? {
        templates.first { $0.purpose == purpose && $0.lang == language.rawValue && $0.channel == channel.rawValue }
    }

    func fill(purpose: String, language: MessageLanguage, channel: MessageChannel, values: [String: String]) -> FilledMessage? {
        guard let template = template(purpose: purpose, language: language, channel: channel) else { return nil }
        return Self.fill(template.text, values: values)
    }

    /// Replaces every `{name}` found in `text` that has a value; lists the ones that do not.
    static func fill(_ text: String, values: [String: String]) -> FilledMessage {
        var result = text
        var missing: [String] = []
        for name in placeholders(in: text) {
            if let value = values[name] {
                result = result.replacingOccurrences(of: "{\(name)}", with: value)
            } else {
                missing.append(name)
            }
        }
        return FilledMessage(text: result, unfilled: missing)
    }

    static func placeholders(in text: String) -> [String] {
        var found: [String] = []
        var rest = Substring(text)
        while let open = rest.firstIndex(of: "{"), let close = rest[open...].firstIndex(of: "}") {
            let name = String(rest[rest.index(after: open)..<close])
            if !name.isEmpty, !name.contains(where: { $0.isWhitespace || $0 == "{" }), !found.contains(name) { found.append(name) }
            rest = rest[rest.index(after: close)...]
        }
        return found
    }
}
