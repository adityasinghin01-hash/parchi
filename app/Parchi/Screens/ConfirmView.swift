import ParchiCore
import SwiftUI

struct ConfirmView: View {
    @Environment(AppModel.self) private var model
    @Binding var path: [Route]

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
        }
        .navigationTitle("Did we read it right?")
        .safeAreaInset(edge: .bottom) {
            Button {
                model.confirmList()
                path.append(.plan)
            } label: {
                Text(model.allConfirmed ? "All correct" : "Answer the highlighted line")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.allConfirmed)
            .padding()
            .background(.bar)
        }
    }
}

private struct LineRow: View {
    @Environment(AppModel.self) private var model
    let line: ReadLine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "pills")
                    .accessibilityHidden(true)
                Text([line.item.name, line.item.strength].compactMap { $0 }.joined(separator: " "))
                    .font(.body.weight(.semibold))
                Spacer()
                if !line.needsAnswer {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        .accessibilityLabel("Confirmed")
                }
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
    }
}
