import Foundation
import Observation

enum ParchiLanguage: String, CaseIterable, Identifiable {
    case english = "en", hindi = "hi"
    var id: String { rawValue }
    var title: String { self == .english ? "English" : "हिंदी" }
    func text(_ english: String, _ hindi: String) -> String {
        self == .english ? english : hindi
    }
}

enum OnboardingPage { case welcome, details, account, login, dashboard }
enum ProfileField: String { case firstName, lastName, phone, username, password }

/// Presentation state only. Connect real auth through the integration owner's adapter.
/// Passwords are never persisted, logged, or sent over the network.
@MainActor @Observable
final class OnboardingState {
    var language: ParchiLanguage = .english
    var page: OnboardingPage = .welcome
    var firstName = ""
    var lastName = ""
    var phone = ""
    var location = ""
    var username = ""
    var password = ""
    var errors: [String: String] = [:]
    var displayName = ""
    var profileLocation = ""
    var showingConfirmation = false
    var confirmationID = UUID()
    var registered = false

    func text(_ en: String, _ hi: String) -> String { language.text(en, hi) }
    func move(to page: OnboardingPage) {
        errors = [:]
        self.page = page
        if page == .welcome { password = "" }
    }
    func validateDetails() -> Bool {
        errors = [:]
        if firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors["firstName"] = text("Please enter your first name.", "कृपया अपना पहला नाम लिखें।")
        }
        let digits = phone.compactMap { $0.wholeNumberValue }
        let allowed = phone.allSatisfy { $0.wholeNumberValue != nil || $0 == " " || $0 == "-" }
        if !allowed || digits.count != 10 || !(6...9).contains(digits.first ?? 0) {
            errors["phone"] = text("Enter a valid 10-digit mobile number.", "सही 10 अंकों का मोबाइल नंबर लिखें।")
        }
        if location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors["location"] = text("Please choose your location.", "कृपया अपनी लोकेशन चुनें।")
        }
        return errors.isEmpty
    }
    func validateAccount(isLogin: Bool) -> Bool {
        errors = [:]
        let name = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            errors["username"] = text("Please enter your username.", "कृपया अपना यूज़रनेम लिखें।")
        } else if name.range(of: #"^[\p{L}\p{M}\p{N}_]+$"#, options: .regularExpression) == nil {
            errors["username"] = text("Use letters, numbers or underscores without spaces.", "बिना स्पेस के अक्षर, अंक या अंडरस्कोर लिखें।")
        }
        if password.isEmpty || (!isLogin && password.count < 8) {
            errors["password"] = isLogin
                ? text("Please enter your password.", "कृपया अपना पासवर्ड लिखें।")
                : text("Use at least 8 characters.", "कम से कम 8 अक्षर या अंक रखें।")
        }
        return errors.isEmpty
    }
    func finishPreview(isLogin: Bool) {
        guard validateAccount(isLogin: isLogin) else { return }
        displayName = (isLogin ? username : firstName).trimmingCharacters(in: .whitespacesAndNewlines)
        profileLocation = location
        registered = !isLogin
        firstName = ""; lastName = ""; phone = ""; username = ""; password = ""
        page = .dashboard
        confirmationID = UUID()
        showingConfirmation = true
    }
}
