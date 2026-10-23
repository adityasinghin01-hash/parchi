import MapKit
import ParchiCore
import SwiftUI

/// Bottom sheet for one shop (tap a pin or a list row). Plain on purpose: system components only, restyled later.
struct ShopSheet: View {
    let shop: MapShop

    @Environment(AppModel.self) private var app
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var askOpen = false
    @State private var notice: String?

    var body: some View {
        let quote = ShopPricer(app: app).quote(for: shop)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(quote)
                    actions
                    if let notice {
                        Label(notice, systemImage: "info.circle")
                            .font(.subheadline)
                            .accessibilityIdentifier("shopSheetNotice")
                    }
                    if !quote.items.isEmpty { itemPrices(quote) }
                    if let footnote = quote.footnote {
                        Text(footnote).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityLabel("Close shop sheet") }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $askOpen) { AskThisShopSheet(shop: shop) }
    }

    // MARK: Header

    private func header(_ quote: ShopQuote) -> some View {
        // The shop answered "not available" for every medicine: a "Shop replied" chip but no number.
        let repliedUnavailable = quote.price.isAsk && quote.price.source != nil
        return VStack(alignment: .leading, spacing: 6) {
            Text(shop.name).font(.title3.bold()).accessibilityIdentifier("shopSheetName")
            Text([kindText, shop.distanceText].compactMap { $0 }.joined(separator: " · "))
                .foregroundStyle(.secondary)
            if let address = shop.address { Text(address).font(.subheadline).foregroundStyle(.secondary) }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(repliedUnavailable ? "Not available" : quote.price.text).font(.title2.bold()).monospacedDigit()
                if let coverage = quote.price.coverageText { Text(coverage).foregroundStyle(.secondary) }
            }
            .padding(.top, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(repliedUnavailable ? "Not available, the shop replied" : quote.price.spoken)
            .accessibilityIdentifier("shopSheetPrice")
            if let source = quote.price.source {
                PriceSourceChip(source: source)
            } else {
                Text("No price yet · ask the shop").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var kindText: String {
        shop.planSellerID != nil ? (shop.kind == .janAushadhi ? "Jan Aushadhi Kendra · in your plan data" : "Chemist · in your plan data")
            : (shop.kind == .janAushadhi ? "Jan Aushadhi Kendra" : "Chemist")
    }

    // MARK: Buttons (each at least 44 pt, each says what it does)

    private var phone: String? {
        let text = shop.phone ?? app.shopAsk.phone(for: shop.id)
        let dialable = text?.filter { $0.isNumber || $0 == "+" }
        return (dialable?.isEmpty ?? true) ? nil : dialable
    }

    private var actions: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            if let phone {
                actionButton("Call", icon: "phone", label: "Call \(shop.name)", id: "shopCall") { call(phone) }
            }
            actionButton("Directions", icon: "map", label: "Directions to \(shop.name)", id: "shopDirections", action: directions)
            actionButton("Ask this shop", icon: "bubble.left.and.text.bubble.right", label: "Ask \(shop.name) for prices", id: "shopAsk") {
                app.prepareShopAsk(preselecting: shop)
                askOpen = true
            }
            actionButton("Copy message", icon: "doc.on.doc", label: "Copy the message to ask \(shop.name)", id: "shopCopy", action: copyMessage)
        }
    }

    private func actionButton(_ title: String, icon: String, label: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    private func call(_ number: String) {
        #if targetEnvironment(simulator)
        notice = "Calling works on a real iPhone."
        #else
        guard let url = URL(string: "tel:\(number)") else { notice = "This phone number cannot be dialled."; return }
        openURL(url)
        #endif
    }

    private func directions() {
        let options = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        if let item = shop.mapItem {
            item.openInMaps(launchOptions: options)
        } else if let coordinate = shop.coordinate {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            item.name = shop.name
            item.openInMaps(launchOptions: options)
        } else if let url = app.shopAsk.directionsURL(for: ShopCandidate(id: shop.id, name: shop.name, distanceM: shop.distanceM)) {
            openURL(url)   // plan-data shop without coordinates: Maps searches by name
        } else {
            notice = "Directions are not available for this shop."
        }
    }

    /// The existing "Ask nearby shops" text for this shop (the user pastes it into WhatsApp or SMS). Nothing is sent.
    private func copyMessage() {
        app.prepareShopAsk(preselecting: shop)
        guard let filled = app.shopAsk.message(for: shop.id) else { notice = "The message template is missing."; return }
        // Without a live ask there is no reply link; never copy the placeholder address into a message to a real shop.
        let text = filled.text.replacingOccurrences(of: #"https://parchi-demo\.invalid/\S*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        UIPasteboard.general.string = text
        notice = "Message copied. Paste it into WhatsApp or SMS. Nothing was sent."
    }

    // MARK: Per-item prices

    private func itemPrices(_ quote: ShopQuote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Price for each medicine").font(.headline)
            ForEach(quote.items) { item in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.name)
                        if let note = item.note { Text(note).font(.caption).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    Text(item.paise.map { rupees($0) } ?? "—").monospacedDigit()
                        .accessibilityLabel(item.paise.map { rupees($0) } ?? "no price")
                }
                Divider()
            }
        }
    }
}

/// The existing Ask nearby shops sheet, opened with this shop picked. The ask flow itself is unchanged.
struct AskThisShopSheet: View {
    let shop: MapShop
    @Environment(AppModel.self) private var app

    var body: some View {
        ShopAskSheet()
            // The sheet prepares itself with the plan's shops when it appears; pick this shop right after that.
            .task {
                await Task.yield()
                try? await Task.sleep(for: .milliseconds(150))
                app.prepareShopAsk(preselecting: shop)
            }
    }
}
