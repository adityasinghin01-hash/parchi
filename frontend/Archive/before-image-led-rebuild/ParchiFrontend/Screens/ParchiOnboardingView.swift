import SwiftUI
import UIKit

/// Standalone frontend entry. In the upstream app, mount this from ParchiApp
/// and hand authenticated flow off to the existing RootView through its owner.
struct ParchiOnboardingView: View {
    @State private var state = OnboardingState()
    @State private var showingLocation = false
    @State private var showingCaptureNotice = false
    @AccessibilityFocusState private var confirmationFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                ParchiTheme.cream.ignoresSafeArea()
                VStack(spacing: 0) {
                    header
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            switch state.page {
                            case .welcome: welcome
                            case .details: details
                            case .account: account
                            case .login: login
                            case .dashboard:
                                ParchiDashboardView(state: state,
                                    chooseLocation: { showingLocation = true },
                                    scan: { showingCaptureNotice = true })
                            }
                        }
                        .padding(.horizontal, 26).padding(.top, 18).padding(.bottom, 32)
                        .frame(maxWidth: 540)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .accessibilityHidden(state.showingConfirmation)
                }
                .allowsHitTesting(!state.showingConfirmation)
                .accessibilityHidden(state.showingConfirmation)
                if state.showingConfirmation { confirmation }
            }
            .toolbar(.hidden, for: .navigationBar)
            .foregroundStyle(ParchiTheme.ink)
            .sheet(isPresented: $showingLocation) {
                LocationPickerView(language: state.language, selection: state.page == .dashboard ? state.profileLocation : state.location) { value in
                    state.location = value
                    if state.page == .dashboard { state.profileLocation = value }
                    state.errors["location"] = nil
                }
                .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            }
            .alert(state.text("Add your prescription", "अपनी पर्ची जोड़ें"), isPresented: $showingCaptureNotice) {
                Button(state.text("Close", "बंद करें"), role: .cancel) { }
            } message: {
                Text(state.text("Prescription capture will connect to the team's native capture flow.", "पर्ची जोड़ने की सुविधा टीम के मूल कैप्चर फ़्लो से जुड़ेगी।"))
            }
            .task(id: state.confirmationID) {
                guard state.showingConfirmation else { return }
                confirmationFocused = true
                // VoiceOver users control dismissal; others see the brief confirmation.
                guard !UIAccessibility.isVoiceOverRunning else { return }
                do { try await Task.sleep(for: .milliseconds(2200)) } catch { return }
                guard !Task.isCancelled else { return }
                dismissConfirmation()
            }
        }
        .tint(ParchiTheme.orange)
        .environment(\.locale, Locale(identifier: state.language.rawValue))
        // The approved cream palette remains the same in either system appearance.
        .preferredColorScheme(.light)
    }

    private var header: some View {
        HStack {
            ParchiLogo(size: 35).accessibilityHidden(true)
            Text("Parchi").font(.title2.bold()) + Text(".").font(.title2.bold()).foregroundColor(ParchiTheme.orange)
            Spacer()
        }
        .padding(.horizontal, 26).padding(.vertical, 15)
        .accessibilityElement(children: .ignore).accessibilityLabel("Parchi")
    }

    private var welcome: some View {
        VStack(spacing: 24) {
            ParchiLogo().padding(.top, 12)
            Text(state.text("YOUR CARE, ALL TOGETHER", "आपकी देखभाल, एक जगह"))
                .font(.caption2.weight(.bold)).tracking(2).foregroundStyle(ParchiTheme.orange)
            Text(state.text("A simpler start to\nbetter care.", "बेहतर देखभाल की\nआसान शुरुआत।"))
                .font(.largeTitle.bold()).multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 14) {
                Label(state.text("Choose your preferred language", "अपनी पसंदीदा भाषा चुनें"), systemImage: "character.bubble")
                    .font(.subheadline.weight(.semibold))
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { languageOptions }
                    VStack(spacing: 10) { languageOptions }
                }
            }
            .padding(18).background(ParchiTheme.field.opacity(0.5), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(ParchiTheme.line))
            ParchiPrimaryButton(title: state.text("Continue", "आगे बढ़ें")) { state.move(to: .details) }
                .accessibilityIdentifier("welcome.continue")
            accountSwitch(login: true)
        }.frame(maxWidth: .infinity)
    }

    @ViewBuilder private var languageOptions: some View {
        ForEach(ParchiLanguage.allCases) { language in
            Button {
                state.language = language
            } label: {
                HStack {
                    Text(language.title).font(.body.weight(.semibold))
                    Spacer(minLength: 12)
                    Image(systemName: state.language == language ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(state.language == language ? ParchiTheme.orange : ParchiTheme.muted)
                        .accessibilityHidden(true)
                }
                .padding(14).frame(minWidth: 120, minHeight: 54)
                .background(ParchiTheme.paper.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(state.language == language ? ParchiTheme.orange : ParchiTheme.line))
            }
            .buttonStyle(.plain).accessibilityIdentifier("language.\(language.rawValue)")
            .accessibilityAddTraits(state.language == language ? [.isSelected] : [])
        }
    }

    private func topControls(back: @escaping () -> Void) -> some View {
        HStack {
            Button(action: back) {
                Image(systemName: "arrow.left").frame(width: 44, height: 44)
                    .overlay(Circle().stroke(ParchiTheme.line))
            }.buttonStyle(.plain).accessibilityLabel(state.text("Go back", "वापस जाएँ"))
            Spacer()
            languageToggle
        }
    }

    private var languageToggle: some View {
        Button {
            state.language = state.language == .english ? .hindi : .english
            state.errors = [:]
        } label: {
            Text("अ / A · \(state.language.title)").font(.caption)
                .padding(.horizontal, 12).frame(minHeight: 44)
                .overlay(Capsule().stroke(ParchiTheme.line))
        }.buttonStyle(.plain).accessibilityIdentifier("language.toggle")
    }

    private func progress(second: Bool) -> some View {
        HStack {
            Text(second ? state.text("YOUR ACCOUNT", "आपका खाता") : state.text("YOUR DETAILS", "आपकी जानकारी"))
                .font(.caption2.bold()).tracking(1.5).foregroundStyle(ParchiTheme.orange)
            Spacer()
            HStack(spacing: 5) {
                Capsule().fill(ParchiTheme.orange)
                Capsule().fill(second ? ParchiTheme.orange : ParchiTheme.line)
            }.frame(width: 54, height: 4).accessibilityHidden(true)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 22) {
            topControls { state.move(to: .welcome) }
            progress(second: false)
            heading(state.text("Let’s get to know you.", "आइए, आपको जानें।"), subtitle: state.text("A few details to make Parchi feel like yours.", "पर्ची को अपना बनाने के लिए कुछ जानकारी।"))
            labeledField(state.text("First name", "पहला नाम"), key: "firstName") {
                TextField(state.text("Enter your first name", "अपना पहला नाम लिखें"), text: $state.firstName)
                    .textContentType(.givenName).accessibilityIdentifier("profile.firstName").modifier(ParchiFieldStyle())
            }
            labeledField(state.text("Last name", "उपनाम"), optional: true, key: "lastName") {
                TextField(state.text("Enter your last name", "अपना उपनाम लिखें"), text: $state.lastName)
                    .textContentType(.familyName).accessibilityIdentifier("profile.lastName").modifier(ParchiFieldStyle())
            }
            labeledField(state.text("Phone number", "फ़ोन नंबर"), key: "phone") {
                HStack(spacing: 0) {
                    Text("+91").padding(.horizontal, 14).accessibilityLabel(state.text("Country code plus 91", "देश का कोड प्लस 91"))
                    Rectangle().fill(ParchiTheme.line).frame(width: 1, height: 24).accessibilityHidden(true)
                    TextField(state.text("10-digit mobile number", "10 अंकों का मोबाइल नंबर"), text: $state.phone)
                        .keyboardType(.phonePad).textContentType(.telephoneNumber)
                        .padding(.horizontal, 12).padding(.vertical, 15)
                        .accessibilityIdentifier("profile.phone")
                }
                .frame(minHeight: 54).background(ParchiTheme.field, in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(ParchiTheme.line))
            }
            labeledField(state.text("Your location", "आपकी लोकेशन"), key: "location") {
                Button { showingLocation = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill").foregroundStyle(ParchiTheme.orange).font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(state.location.isEmpty ? state.text("Choose your location", "अपनी लोकेशन चुनें") : state.location)
                                .font(.subheadline.weight(.semibold))
                            Text(state.text("For nearby pharmacies and labs", "आस-पास की दवा दुकानों और लैब के लिए"))
                                .font(.caption).foregroundStyle(ParchiTheme.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption).accessibilityHidden(true)
                    }.frame(maxWidth: .infinity, alignment: .leading).modifier(ParchiFieldStyle())
                }.buttonStyle(.plain).accessibilityIdentifier("profile.location")
            }
            ParchiPrimaryButton(title: state.text("Continue", "आगे बढ़ें")) {
                if state.validateDetails() { state.move(to: .account) }
            }.accessibilityIdentifier("details.continue")
            accountSwitch(login: true)
        }
    }

    private var account: some View {
        VStack(alignment: .leading, spacing: 22) {
            topControls { state.move(to: .details) }
            progress(second: true)
            heading(state.text("Create account.", "खाता बनाएँ।"), subtitle: state.text("You can use English or Hindi letters in your username.", "यूज़रनेम में अंग्रेज़ी या हिंदी अक्षर इस्तेमाल कर सकते हैं।"))
            credentials(isLogin: false)
            ParchiPrimaryButton(title: state.text("Create account", "खाता बनाएँ")) { state.finishPreview(isLogin: false) }
                .accessibilityIdentifier("account.submit")
            demoNote
            accountSwitch(login: true)
        }
    }

    private var login: some View {
        VStack(alignment: .leading, spacing: 24) {
            topControls { state.move(to: .welcome) }
            ParchiLogo(size: 76)
            heading(state.text("Welcome back.", "फिर से स्वागत है।"), subtitle: state.text("Good to have you here. Let’s pick up where you left off.", "आपको दोबारा देखकर अच्छा लगा। आइए, वहीं से आगे बढ़ें।"))
            credentials(isLogin: true)
            ParchiPrimaryButton(title: state.text("Log in", "लॉग इन करें")) { state.finishPreview(isLogin: true) }
                .accessibilityIdentifier("login.submit")
            demoNote
            accountSwitch(login: false)
        }
    }

    @ViewBuilder private func credentials(isLogin: Bool) -> some View {
        labeledField(state.text("Username", "यूज़रनेम"), key: "username") {
            TextField(state.text("Enter your username", "अपना यूज़रनेम लिखें"), text: $state.username)
                .textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityIdentifier("account.username").modifier(ParchiFieldStyle())
        }
        labeledField(state.text("Password", "पासवर्ड"), key: "password") {
            ParchiPasswordField(value: $state.password, language: state.language, isLogin: isLogin)
        }
        if !isLogin {
            Text(state.text("Use at least 8 characters.", "कम से कम 8 अक्षर या अंक रखें।"))
                .font(.footnote).foregroundStyle(ParchiTheme.muted)
        }
    }

    private func labeledField<Content: View>(_ label: String, optional: Bool = false, key: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label + (optional ? state.text(" · Optional", " · वैकल्पिक") : " *"))
                .font(.subheadline.weight(.semibold))
            content()
            FieldError(message: state.errors[key]).accessibilityIdentifier("error.\(key)")
        }
    }

    private func heading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
            Text(subtitle).font(.subheadline).foregroundStyle(ParchiTheme.muted)
        }
    }

    private func accountSwitch(login: Bool) -> some View {
        VStack(spacing: 0) {
            Text(login ? state.text("Already have an account?", "पहले से खाता है?") : state.text("New to Parchi?", "पर्ची पर नए हैं?"))
                .font(.subheadline).foregroundStyle(ParchiTheme.muted)
            Button(login ? state.text("Log in", "लॉग इन करें") : state.text("Create account", "खाता बनाएँ")) {
                state.password = ""
                state.move(to: login ? .login : .details)
            }
            .font(.subheadline.bold()).frame(minHeight: 44)
            .accessibilityIdentifier(login ? "switch.login" : "switch.signup")
        }.frame(maxWidth: .infinity)
    }

    private var demoNote: some View {
        Text(state.text("UI demo · No account is created. Details stay in memory only.", "UI डेमो · खाता नहीं बनेगा। जानकारी केवल मेमोरी में रहती है।"))
            .font(.caption).foregroundStyle(ParchiTheme.muted).frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }

    private var confirmation: some View {
        ZStack {
            ParchiTheme.ink.opacity(0.28).ignoresSafeArea().accessibilityHidden(true)
            VStack(spacing: 22) {
                Image(systemName: "checkmark").font(.title.bold()).frame(width: 64, height: 64)
                    .background(ParchiTheme.yellow, in: Circle()).accessibilityHidden(true)
                Text(state.registered ? state.text("You’re all set.", "आप तैयार हैं।") : state.text("Welcome back.", "फिर से स्वागत है।"))
                    .font(.title.bold()).multilineTextAlignment(.center)
                    .accessibilityFocused($confirmationFocused)
                ParchiPrimaryButton(title: state.text("Go to dashboard", "डैशबोर्ड खोलें")) { dismissConfirmation() }
                    .accessibilityIdentifier("confirmation.continue")
            }
            .padding(26).background(ParchiTheme.cream, in: RoundedRectangle(cornerRadius: 26))
            .padding(.horizontal, 26).frame(maxWidth: 390)
            .accessibilityElement(children: .contain).accessibilityAddTraits(.isModal)
            .accessibilityIdentifier("confirmation.popup")
        }
    }

    private func dismissConfirmation() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { state.showingConfirmation = false }
    }
}

private struct ParchiPasswordField: View {
    @Binding var value: String
    let language: ParchiLanguage
    let isLogin: Bool
    @State private var visible = false
    var body: some View {
        HStack {
            Group {
                if visible { TextField(language.text("Enter your password", "अपना पासवर्ड लिखें"), text: $value) }
                else { SecureField(language.text("Enter your password", "अपना पासवर्ड लिखें"), text: $value) }
            }
            .textContentType(isLogin ? .password : .newPassword)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .accessibilityIdentifier("account.password")
            Button { visible.toggle() } label: {
                Image(systemName: visible ? "eye.slash" : "eye").frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain).foregroundStyle(ParchiTheme.orange)
            .accessibilityLabel(visible ? language.text("Hide password", "पासवर्ड छिपाएँ") : language.text("Show password", "पासवर्ड दिखाएँ"))
        }
        .padding(.leading, 14).padding(.trailing, 4).padding(.vertical, 5)
        .background(ParchiTheme.field, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(ParchiTheme.line))
    }
}

#Preview { ParchiOnboardingView() }
