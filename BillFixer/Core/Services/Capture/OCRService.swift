import CoreGraphics
import Foundation
import PDFKit
import UIKit
import Vision

/// On-device text recognition (ADR-002). Images never leave the phone.
nonisolated enum OCRService {
    enum OCRError: LocalizedError {
        case noText, unreadablePDF
        var errorDescription: String? {
            switch self {
            case .noText: "We couldn’t read any text. Try better lighting or a flatter page."
            case .unreadablePDF: "This PDF couldn’t be opened. It may be password protected."
            }
        }
    }

    /// Runs Vision on a background thread (`@concurrent`) so scanning never blocks the UI.
    @concurrent
    static func recognize(images: [UIImage], progress: (@Sendable (Double) -> Void)? = nil) async throws -> OCRResult {
        var rows: [OCRRow] = []
        for (index, image) in images.enumerated() {
            try Task.checkCancellation()
            guard let cg = image.normalizedCGImage() else { continue }
            let boxes = try recognizeBoxes(cg)
            rows += RowGrouper.rows(from: boxes, page: index)
            progress?(Double(index + 1) / Double(max(images.count, 1)))
        }
        let result = OCRResult(rows: rows, pageCount: images.count, usedTextLayer: false)
        if result.isEmpty { throw OCRError.noText }
        return result
    }

    private static func recognizeBoxes(_ image: CGImage) throws -> [OCRBox] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false        // codes and amounts must not be "corrected"
        request.recognitionLanguages = ["en-US"]
        request.minimumTextHeight = 0.008
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return (request.results ?? []).compactMap { obs in
            guard let top = obs.topCandidates(1).first else { return nil }
            return OCRBox(text: top.string, confidence: Double(top.confidence), box: obs.boundingBox)
        }
    }

    /// Digital PDFs: use the embedded text layer (exact). Scanned PDFs: render pages and OCR them.
    @concurrent
    static func recognize(pdf data: Data, progress: (@Sendable (Double) -> Void)? = nil) async throws -> (OCRResult, [UIImage]) {
        guard let doc = PDFDocument(data: data), !doc.isLocked, doc.pageCount > 0 else { throw OCRError.unreadablePDF }
        let pageCount = min(doc.pageCount, 30)
        var textRows: [OCRRow] = []
        var previews: [UIImage] = []
        for i in 0..<pageCount {
            guard let page = doc.page(at: i) else { continue }
            previews.append(page.thumbnail(of: CGSize(width: 900, height: 1200), for: .mediaBox))
            let lines = (page.string ?? "").components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            textRows += lines.map { OCRRow(text: $0, confidence: 1, page: i) }
        }
        let characters = textRows.reduce(0) { $0 + $1.text.count }
        if characters >= 60 * pageCount {   // real text layer, not just a header/footer
            return (OCRResult(rows: textRows, pageCount: pageCount, usedTextLayer: true), previews)
        }
        let rendered = (0..<pageCount).compactMap { doc.page(at: $0)?.thumbnail(of: CGSize(width: 1700, height: 2200), for: .mediaBox) }
        return (try await recognize(images: rendered, progress: progress), previews)
    }
}

extension UIImage {
    /// CGImage with orientation applied, downscaled to ≤ 2600px — enough for Vision, bounded memory.
    nonisolated func normalizedCGImage(maxDimension: CGFloat = 2600) -> CGImage? {
        let scale = min(1, maxDimension / max(size.width, size.height))
        if imageOrientation == .up, scale >= 1, let cg = cgImage { return cg }
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }.cgImage
    }
}
