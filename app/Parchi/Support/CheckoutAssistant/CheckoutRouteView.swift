import SwiftUI

/// What `Route.checkout` shows. Launch options for screenshots (all optional):
/// `-checkoutScreen probe` opens the seller probe, `-probeAuto 1` runs it at once, `-checkoutStep 2` starts at step 2.
struct CheckoutRouteView: View {
    @Environment(AppModel.self) private var model
    @State private var flow: CheckoutFlow?
    private let screen = UserDefaults.standard.string(forKey: "checkoutScreen")

    var body: some View {
        Group {
            if screen == "probe" {
                SellerProbeView(autoRun: UserDefaults.standard.bool(forKey: "probeAuto"))
            } else if let flow {
                CheckoutAssistantView(flow: flow)
            } else {
                Text("No plan yet. Build a plan first.").foregroundStyle(.secondary)
            }
        }
        .onAppear {
            guard flow == nil, let plan = model.approvedPlan ?? model.plan else { return }
            let start = max(UserDefaults.standard.integer(forKey: "checkoutStep") - 1, 0)
            let built = CheckoutFlow(steps: CheckoutFlow.steps(for: plan, model: model), startAt: start)
            built.onSkip = { [model] sellerID in model.skipSeller(sellerID) }   // re-plan without that seller
            flow = built
        }
    }
}
