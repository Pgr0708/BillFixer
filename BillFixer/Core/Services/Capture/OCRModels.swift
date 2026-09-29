import CoreGraphics
import Foundation

/// One visual row of text (Vision observations on the same baseline joined left→right).
nonisolated struct OCRRow: Sendable, Hashable {
    let text: String
    let confidence: Double
    let page: Int
}

nonisolated struct OCRResult: Sendable {
    let rows: [OCRRow]
    let pageCount: Int
    let usedTextLayer: Bool

    var averageConfidence: Double {
        guard !rows.isEmpty else { return 0 }
        return rows.map(\.confidence).reduce(0, +) / Double(rows.count)
    }
    var isEmpty: Bool { rows.allSatisfy { $0.text.trimmingCharacters(in: .whitespaces).isEmpty } }
}

/// A recognized word box before row grouping (normalized Vision coordinates, origin bottom-left).
nonisolated struct OCRBox: Sendable {
    let text: String
    let confidence: Double
    let box: CGRect
}

nonisolated enum RowGrouper {
    /// Groups boxes into rows by vertical overlap, then orders each row left→right.
    static func rows(from boxes: [OCRBox], page: Int) -> [OCRRow] {
        let sorted = boxes.sorted { $0.box.midY > $1.box.midY }
        var groups: [[OCRBox]] = []
        for b in sorted {
            if let last = groups.last?.last,
               abs(last.box.midY - b.box.midY) < max(min(last.box.height, b.box.height) * 0.5, 0.004) {
                groups[groups.count - 1].append(b)
            } else {
                groups.append([b])
            }
        }
        return groups.map { g in
            let ordered = g.sorted { $0.box.minX < $1.box.minX }
            let text = ordered.map(\.text).joined(separator: "  ")
            let conf = ordered.map(\.confidence).reduce(0, +) / Double(ordered.count)
            return OCRRow(text: text, confidence: conf, page: page)
        }
    }
}
