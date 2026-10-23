import ParchiCore
import SwiftUI

/// "Online, 23 Oct" under every price, plus "may have changed" once it is more than 7 days old (U20).
struct PriceSourceChip: View {
    let source: PriceSource
    var now: Date = .now

    var body: some View {
        HStack(spacing: 6) {
            Text(source.datedLabel)
            if let note = source.staleNote(now: now) {
                Text("· \(note)").foregroundStyle(.orange)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}

/// Lab prices from the bundled real data for Meerut and Muradnagar. A city with no price shows "Price not found yet"; nothing is copied from another city.
struct LabPricesSection: View {
    @Environment(AppModel.self) private var model
    @State private var city: String = ""

    static let cities = ["Meerut", "Muradnagar"]

    var body: some View {
        Section {
            Picker("City", selection: $city) {
                ForEach(Self.cities, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            ForEach(model.lines.filter { $0.item.kind == .test && !$0.askDoctor }) { line in
                testRows(line)
            }
            labList
        } header: {
            Text("Lab prices in \(activeCity)")
        } footer: {
            Text("Lab prices were read from each lab's own page. Home collection and booking come from the lab.")
        }
        .onAppear { if city.isEmpty { city = Self.defaultCity(model.location.centre) } }
    }

    private var activeCity: String { city.isEmpty ? Self.defaultCity(model.location.centre) : city }

    @ViewBuilder
    private func testRows(_ line: ReadLine) -> some View {
        let test = line.canonicalTestName ?? line.item.name
        let prices = model.data.labPrices(city: activeCity, test: test)
        VStack(alignment: .leading, spacing: 4) {
            Text(line.item.name).font(.subheadline.weight(.semibold))
            if prices.isEmpty {
                Text("Price not found yet").foregroundStyle(.secondary)
            } else {
                ForEach(prices, id: \.lab) { row in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.lab)
                            PriceSourceChip(source: row.source)
                        }
                        Spacer()
                        Text(rupees(row.paise)).monospacedDigit()
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var labList: some View {
        let options = model.data.labOptions(city: activeCity)
        if options.isEmpty {
            Text("No labs found yet for \(activeCity).").foregroundStyle(.secondary)
        } else {
            DisclosureGroup("Labs in \(activeCity) (\(options.count))") {
                ForEach(options) { lab in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lab.lab)
                            Text(homeText(lab.homeCollection)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let text = lab.bookingURL, let url = URL(string: text), url.scheme == "https" {
                            Link("Book", destination: url).frame(minWidth: 44, minHeight: 44)
                        }
                    }
                }
            }
        }
    }

    private func homeText(_ value: LabOption.HomeCollection) -> String {
        switch value {
        case .yes: return "Home collection: yes"
        case .no: return "Home collection: no"
        case .unknown: return "Home collection: not confirmed"
        }
    }

    /// The nearer of Meerut and Muradnagar to where the patient is searching.
    static func defaultCity(_ centre: City) -> String {
        cities.min { a, b in distance(centre, a) < distance(centre, b) } ?? "Meerut"
    }

    private static func distance(_ centre: City, _ name: String) -> Double {
        guard let c = Cities.named(name) else { return .greatestFiniteMagnitude }
        return Cities.distanceKm(centre.latitude, centre.longitude, c.latitude, c.longitude)
    }
}
