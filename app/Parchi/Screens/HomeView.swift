import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Binding var path: [Route]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Parchi")
                .font(.largeTitle.bold())
            Text("Share or scan your doctor's parchi. We read every medicine and test, and find the full price to get all of it.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Button {
                model.readDemoParchi()
                path.append(.confirm)
            } label: {
                Label("Scan or share parchi", systemImage: "camera.viewfinder")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            Text("Demo build: uses a sample parchi with real prices captured 23 Oct 2026.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }
}
