import UIKit

/// Renders a letter to a US-Letter PDF (1" margins, serif body) for Share / Print / Files.
enum LetterPDF {
    static func render(subject: String?, body: String, fileName: String) throws -> URL {
        let formatter = UISimpleTextPrintFormatter(attributedText: attributed(subject: subject, body: body))
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        renderer.setValue(page, forKey: "paperRect")
        renderer.setValue(page.insetBy(dx: 72, dy: 72), forKey: "printableRect")

        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, page, [kCGPDFContextCreator as String: "Bill Fixer"])
        for i in 0..<max(renderer.numberOfPages, 1) {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()

        let safe = fileName.replacingOccurrences(of: #"[^A-Za-z0-9 _-]"#, with: "", options: .regularExpression)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe.isEmpty ? "Letter" : safe).pdf")
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    private static func attributed(subject: String?, body: String) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 3
        para.paragraphSpacing = 8
        if let subject, !subject.isEmpty {
            out.append(NSAttributedString(string: "\(subject)\n\n", attributes: [
                .font: UIFont(name: BFFontName.serifBold, size: 13) ?? .boldSystemFont(ofSize: 13), .paragraphStyle: para]))
        }
        out.append(NSAttributedString(string: body, attributes: [
            .font: UIFont(name: "Georgia", size: 11.5) ?? .systemFont(ofSize: 11.5), .paragraphStyle: para, .foregroundColor: UIColor.black]))
        return out
    }
}
