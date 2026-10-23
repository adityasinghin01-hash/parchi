import CoreGraphics
import Foundation

/// One piece of text Apple Vision found, with where it is on the page.
/// `rect` is Vision's normalised box: 0...1, origin at the BOTTOM-left of the image.
struct OCRBox: Equatable {
    let text: String
    let rect: CGRect
    let confidence: Float
}

/// Several boxes that sit on the same printed row, left to right.
struct TextLine: Equatable {
    let boxes: [OCRBox]
    var text: String { boxes.map(\.text).joined(separator: " ") }
    var rect: CGRect { boxes.dropFirst().reduce(boxes[0].rect) { $0.union($1.rect) } }
    /// Largest horizontal gap between two neighbouring boxes, in line-heights (0 for a single box).
    let widestGap: CGFloat
}

/// Puts Vision's boxes back into rows: top to bottom, left to right.
/// Two boxes belong to the same row when they overlap vertically by at least half of the smaller box
/// AND the empty space between them is not wider than `maxGap` line-heights. The second rule keeps a
/// side column (complaints, BP) from being glued onto the medicine line next to it.
enum LineGrouper {
    /// `aspect` = image width / height in pixels, so that horizontal gaps can be compared with line heights.
    static func group(_ boxes: [OCRBox], aspect: CGFloat = 1, maxGap: CGFloat = 4.0) -> [TextLine] {
        let items = boxes.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty && $0.rect.height > 0 }
            .sorted { $0.rect.minX < $1.rect.minX }
        guard !items.isEmpty else { return [] }

        var parent = Array(0..<items.count)
        func find(_ i: Int) -> Int {
            var i = i
            while parent[i] != i { parent[i] = parent[parent[i]]; i = parent[i] }
            return i
        }
        for i in 0..<items.count {
            for j in (i + 1)..<max(i + 1, items.count) where sameRow(items[i].rect, items[j].rect, aspect: aspect, maxGap: maxGap) {
                parent[find(j)] = find(i)
            }
        }
        var groups: [Int: [OCRBox]] = [:]
        for (i, box) in items.enumerated() { groups[find(i), default: []].append(box) }

        let lines: [TextLine] = groups.values.map { members in
            let ordered = members.sorted { $0.rect.minX < $1.rect.minX }
            var widest: CGFloat = 0
            for (a, b) in zip(ordered, ordered.dropFirst()) { widest = max(widest, gap(a.rect, b.rect, aspect: aspect)) }
            return TextLine(boxes: ordered, widestGap: widest)
        }
        return lines.sorted {
            let (ya, yb) = ($0.rect.midY, $1.rect.midY)
            if abs(ya - yb) > 0.0005 { return ya > yb }     // Vision's y grows upwards: larger = higher on the page
            return $0.rect.minX < $1.rect.minX
        }
    }

    /// Horizontal empty space between two boxes, measured in heights of the smaller box (0 when they overlap).
    static func gap(_ a: CGRect, _ b: CGRect, aspect: CGFloat) -> CGFloat {
        let space = max(0, max(a.minX, b.minX) - min(a.maxX, b.maxX))
        return space * aspect / max(min(a.height, b.height), 0.0001)
    }

    static func sameRow(_ a: CGRect, _ b: CGRect, aspect: CGFloat, maxGap: CGFloat) -> Bool {
        let overlap = min(a.maxY, b.maxY) - max(a.minY, b.minY)
        guard overlap > 0, overlap / min(a.height, b.height) >= 0.5 else { return false }
        return gap(a, b, aspect: aspect) <= maxGap
    }
}
