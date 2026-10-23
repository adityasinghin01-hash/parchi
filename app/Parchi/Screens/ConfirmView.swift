import ParchiCore
import SwiftUI

struct ConfirmView: View {
    @Environment(AppModel.self) private var model
    @Binding var path: [Route]
    @State private var showAddMedicine = false
    @State private var showAddTest = false

    var body: some View {
        List {
            Section("Medicines") {
                ForEach(model.lines.filter { $0.item.kind == .medicine }) { line in
                    LineRow(line: line)
                }
            }
            Section("Tests") {
                ForEach(model.lines.filter { $0.item.kind == .test }) { line in
                    TestRow(line: line)
                }
            }
            // K18: a handwritten parchi the reader cannot read can be typed in.
            Section {
                if model.lines.isEmpty {
                    Text("Nothing on the list yet. Add the medicines and tests written on your parchi.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button { showAddMedicine = true } label: {
                    Label("Add a medicine", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityLabel("Add a medicine")
                .accessibilityIdentifier("addMedicine")
                Button { showAddTest = true } label: {
                    Label("Add a test", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityLabel("Add a test")
                .accessibilityIdentifier("addTest")
            }
        }
        .navigationTitle("Did we read it right?")
        .sheet(isPresented: $showAddMedicine) { AddMedicineSheet() }
        .sheet(isPresented: $showAddTest) { AddTestSheet() }
        .safeAreaInset(edge: .bottom) {
            Button {
                model.confirmList()
                path.append(.plan)
            } label: {
                Text(model.lines.isEmpty ? "Add a medicine or test first" : model.allConfirmed ? "All correct" : "Answer the highlighted line")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.lines.isEmpty || !model.allConfirmed)
            .padding()
            .background(.bar)
        }
    }
}

/// "Remove <name>": the line's menu entry and its swipe action share this, so both say the same thing to VoiceOver.
private struct RemoveLineActions: ViewModifier {
    @Environment(AppModel.self) private var model
    let line: ReadLine
    let title: String

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) { model.removeManualLine(line.id) } label: { Text("Remove") }
                    .accessibilityLabel("Remove \(title)")
            }
    }
}

private struct LineMenu: View {
    @Environment(AppModel.self) private var model
    let line: ReadLine
    let title: String

    var body: some View {
        Menu {
            Button(role: .destructive) { model.removeManualLine(line.id) } label: { Label("Remove", systemImage: "trash") }
                .accessibilityLabel("Remove \(title)")
        } label: {
            Image(systemName: "ellipsis.circle")
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Options for \(title)")
    }
}

private struct LineRow: View {
    @Environment(AppModel.self) private var model
    let line: ReadLine
    private var title: String { [line.item.name, line.item.strength].compactMap { $0 }.joined(separator: " ") }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "pills")
                    .accessibilityHidden(true)
                Text(title)
                    .font(.body.weight(.semibold))
                Spacer()
                if !line.needsAnswer {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        .accessibilityLabel("Confirmed")
                }
                LineMenu(line: line, title: title)
            }
            if case let .strengthMismatch(brand, read, available)? = line.check {
                Text("\(brand.capitalized) \(read) doesn't exist. It comes in \(available.joined(separator: " / ")). Which one?")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                HStack {
                    ForEach(available, id: \.self) { strength in
                        Button(strength) { model.choose(strength: strength, for: line.id) }
                            .buttonStyle(.bordered)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }
            }
            if case let .unknownBrand(read, suggestions)? = line.check {
                Text("We couldn't find \"\(read)\". Did you mean \(suggestions.joined(separator: ", "))?")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
            if let schedule = line.inPersonOnly {
                Label(schedule.inPersonMessage, systemImage: "person.badge.shield.checkmark")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(line.needsAnswer ? Color.orange.opacity(0.12) : nil)
        .modifier(RemoveLineActions(line: line, title: title))
    }
}

/// A test line: exact match is a plain row; ambiguous asks "Which test?" (never guessed); unknown says so and keeps the written name.
private struct TestRow: View {
    @Environment(AppModel.self) private var model
    let line: ReadLine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(line.item.name, systemImage: "testtube.2")
                    .font(.body.weight(.semibold))
                Spacer()
                if !line.needsAnswer {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        .accessibilityLabel("Confirmed")
                }
                LineMenu(line: line, title: line.item.name)
            }
            if case let .ambiguous(names)? = line.testMatch {
                Text(line.askDoctor ? "Left out of your plan. Ask your doctor which test they meant." : "Which test?")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                ForEach(names, id: \.self) { name in
                    Button(name) { model.choose(test: name, for: line.id) }
                        .buttonStyle(.bordered)
                        .frame(minHeight: 44)
                }
                if !line.askDoctor {
                    Button("Ask my doctor") { model.askDoctorAbout(testLine: line.id) }
                        .buttonStyle(.bordered)
                        .frame(minHeight: 44)
                }
            } else if case .unknown? = line.testMatch {
                Text("We could not match this test")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(line.needsAnswer ? Color.orange.opacity(0.12) : nil)
        .modifier(RemoveLineActions(line: line, title: line.item.name))
    }
}
