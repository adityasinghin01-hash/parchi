import ParchiCore
import SwiftUI

/// Plain, functional lab-booking sheet (teammates restyle it later).
struct LabBookingView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let model = app.labBooking
        NavigationStack {
            List {
                if model.phase == .booked {
                    bookedSections(model: model)
                } else {
                    chooseSections(model: model)
                }
                if let error = model.error {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange).font(.subheadline) }
                }
            }
            .navigationTitle("Book lab tests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                if model.phase != .booked {
                    Button { model.book() } label: {
                        Text(model.phase == .booking ? "Booking…" : "Request booking · \(rupees(model.selectedTotal))")
                            .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canBook)
                    .padding()
                    .background(.bar)
                }
            }
        }
        .onAppear {
            app.prepareLabBooking()
            model.resumePolling()
            // Screenshot aids: `-demoBook 1` presses Request booking; `-demoSchedule 1` presses Add to Calendar once confirmed.
            if UserDefaults.standard.bool(forKey: "demoBook"), model.phase == .choosing { model.book() }
        }
        .onChange(of: model.bookings) { _, bookings in
            guard UserDefaults.standard.bool(forKey: "demoSchedule") else { return }
            for booking in bookings where booking.isConfirmed && booking.calendarResult == nil && booking.slot != nil {
                Task { await model.addToCalendarAndRemind(booking.id) }
            }
        }
    }

    // MARK: Choosing

    @ViewBuilder
    private func chooseSections(model: LabBookingModel) -> some View {
        Section {
            Picker("City", selection: Bindable(model).city) {
                ForEach(LabBookingModel.cities, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
        } footer: {
            Text("Cheapest lab first. Prices are from lab websites on 23 Oct 2026; the lab confirms the final fee.")
        }

        Section("Preferred time") {
            Picker("Day", selection: Bindable(model).dayOffset) {
                ForEach(Array(model.dayChoices.enumerated()), id: \.offset) { index, day in
                    Text(ISOTime.format(day, "EEE d MMM")).tag(index + 1)
                }
            }
            .pickerStyle(.segmented)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                ForEach(LabBookingModel.hours, id: \.self) { hour in
                    Button { model.hour = hour } label: {
                        Text(LabBookingModel.hourText(hour)).frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.bordered)
                    .tint(model.hour == hour ? .accentColor : .gray)
                }
            }
            Text("Preferred: \(ISOTime.slot(model.preferredSlot)). The lab confirms or proposes another time.").font(.footnote).foregroundStyle(.secondary)
        }

        ForEach(model.tests) { row in
            Section {
                if row.choices.isEmpty {
                    Text("No lab price known for this test.").foregroundStyle(.secondary)
                }
                ForEach(row.choices) { choice in
                    Button { model.select(lab: choice.id, for: row.id) } label: {
                        HStack(alignment: .top) {
                            Image(systemName: model.chosenLab[row.id] == choice.id ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(model.chosenLab[row.id] == choice.id ? Color.accentColor : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(choice.name).foregroundStyle(.primary)
                                Text(choice.homeText + (choice.reportMinutes.map { " · report \(readyText(minutes: $0))" } ?? ""))
                                    .font(.footnote).foregroundStyle(.secondary)
                                Text(choice.source.datedLabel).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(rupees(choice.pricePaise)).monospacedDigit().foregroundStyle(.primary)
                                if choice.feePaise > 0 { Text("+ \(rupees(choice.feePaise)) fee").font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                }
                fastingRow(row, model: model)
            } header: {
                Text(row.name)
            }
        }

        Section {
            Toggle("Collect the sample at home", isOn: Bindable(model).wantsHome)
            if model.wantsHome {
                TextField("Home address", text: Bindable(model.address).text, axis: .vertical)
                    .lineLimit(2...4)
            }
        } header: {
            Text("Home collection")
        } footer: {
            Text("Your address is saved on this phone only and is sent to the lab with the booking. Do not type your name or phone number here.")
        }
    }

    @ViewBuilder
    private func fastingRow(_ row: LabTestRow, model: LabBookingModel) -> some View {
        switch row.fasting {
        case .required:
            Label("Fasting needed for this test", systemImage: "fork.knife")
        case .notRequired:
            Label("No fasting needed", systemImage: "checkmark.circle").foregroundStyle(.secondary)
        case .unknown:
            Toggle(isOn: Binding(get: { model.toldToFast.contains(row.id) }, set: { model.setToldToFast($0, for: row.id) })) {
                VStack(alignment: .leading) {
                    Text("My lab told me to fast")
                    Text("Fasting for this test is not known to us. Only turn this on if the lab or doctor said so.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Booked

    @ViewBuilder
    private func bookedSections(model: LabBookingModel) -> some View {
        ForEach(model.bookings) { booking in
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(booking.labName).font(.headline)
                        Spacer()
                        if booking.isDemo && booking.isConfirmed {
                            Text("Demo reply").font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 2)
                                .background(.orange.opacity(0.25), in: Capsule())
                        }
                    }
                    Text(booking.testNames.joined(separator: ", ")).font(.subheadline).foregroundStyle(.secondary)
                    Text(booking.homeCollection ? "Home collection" : "Visit the lab").font(.footnote).foregroundStyle(.secondary)
                    statusLine(booking)
                }
                .padding(.vertical, 2)

                if booking.isConfirmed, booking.slot != nil {
                    if let result = booking.calendarResult {
                        Label(result, systemImage: "calendar.badge.checkmark").font(.footnote)
                    }
                    if let result = booking.reminderResult {
                        Label(result, systemImage: "bell").font(.footnote)
                    } else if let fireAt = booking.fastingReminderAt {
                        Label("Fasting reminder will be set for \(ISOTime.slot(fireAt))", systemImage: "bell").font(.footnote)
                    }
                    if booking.calendarResult == nil {
                        Button("Add to Calendar and set reminder") { Task { await model.addToCalendarAndRemind(booking.id) } }
                            .buttonStyle(.borderedProminent)
                    }
                }
                if !booking.isDemo, !booking.isConfirmed, let text = model.requestText(for: booking) {
                    ShareLink(item: text) { Label("Send this request to the lab", systemImage: "square.and.arrow.up") }
                }
                if let note = booking.note { Text(note).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        Section {
            if !model.isDemo { Button("Refresh") { model.refresh() } }
            Button("Book other tests") { model.startOver(); app.prepareLabBooking() }
        } footer: {
            Text(model.isDemo ? "Demo mode: no lab was contacted. The confirmation is scripted so the flow can be shown offline." : "The lab confirms on a web page. Parchi never books or pays for you.")
        }
    }

    @ViewBuilder
    private func statusLine(_ booking: LabBookingState) -> some View {
        switch booking.state {
        case "requested":
            if booking.noReply { Label("No reply in 30 min. Call the lab instead?", systemImage: "phone").foregroundStyle(.orange) }
            else { Label("Waiting for the lab to confirm · preferred \(ISOTime.slot(booking.requestedSlot))", systemImage: "hourglass").foregroundStyle(.secondary) }
        case "rejected":
            Label("The lab cannot do this slot.", systemImage: "xmark.circle").foregroundStyle(.red)
        case "expired":
            Label("This booking was closed because nothing happened for a week. Book again if you still need it.", systemImage: "clock.badge.xmark").foregroundStyle(.secondary)
        case "report_chase_due":
            VStack(alignment: .leading, spacing: 2) {
                Label("Your report was due. Call the lab to ask for it.", systemImage: "phone.arrow.up.right").foregroundStyle(.orange)
                if let slot = booking.slot { Text("Collected around \(ISOTime.slot(slot))").font(.footnote).foregroundStyle(.secondary) }
            }
        default:
            VStack(alignment: .leading, spacing: 2) {
                Label("Confirmed \(booking.slot.map(ISOTime.slot) ?? "")", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                if let fee = booking.feePaise { Text("Fee \(rupees(fee))").font(.footnote) }
            }
        }
    }
}
