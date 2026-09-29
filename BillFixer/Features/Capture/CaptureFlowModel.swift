import OSLog
import PhotosUI
import SwiftUI
import Observation

enum CaptureSource: String, Identifiable, CaseIterable {
    case camera, photos, pdf
    var id: String { rawValue }
}

enum DocKind: String, Hashable { case bill, eob }

enum CaptureStep: Hashable {
    case pages(DocKind)
    case reviewBill
    case eobPrompt
    case reviewEOB
    case context
    case analysis(String)
}

/// Owns everything captured in one "scan a bill" session. Images live only in memory and are dropped
/// when the flow closes (AGENTS.md privacy: delete temporary processing files after use).
@MainActor
@Observable
final class CaptureFlowModel {
    var path: [CaptureStep] = []
    var kind: DocKind = .bill

    var billPages: [UIImage] = []
    var eobPages: [UIImage] = []
    var billSource: CaptureSource = .camera
    var eobSource: CaptureSource = .camera
    private var billPDF: Data?
    private var eobPDF: Data?

    var billDraft = BillDraft()
    var eobDraft: EOBDraft?
    private var billOCRConfidence: Double?
    private var eobOCRConfidence: Double?

    // Context questions
    var wasEmergency: Bool?
    var hasInsurance: Bool? = true
    var outOfNetwork: Bool?
    var householdSize = 1
    var annualIncome = ""
    var state = ""

    var isProcessing = false
    var processingProgress: Double = 0
    var isSubmitting = false
    var submitStage = ""
    var needsPremium = false
    private var createdCaseId: String?

    private let services: AppServices
    init(services: AppServices) { self.services = services }

    var pages: [UIImage] { kind == .bill ? billPages : eobPages }

    // MARK: Import

    func addImages(_ images: [UIImage], source: CaptureSource) {
        guard !images.isEmpty else { return }
        let capped = images.prefix(max(0, 20 - pages.count)).map { $0.downscaled(maxDimension: 2600) }
        if kind == .bill {
            billPages += capped
            billSource = source
            billPDF = nil
        } else {
            eobPages += capped
            eobSource = source
            eobPDF = nil
        }
        if images.count > capped.count { Toast.warning("Up to 20 pages per document") }
        Haptics.scanComplete()
        if path.last != .pages(kind) { path.append(.pages(kind)) }
    }

    func loadPhotos(_ items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) { images.append(image) }
        }
        if images.isEmpty { Toast.error("Couldn’t load those photos", "Try choosing them again."); return }
        addImages(images, source: .photos)
    }

    func importPDF(_ url: URL) async {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), data.count < 40_000_000 else {
            Toast.error("Couldn’t open that PDF", "Files must be under 40 MB.")
            return
        }
        isProcessing = true
        defer { isProcessing = false }
        do {
            let (_, previews) = try await OCRService.recognize(pdf: data)
            if kind == .bill { billPages = previews; billPDF = data; billSource = .pdf } else { eobPages = previews; eobPDF = data; eobSource = .pdf }
            Haptics.scanComplete()
            if path.last != .pages(kind) { path.append(.pages(kind)) }
        } catch {
            Toast.error("Couldn’t read that PDF", error.localizedDescription)
        }
    }

    func removePage(at index: Int) {
        if kind == .bill { if billPages.indices.contains(index) { billPages.remove(at: index); billPDF = nil } }
        else if eobPages.indices.contains(index) { eobPages.remove(at: index); eobPDF = nil }
        Haptics.tapLight()
    }

    // MARK: OCR

    /// On-device OCR + deterministic parse, then on to the review screen.
    func extract() async {
        let kind = self.kind
        let images = kind == .bill ? billPages : eobPages
        let pdf = kind == .bill ? billPDF : eobPDF
        guard !images.isEmpty else { return }
        isProcessing = true
        processingProgress = 0
        defer { isProcessing = false }
        do {
            let result: OCRResult
            if let pdf {
                result = try await OCRService.recognize(pdf: pdf).0
            } else {
                result = try await OCRService.recognize(images: images) { p in Task { @MainActor in self.processingProgress = p } }
            }
            AppLog.capture.info("OCR complete: \(result.rows.count, privacy: .public) rows, text layer \(result.usedTextLayer, privacy: .public)")
            if kind == .bill {
                billDraft = BillParser.parse(result)
                billOCRConfidence = result.averageConfidence
                path.append(.reviewBill)
            } else {
                var eob = EOBParser.parse(result)
                if eob.providerName.isEmpty { eob.providerName = billDraft.providerName }
                eobDraft = eob
                eobOCRConfidence = result.averageConfidence
                path.append(.reviewEOB)
            }
            Haptics.success()
        } catch is CancellationError {
        } catch {
            Toast.error("We couldn’t read this document", error.localizedDescription)
        }
    }

    func startEOBCapture() { kind = .eob }

    func skipEOB(uninsured: Bool = false) {
        eobDraft = nil
        eobPages = []
        if uninsured { hasInsurance = false }
        kind = .bill
        path.append(.context)
    }

    // MARK: Submit

    var contextError: String? {
        if !annualIncome.isEmpty, Money(parsing: annualIncome) == nil { return "Enter income like 42000" }
        if let e = Validation.stateCode(state) { return e }
        return nil
    }

    func submit() async {
        if let e = billDraft.validationError { Toast.warning("Check your bill details", e); return }
        if let e = contextError { Toast.warning("Check your answers", e); return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let caseId: String
            if let existing = createdCaseId {
                caseId = existing
            } else {
                submitStage = "Creating your case…"
                caseId = try await services.cases.create(title: String(billDraft.providerName.trimmed.prefix(120)),
                                                         billDate: billDraft.billDate.map(DateHelpers.dayString), serviceType: nil)
                createdCaseId = caseId
            }
            submitStage = "Saving bill details…"
            let billDoc = try await services.cases.addDocument(caseId, CreateDocumentRequest(
                type: "bill", source: billSource.rawValue, pageCount: max(billPages.count, 1),
                ocrConfidence: billOCRConfidence.map { min(max($0, 0), 1) }, sha256: nil))
            try await services.cases.submitBill(caseId, billDraft.submission(documentId: billDoc))

            if let eob = eobDraft {
                submitStage = "Saving EOB…"
                let eobDoc = try await services.cases.addDocument(caseId, CreateDocumentRequest(
                    type: "eob", source: eobSource.rawValue, pageCount: max(eobPages.count, 1),
                    ocrConfidence: eobOCRConfidence.map { min(max($0, 0), 1) }, sha256: nil))
                try await services.cases.submitEOB(caseId, eob.submission(documentId: eobDoc))
            }

            submitStage = "Starting analysis…"
            var context = AnalysisContext()
            context.wasEmergency = wasEmergency
            context.hasInsurance = hasInsurance
            context.outOfNetwork = outOfNetwork ?? (eobDraft?.networkStatus == .outOfNetwork ? true : nil)
            context.householdSize = householdSize
            context.annualIncome = Money(parsing: annualIncome)?.magnitude
            context.state = state.isEmpty ? nil : state.uppercased()
            _ = try await services.analysis.start(caseId, context: context)

            // Documents are no longer needed: drop the images from memory.
            billPages = []
            eobPages = []
            billPDF = nil
            eobPDF = nil
            path.append(.analysis(caseId))
        } catch let error as APIError {
            if case .premiumRequired = error { needsPremium = true } else { Toast.error(error) }
        } catch {
            Toast.error(error)
        }
    }
}

extension UIImage {
    func downscaled(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}
