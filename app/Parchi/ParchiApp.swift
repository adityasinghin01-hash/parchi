import SwiftUI

@main
struct ParchiApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        _ = TempFileStore().purgeExpired()   // photo crops older than their limit go at launch and whenever the app comes back
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.Color.accent)
                .environment(model)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { _ = TempFileStore().purgeExpired() }
        }
    }
}

enum Route: Hashable {
    case confirm, plan, getItAll, track, checkout
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .confirm: ConfirmView(path: $path)
                    case .plan: PlanView(path: $path)
                    case .getItAll: GetItAllView(path: $path)
                    case .track: TrackView()
                    case .checkout: CheckoutRouteView()
                    }
                }
        }
        .onAppear(perform: jumpForTesting)
        .captureInbox(path: $path, consent: model.consent)   // K12: Open in Parchi + the single capture preview sheet; consent gate in front of the first photo
        .overlay { if let name = UserDefaults.standard.string(forKey: "demoRoute"), let screen = Phase4Route.view(for: name) { screen.background(Color(.systemBackground)) } }   // Phase 4 demo screens: history|care|settings|consent|rank|city
        .onChange(of: path) { _, newPath in model.trackVisibilityChanged(newPath.contains(.track)) }
    }

    /// Launch with `-demoRoute confirm|plan|getItAll|track|planB|askShops|lab` to open the demo at that step (screenshots, rehearsal reset).
    private func jumpForTesting() {
        guard let target = UserDefaults.standard.string(forKey: "demoRoute") else { return }
        model.readDemoParchi()
        path = [.confirm]
        guard target != "confirm" else { return }
        model.choose(strength: "40", for: "telma")
        model.confirmList()
        path.append(.plan)
        if let sheet = ShopLabSheet(rawValue: target) { model.openShopLab(sheet); return }   // askShops | lab
        guard target != "plan" else { return }
        if target == "checkout" { path.append(.checkout); return }
        path.append(.getItAll)
        guard target != "getItAll" else { return }
        model.placeTestOrders()
        path.append(.track)
        if target == "planB", let online = model.approvedPlan?.sellerIDs.first(where: { model.seller($0)?.channel == .onlinePharmacy }) {
            model.simulateCancel(sellerID: online)
        }
    }
}
