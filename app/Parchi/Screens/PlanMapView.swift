import CoreLocation
import MapKit
import ParchiCore
import SwiftUI

/// Plan > Map: pins from a live Apple Maps search around the selected city, the same shops as a list (cheapest first, then
/// nearest), delivery-only sellers in a bottom strip. Plain on purpose; the design handover restyles it.
struct PlanMapView: View {
    @Environment(AppModel.self) private var app
    @State private var search = ShopSearchModel()
    @State private var selected: MapShop?
    @State private var position: MapCameraPosition = .automatic
    @Environment(\.dynamicTypeSize) private var typeSize

    private struct Row: Identifiable {
        let shop: MapShop
        let quote: ShopQuote
        var id: String { shop.id }
    }

    var body: some View {
        let pricer = ShopPricer(app: app)
        let rows = rows(pricer)
        let delivery = pricer.deliverySellers()
        VStack(spacing: 0) {
            mapArea(rows)
            List {
                if typeSize.isAccessibilitySize && !delivery.isEmpty {
                    Section { deliveryStrip(delivery).listRowInsets(EdgeInsets()) }
                }
                Section {
                    if search.state == .loading { Label("Finding shops…", systemImage: "magnifyingglass").foregroundStyle(.secondary) }
                    ForEach(rows) { row in shopRow(row) }
                    if rows.isEmpty { Text("No shops to show yet.").foregroundStyle(.secondary) }
                } header: {
                    Text("Shops, cheapest first, then nearest")
                } footer: {
                    Text("Shops come from Apple Maps, searched live around \(app.location.centre.name). Their names and places stay on this phone and are not saved. If you ask a shop, Parchi's server gets only a random code and a generic name, never its real name or place. Map data © Apple. A price marked \"Catalogue MRP\" is the printed price, not a quote from that shop.")
                }
            }
        }
        // K24: at big text the strip would fill the screen and leave no room for the shop list; it joins the list instead.
        .safeAreaInset(edge: .bottom, spacing: 0) { if !delivery.isEmpty && !typeSize.isAccessibilitySize { deliveryStrip(delivery) } }
        .sheet(item: $selected) { shop in ShopSheet(shop: shop) }
        .task(id: "\(app.location.centre.latitude),\(app.location.centre.longitude)") {
            selected = nil   // a sheet for the previous city's shop must not stay open under the new city
            position = .region(Self.region(for: app.location.centre))
            await search.load(around: app.location.centre)
            // Screenshot aid: `-mapOpenShop <id prefix>` opens that shop's sheet.
            if let key = UserDefaults.standard.string(forKey: "mapOpenShop"), selected == nil {
                selected = (ShopPricer(app: app).planShops() + search.shops).first { $0.id.hasPrefix(key) }
            }
        }
    }

    static func region(for centre: City) -> MKCoordinateRegion {
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: centre.latitude, longitude: centre.longitude),
                           latitudinalMeters: 5000, longitudinalMeters: 5000)
    }

    /// MapKit shops + the plan data's local shops, priced and sorted: cheapest first, then nearest.
    private func rows(_ pricer: ShopPricer) -> [Row] {
        let planIDs = Set(pricer.planShops().map(\.id))
        let all = pricer.planShops() + search.shops.filter { !planIDs.contains($0.id) }
        return all.map { Row(shop: $0, quote: pricer.quote(for: $0)) }.sorted { a, b in
            PinPricing.areInOrder(a.quote.price, a.shop.distanceM, a.shop.name, b.quote.price, b.shop.distanceM, b.shop.name)
        }
    }

    // MARK: Map or the offline message

    @ViewBuilder
    private func mapArea(_ rows: [Row]) -> some View {
        if search.state == .failed {
            VStack(spacing: 10) {
                Image(systemName: "wifi.slash").font(.largeTitle).foregroundStyle(.secondary).accessibilityHidden(true)
                Text("The map needs internet. The list still works.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("mapOfflineMessage")
                Button("Try again") { Task { await search.load(around: app.location.centre, force: true) } }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Try the map search again")
            }
            .frame(maxWidth: .infinity, minHeight: 180)
            .padding()
            .background(Color(.secondarySystemBackground))
        } else {
            Map(position: $position) {
                ForEach(rows.filter { $0.shop.coordinate != nil }) { row in
                    if let coordinate = row.shop.coordinate {
                        Annotation(row.shop.name, coordinate: coordinate, anchor: .bottom) { pin(row) }
                    }
                }
            }
            .frame(height: typeSize.isAccessibilitySize ? 140 : 210)
            .accessibilityIdentifier("planMap")
        }
    }

    /// Icon + text, never colour alone: chemist and Jan Aushadhi have different icons; "Ask" has its own icon.
    private func pin(_ row: Row) -> some View {
        let price = row.quote.price
        return Button { selected = row.shop } label: {
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: price.isAsk ? "questionmark.circle" : icon(row.shop.kind))
                    Text(price.isAsk ? "Ask" : price.fullText).font(.caption.bold()).monospacedDigit()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.secondary, lineWidth: 1))
                Image(systemName: "arrowtriangle.down.fill").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(row.shop.name), \(price.spoken)")
        .accessibilityIdentifier("mapPin-\(row.shop.id)")
    }

    private func icon(_ kind: MapShop.Kind) -> String { kind == .janAushadhi ? "heart.text.square" : "cross.case" }

    // MARK: List

    private func shopRow(_ row: Row) -> some View {
        let price = row.quote.price
        return Button { selected = row.shop } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: price.isAsk ? "questionmark.circle" : icon(row.shop.kind)).frame(width: 24).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.shop.name).font(.headline).foregroundStyle(.primary)
                    Text([row.shop.distanceText, row.shop.planSellerID != nil ? "in your plan data" : nil].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                    if let source = price.source { PriceSourceChip(source: source) }
                    else { Text("No price yet · ask the shop").font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(price.text).font(.headline).monospacedDigit().foregroundStyle(.primary)
                    if let coverage = price.coverageText { Text(coverage).font(.caption).foregroundStyle(.secondary) }
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(row.shop.name), \(price.spoken)")
        .accessibilityIdentifier("shopRow-\(row.shop.id)")
    }

    // MARK: Delivery-only strip

    private func deliveryStrip(_ sellers: [ShopPricer.DeliverySeller]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Delivered to you (not on the map)").font(.caption.bold()).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(sellers) { seller in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(seller.name).font(.subheadline.bold())
                            Text(seller.price.isAsk ? "Ask" : seller.price.fullText).font(.subheadline).monospacedDigit()
                            Text(([seller.inPlan ? "In your plan" : "Not in your plan"] + (seller.price.isAsk ? [] : [seller.source.datedLabel])).joined(separator: " · "))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .frame(minHeight: 44, alignment: .topLeading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("deliverySeller-\(seller.id)")
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
        .accessibilityIdentifier("deliveryStrip")
    }
}
