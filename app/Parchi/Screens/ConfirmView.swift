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
                    Label(line.item.name, systemImage: "testtube.2")
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
        }
        .padding(.vertical, 4)
        .listRowBackground(line.needsAnswer ? Color.orange.opacity(0.12) : nil)
    }
}
