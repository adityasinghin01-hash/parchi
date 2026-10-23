import SwiftUI

@main
struct ParchiApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}

enum Route: Hashable {
    case confirm, plan, getItAll, track
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
                    }
                }
        }
        .onAppear(perform: jumpForTesting)
    }

    /// Launch with `-demoRoute confirm|plan|getItAll|track|planB` to open the demo at that step (screenshots, rehearsal reset).
    private func jumpForTesting() {
        guard let target = UserDefaults.standard.string(forKey: "demoRoute") else { return }
        model.readDemoParchi()
        path = [.confirm]
        guard target != "confirm" else { return }
        model.choose(strength: "40", for: "telma")
        model.confirmList()
        path.append(.plan)
        guard target != "plan" else { return }
        path.append(.getItAll)
        guard target != "getItAll" else { return }
        model.placeTestOrders()
        path.append(.track)
        if target == "planB", let online = model.approvedPlan?.sellerIDs.first(where: { model.seller($0)?.channel == .onlinePharmacy }) {
            model.simulateCancel(sellerID: online)
        }
    }
}
