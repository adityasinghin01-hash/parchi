import SwiftUI

struct ReferenceWelcomeView: View {
    let onContinue: (WelcomeChoice) -> Void
    @State private var selectedPermission: WelcomePermission?
    @State private var permissions = WelcomePermissionStore()
    @ScaledMetric(relativeTo: .largeTitle) private var brandSize: CGFloat = 42
    @ScaledMetric(relativeTo: .title) private var headlineSize: CGFloat = 26
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 13
    @ScaledMetric(relativeTo: .subheadline) private var rowTitleSize: CGFloat = 13
    @ScaledMetric(relativeTo: .caption) private var rowBodySize: CGFloat = 11
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 48

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    brand.padding(.top, 6)
                    introduction.padding(.top, 15)
                    VStack(spacing: 4) {
                        ForEach(WelcomePermission.allCases) { permission in
                            permissionRow(permission)
                        }
                    }.padding(.top, 13)
                    privacyCard.padding(.top, 10)
                    actions.padding(.top, 12)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 8)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
        .background(WelcomeDecoration())
        .foregroundStyle(WelcomeAppearance.brown)
        .preferredColorScheme(.light)
        .sheet(item: $selectedPermission) { permission in
            WelcomePermissionSheet(permission: permission, store: permissions)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var brand: some View {
        VStack(spacing: 0) {
            Image("ParchiLogo").resizable().scaledToFit()
                .frame(width: 154, height: 139)
                .accessibilityHidden(true)
            Text("Parchi")
                .font(.custom("Georgia-Bold", fixedSize: brandSize))
                .tracking(-1.5)
                .padding(.top, -1)
                .accessibilityAddTraits(.isHeader)
            Text("YOUR HEALTH, MORE CLEARLY")
                .font(.system(size: 8, weight: .semibold)).tracking(1.7)
                .foregroundStyle(WelcomeAppearance.secondary)
                .padding(.top, 1)
        }
    }

    private var introduction: some View {
        VStack(spacing: 8) {
            // One composed Text allows Dynamic Type to wrap naturally while retaining
            // the reference's orange emphasis on “clear plan”.
            (Text("Turn your prescription\ninto a ") + Text("clear plan").foregroundColor(WelcomeAppearance.orange))
                .font(.custom("Georgia-Bold", fixedSize: headlineSize))
                .tracking(-0.4).lineSpacing(1)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Parchi reads your prescription, protects your privacy, shows options and helps you get your medicines easily.")
                .font(.system(size: bodySize)).foregroundStyle(WelcomeAppearance.secondary)
                .lineSpacing(1.5).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func permissionRow(_ permission: WelcomePermission) -> some View {
        Button { selectedPermission = permission } label: {
            HStack(alignment: .center, spacing: 15) {
                ReferencePermissionIcon(kind: permission).frame(width: iconSize, height: iconSize)
                VStack(alignment: .leading, spacing: 3) {
                    Text(permission.title).font(.system(size: rowTitleSize, weight: .semibold))
                        .foregroundStyle(WelcomeAppearance.brown)
                    Text(permission.subtitle).font(.system(size: rowBodySize))
                        .foregroundStyle(WelcomeAppearance.secondary).lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium))
                    .foregroundStyle(WelcomeAppearance.chevron).accessibilityHidden(true)
            }
            .padding(.leading, 10).padding(.trailing, 14).padding(.vertical, 8)
            .frame(minHeight: 66)
            .background(WelcomeAppearance.card.opacity(0.66), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(permission.title) preferences")
        .accessibilityIdentifier("welcome.permission.\(permission.rawValue)")
    }

    private var privacyCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Image(systemName: "shield.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.93, blue: 0.78), Color(red: 0.96, green: 0.79, blue: 0.50)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: Color(red: 0.69, green: 0.38, blue: 0.12).opacity(0.28), radius: 3, y: 2)
                Image(systemName: "lock.fill").font(.system(size: 20, weight: .bold))
                    .foregroundStyle(WelcomeAppearance.brown).offset(y: 1)
            }.frame(width: iconSize, height: 52).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Your privacy is our priority")
                    .font(.system(size: rowTitleSize, weight: .semibold))
                Text("We automatically blur sensitive details like your name, age and phone number.")
                    .font(.system(size: rowBodySize)).foregroundStyle(WelcomeAppearance.secondary)
                    .lineSpacing(1).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .frame(minHeight: 74)
        .background(Color(red: 0.98, green: 0.79, blue: 0.51).opacity(0.25), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: 7) {
            Button { onContinue(.agree) } label: {
                HStack(spacing: 12) {
                    Text("I Agree & Continue").font(.system(size: 15, weight: .semibold))
                    Image(systemName: "arrow.right").font(.system(size: 16)).accessibilityHidden(true)
                }
                .foregroundStyle(WelcomeAppearance.card).padding(.horizontal, 20)
                .frame(maxWidth: .infinity, minHeight: 44).padding(.vertical, 1)
                .background(LinearGradient(colors: [WelcomeAppearance.orangeBright, WelcomeAppearance.orange], startPoint: .leading, endPoint: .trailing), in: Capsule())
            }
            .buttonStyle(.plain).accessibilityIdentifier("welcome.agree")
            Button { onContinue(.guest) } label: {
                Text("Continue as Guest").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WelcomeAppearance.orange)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain).accessibilityIdentifier("welcome.guest")
        }
    }
}

#Preview("Reference welcome · iPhone") {
    ReferenceWelcomeView { _ in }
}

#Preview("Large text") {
    ReferenceWelcomeView { _ in }.environment(\.dynamicTypeSize, .accessibility3)
}
