import SwiftUI

struct GetItAllView: View {
    @Environment(AppModel.self) private var model
    @Binding var path: [Route]

    var body: some View {
        List {
            Section {
                Label("Test order: nothing is really bought or booked in this demo.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            if let plan = model.plan {
                ForEach(plan.sellerIDs, id: \.self) { sellerID in
                    let lines = plan.lines.filter { $0.sellerID == sellerID }
                    let total = lines.map(\.price).reduce(0, +) + (plan.feesBySeller[sellerID] ?? 0)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(model.sellerName(sellerID)).font(.headline)
                                Text(lines.map { model.itemName($0.itemID) }.joined(separator: ", "))
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(rupees(total)).monospacedDigit()
                        }
                        PriceSourceChip(source: model.priceSource(sellerID: sellerID))
                        ForEach(lines, id: \.itemID) { line in
                            if let link = model.productLink(itemID: line.itemID, sellerID: sellerID), let url = URL(string: link.productURL), url.scheme == "https" {
                                HStack {
                                    Link("Open \(model.itemName(line.itemID)) on \(model.sellerName(sellerID))", destination: url)
                                        .font(.subheadline)
                                    Spacer()
                                    Text(link.pricePaise.map { "Seen \(rupees($0))" } ?? "Price on seller page")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                .frame(minHeight: 44)
                            }
                        }
                    }
                }
                Section { Button("Open Checkout Assistant") { path.append(.checkout) } }
                Section {
                    Text("In the real app you finish payment in each seller's own app or website. Parchi never holds your money.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Get it all")
        .safeAreaInset(edge: .bottom) {
            Button {
                model.placeTestOrders()
                path.append(.track)
            } label: {
                Text("Place test orders").font(.headline).frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .padding()
            .background(.bar)
        }
    }
}
