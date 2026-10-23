import Foundation
import ParchiCore

/// K18: add / remove a line by hand on the Confirm screen, through the existing model API only.
///
/// `AppModel.lines` cannot be edited from another file, so every change rebuilds the whole list with `loadReaderLines` from the
/// current lines plus or minus the change. Each line keeps its name, strength, quantity and kind; ids are renumbered (r1, r2...).
/// "Ask my doctor" on a test is put back after the rebuild with `askDoctorAbout`. A strength or test the patient already chose
/// is kept because it is part of the line (`choose(strength:)` / `choose(test:)` edit the line itself).
/// What does NOT survive: the demo basket's own ids ("dolo", "telma"...), so once a demo-parchi line is added or removed the
/// remaining demo lines are priced from the catalogue MRP instead of the demo scenario prices (see KIRO_REPORT_K18.md).
extension AppModel {
    /// The most tablets / units one typed line may have. The shop-ask server rejects a quantity above 999 (422), so the Add sheet,
    /// the clamp below and the ask body all use this number.
    static let maxManualQuantity = 999

    /// The current lines as the reader would have returned them, and which of them the patient left to the doctor.
    private func manualSnapshot() -> (lines: [ReaderLine], askDoctor: [Bool]) {
        (lines.map { line in
            ReaderLine(kind: line.item.kind == .test ? "test" : "medicine", name: line.item.name, strength: line.item.strength,
                       quantity: line.item.quantity, schedule: nil)
        }, lines.map(\.askDoctor))
    }

    /// True when every id is r1, r2... (a list from the reader or an earlier rebuild); false for the demo parchi's own ids.
    private var linesAreReaderLines: Bool {
        lines.allSatisfy { $0.id.hasPrefix("r") && Int($0.id.dropFirst()) != nil }
    }

    private func manualRebuild(_ read: [ReaderLine], askDoctor: [Bool]) {
        let unresolvedRows = readerNeedsHelp
        loadReaderLines(read)
        readerNeedsHelp = unresolvedRows
        for (index, asked) in askDoctor.enumerated() where asked && index < lines.count {
            askDoctorAbout(testLine: lines[index].id)
        }
    }

    /// The strengths to offer for a brand: the ones in the price catalogue, and (when the Confirm screen's own strength list
    /// knows the brand) only those it also accepts, so a pick never lands on "this strength doesn't exist". Never invented.
    func manualStrengthChoices(brand: String, index: ManualBrandIndex) -> [String] {
        let priced = index.strengths(brand: brand)
        guard let known = catalogue.strengths[ManualBrandIndex.key(for: brand)] else { return priced }
        let both = priced.filter(known.contains)
        return both.isEmpty ? priced : both
    }

    /// Adds a medicine at the end. `strength` is the number ("650") or nil; `quantity` is clamped to 1...999 (the server rejects more than 999 in a shop ask).
    func addManualMedicine(name: String, strength: String?, quantity: Int) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let cleanStrength = strength?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = (cleanStrength?.isEmpty ?? true) ? nil : cleanStrength
        if !linesAreReaderLines {   // the demo parchi: keep its ids so its own prices still apply
            appendLine(RxItem(id: "m" + UUID().uuidString.prefix(8), kind: .medicine, name: trimmed, strength: cleaned, quantity: min(max(quantity, 1), Self.maxManualQuantity)))
            return
        }
        var (read, asked) = manualSnapshot()
        read.append(ReaderLine(kind: "medicine", name: trimmed, strength: cleaned,
                               quantity: min(max(quantity, 1), Self.maxManualQuantity), schedule: nil))
        asked.append(false)
        manualRebuild(read, askDoctor: asked)
    }

    /// Adds a test by its canonical name; the usual test-matching rules apply to it.
    func addManualTest(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !linesAreReaderLines {
            appendLine(RxItem(id: "m" + UUID().uuidString.prefix(8), kind: .test, name: trimmed))
            return
        }
        var (read, asked) = manualSnapshot()
        read.append(ReaderLine(kind: "test", name: trimmed, strength: nil, quantity: nil, schedule: nil))
        asked.append(false)
        manualRebuild(read, askDoctor: asked)
    }

    /// Removes one line (by its current id). Unknown ids do nothing.
    func removeManualLine(_ lineID: String) {
        guard let index = lines.firstIndex(where: { $0.id == lineID }) else { return }
        if !linesAreReaderLines { removeLine(lineID); return }
        var (read, asked) = manualSnapshot()
        read.remove(at: index)
        asked.remove(at: index)
        manualRebuild(read, askDoctor: asked)
    }
}
