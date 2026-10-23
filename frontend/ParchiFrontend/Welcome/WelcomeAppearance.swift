import SwiftUI

enum WelcomeAppearance {
    static let cream = Color(red: 250/255, green: 238/255, blue: 218/255)
    static let card = Color(red: 255/255, green: 246/255, blue: 228/255)
    static let brown = Color(red: 66/255, green: 28/255, blue: 8/255)
    static let secondary = Color(red: 104/255, green: 85/255, blue: 63/255)
    static let orange = Color(red: 204/255, green: 63/255, blue: 18/255)
    static let orangeBright = Color(red: 221/255, green: 72/255, blue: 18/255)
    static let gold = Color(red: 247/255, green: 163/255, blue: 22/255)
    static let chevron = Color(red: 207/255, green: 170/255, blue: 124/255)
}

struct WelcomeDecoration: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                WelcomeAppearance.cream
                RadialGradient(colors: [.white.opacity(0.20), .clear], center: .center,
                               startRadius: 0, endRadius: geometry.size.height * 0.7)
                CornerWave().fill(LinearGradient(colors: [Color(red: 1, green: 0.77, blue: 0.37), WelcomeAppearance.gold.opacity(0.84)], startPoint: .top, endPoint: .bottom))
                    .frame(width: geometry.size.width * 0.14, height: geometry.size.height * 0.20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                CornerWaveLine().stroke(WelcomeAppearance.gold.opacity(0.65), lineWidth: 0.8)
                    .frame(width: geometry.size.width * 0.18, height: geometry.size.height * 0.22)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                CornerWave().fill(LinearGradient(colors: [Color(red: 1, green: 0.79, blue: 0.42), WelcomeAppearance.gold], startPoint: .top, endPoint: .bottom))
                    .rotationEffect(.degrees(180))
                    .frame(width: geometry.size.width * 0.19, height: geometry.size.height * 0.14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                CornerWaveLine().stroke(WelcomeAppearance.gold.opacity(0.65), lineWidth: 0.8)
                    .rotationEffect(.degrees(180))
                    .frame(width: geometry.size.width * 0.23, height: geometry.size.height * 0.17)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}

private struct CornerWave: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width * 0.78, y: 0))
        path.addCurve(to: CGPoint(x: rect.width * 0.75, y: rect.height * 0.38),
                      control1: CGPoint(x: rect.width * 0.31, y: rect.height * 0.13),
                      control2: CGPoint(x: rect.width * 0.56, y: rect.height * 0.24))
        path.addCurve(to: CGPoint(x: rect.width * 0.70, y: rect.height * 0.73),
                      control1: CGPoint(x: rect.width * 1.30, y: rect.height * 0.60),
                      control2: CGPoint(x: rect.width * 0.88, y: rect.height * 0.67))
        path.addCurve(to: CGPoint(x: 0, y: rect.height),
                      control1: CGPoint(x: rect.width * 0.36, y: rect.height * 0.87),
                      control2: CGPoint(x: rect.width * 0.05, y: rect.height * 0.89))
        path.closeSubpath()
        return path
    }
}

private struct CornerWaveLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.58, y: -5))
        path.addCurve(to: CGPoint(x: rect.width * 0.80, y: rect.height * 0.43),
                      control1: CGPoint(x: rect.width * 0.03, y: rect.height * 0.16),
                      control2: CGPoint(x: rect.width * 0.60, y: rect.height * 0.29))
        path.addCurve(to: CGPoint(x: rect.width * 0.70, y: rect.height * 0.77),
                      control1: CGPoint(x: rect.width * 1.18, y: rect.height * 0.65),
                      control2: CGPoint(x: rect.width * 1.15, y: rect.height * 0.70))
        path.addCurve(to: CGPoint(x: 0, y: rect.height),
                      control1: CGPoint(x: rect.width * 0.25, y: rect.height * 0.83),
                      control2: CGPoint(x: rect.width * 0.08, y: rect.height * 0.91))
        return path
    }
}

struct ReferencePermissionIcon: View {
    let kind: WelcomePermission
    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [Color(red: 1, green: 0.87, blue: 0.63).opacity(0.65), Color(red: 0.98, green: 0.86, blue: 0.68).opacity(0.35)], center: .center, startRadius: 0, endRadius: 26))
            if kind == .usage {
                HStack(alignment: .bottom, spacing: 3) {
                    RoundedRectangle(cornerRadius: 2).frame(width: 6, height: 14)
                    RoundedRectangle(cornerRadius: 2).frame(width: 6, height: 10)
                    RoundedRectangle(cornerRadius: 2).frame(width: 6, height: 19)
                }.foregroundStyle(LinearGradient(colors: [Color(red: 0.68, green: 0.30, blue: 0.10), Color(red: 0.48, green: 0.19, blue: 0.05)], startPoint: .top, endPoint: .bottom))
            } else {
                Image(systemName: kind.symbol).font(.system(size: kind == .location ? 30 : 27, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: kind == .notifications ? [WelcomeAppearance.gold, Color(red: 0.88, green: 0.43, blue: 0.01)] : [WelcomeAppearance.orangeBright, Color(red: 0.65, green: 0.19, blue: 0.02)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: WelcomeAppearance.gold.opacity(0.20), radius: 1, y: 2)
            }
        }.accessibilityHidden(true)
    }
}
