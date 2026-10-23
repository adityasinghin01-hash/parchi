import ParchiCore
import SwiftUI

/// Plain, functional "Ask nearby shops" sheet (teammates restyle it later). Everything it shows comes from `ShopAskModel`.
struct ShopAskSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        let model = app.shopAsk
        NavigationStack {
            List {
                if model.phase == .composing || model.phase == .asking {
                    composeSections(model: model)
                } else {
                    statusSections(model: model)
                }
                if let notice = model.notice {
                    Section { Label(notice, systemImage: "doc.on.clipboard").font(.subheadline) }
                }
                if let error = model.error {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange).font(.subheadline) }
                }
            }
            .navigationTitle("Ask nearby shops")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                if model.phase != .asked {
                    Button {
                        model.send()
                    } label: {
                        Text(model.phase == .asking ? "Asking…" : "Send to \(model.selected.count) shop\(model.selected.count == 1 ? "" : "s")")
                            .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canSend)
                    .padding()
                    .background(.bar)
                }
            }
        }
        .onAppear {
            app.prepareShopAsk()
            model.resumePolling()
            // Screenshot aid: launch with `-demoSend 1` to press Send automatically.
            if UserDefaults.standard.bool(forKey: "demoSend"), model.phase == .composing { model.send() }
        }
    }

    // MARK: Before sending

    @ViewBuilder
    private func composeSections(model: ShopAskModel) -> some View {
        Section("Keep ready by") {
            DatePicker("Keep ready by", selection: Bindable(model).pickupTime, displayedComponents: .hourAndMinute)
            Text("Keep ready by \(model.pickupHint)").font(.headline)
        }

        Section {
            ForEach(model.candidates) { shop in
                VStack(alignment: .leading, spacing: 8) {
                    Button { model.toggle(shop.id) } label: {
                        HStack {
                            Image(systemName: model.selected.contains(shop.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(model.selected.contains(shop.id) ? Color.accentColor : .secondary)
                            VStack(alignment: .leading) {
                                Text(shop.name).foregroundStyle(.primary)
                                Text(shop.distanceText ?? "Distance not known").font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderless)
                    HStack {
                        TextField("Shop phone (optional)", text: phoneBinding(model, shop.id))
                            .keyboardType(.phonePad)
                            .textFieldStyle(.roundedBorder)
                        if let call = model.callURL(for: shop.id) {
                            Button { openURL(call) } label: { Label("Call", systemImage: "phone") }.buttonStyle(.bordered)
                        }
                        if let directions = model.directionsURL(for: shop) {
                            Button { openURL(directions) } label: { Label("Directions", systemImage: "map") }.buttonStyle(.bordered)
                        }
                    }
                    .labelStyle(.titleAndIcon)
                    .font(.footnote)
                }
                .padding(.vertical, 2)
            }
            Button("Pick the nearest 3") { model.selectNearest() }
        } header: {
            Text("Which shops? (up to 3)")
        } footer: {
            Text("Local shops show MRP until they reply. Without a phone number we write an SMS text instead of a WhatsApp one.")
        }

        Section("Message language") {
            Picker("Language", selection: Bindable(model).language) {
                ForEach(MessageLanguage.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            if let first = model.candidates.first(where: { model.selected.contains($0.id) }), let preview = model.message(for: first.id) {
                Text(preview.text).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func phoneBinding(_ model: ShopAskModel, _ id: String) -> Binding<String> {
        Binding(get: { model.phones[id] ?? "" }, set: { model.phones[id] = $0 })
    }

    // MARK: After sending

    @ViewBuilder
    private func statusSections(model: ShopAskModel) -> some View {
        Section {
            ForEach(model.rows) { row in
                statusRow(row, model: model)
            }
        } header: {
            Text("Keep ready by \(model.pickupHint) · round \(model.round)")
        } footer: {
            Text(model.isDemo ? "Demo mode: no message was sent. The reply below is scripted so the flow can be shown offline." : "Shops reply on a web page. The first complete reply wins.")
        }

        if model.noReply {
            Section {
                Text("No reply in 10 min.").font(.headline)
                if !model.nextGroup.isEmpty {
                    Button("Ask next \(min(3, model.nextGroup.count))?") { model.askNext() }
                } else {
                    Text("Call a shop instead.").foregroundStyle(.secondary)
                }
            }
        }

        if model.winnerShopID != nil, !model.shopReplyOffers.isEmpty {
            Section("Saved for your plan") {
                Text("\(model.shopReplyOffers.count) price\(model.shopReplyOffers.count == 1 ? "" : "s") from this shop are ready to go into the plan.")
                    .font(.subheadline)
            }
        }
        Section { Button("Ask different shops") { model.startOver(); app.prepareShopAsk() } }
    }

    private func statusRow(_ row: ShopRow, model: ShopAskModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(row.name).font(.headline)
                Spacer()
                if row.isDemo && row.state == .replied {
                    Text("Demo reply").font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 2)
                        .background(.orange.opacity(0.25), in: Capsule())
                }
            }
            switch row.state {
            case .replied:
                Text("Replied \(rupees(row.totalPaise ?? 0)) · ready by \(row.readyBy.map(ISOTime.clock) ?? model.pickupHint)").foregroundStyle(.green)
                ForEach(row.items, id: \.itemID) { item in
                    HStack {
                        Text(app.itemName(item.itemID))
                        Spacer()
                        Text(item.available ? rupees(item.pricePaise ?? 0) : "Not available").monospacedDigit()
                    }
                    .font(.footnote)
                }
                Text(PriceSource(kind: .shopReply, dateSeen: row.repliedAt ?? Date()).label)
                    .font(.caption).padding(.horizontal, 8).padding(.vertical, 2)
                    .background(.green.opacity(0.15), in: Capsule())
            case .waiting:
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    Text(model.waitingText(for: row, now: context.date)).foregroundStyle(.secondary)
                }
                if row.link != nil || model.isDemo {
                    Button("Send message") { model.sendMessage(to: row.id) }.buttonStyle(.bordered)
                }
            case .notNeeded:
                Text("Not needed any more (another shop replied first)").foregroundStyle(.secondary)
            case .noReply:
                Text("No reply").foregroundStyle(.orange)
            case .notAsked:
                Text("Not asked yet").foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
