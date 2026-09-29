import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Full-screen capture flow. Screen 07 (options) is the root; everything else is pushed.
struct CaptureFlowView: View {
    var initialSource: CaptureSource?
    let onClose: (String?) -> Void

    @Environment(\.services) private var services
    @Environment(AppSession.self) private var session
    @State private var model: CaptureFlowModel?
    @State private var confirmClose = false

    var body: some View {
        Group {
            if let model {
                FlowContent(model: model, initialSource: initialSource, onClose: attemptClose, onFinish: { onClose($0) })
            } else {
                Color.clear
            }
        }
        .onAppear { if model == nil { model = CaptureFlowModel(services: services) } }
        .confirmationDialog("Discard this scan?", isPresented: $confirmClose, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { onClose(nil) }
            Button("Keep Editing", role: .cancel) {}
        } message: { Text("The pages and details you’ve entered will be removed.") }
        .sheet(isPresented: Binding(get: { model?.needsPremium == true }, set: { model?.needsPremium = $0 })) {
            PaywallScreenView(reason: .cases) {
                model?.needsPremium = false
                Task { await session.syncSubscription(); await model?.submit() }
            }
        }
    }

    private func attemptClose() {
        guard let model else { return onClose(nil) }
        if model.path.contains(where: { if case .analysis = $0 { true } else { false } }) { return }
        if model.billPages.isEmpty && model.path.isEmpty { onClose(nil) } else { confirmClose = true }
    }
}

private struct FlowContent: View {
    @Bindable var model: CaptureFlowModel
    let initialSource: CaptureSource?
    let onClose: () -> Void
    let onFinish: (String?) -> Void

    var body: some View {
        NavigationStack(path: $model.path) {
            CaptureOptionsView(model: model, initialSource: initialSource, onClose: onClose)
                .navigationDestination(for: CaptureStep.self) { step in
                    switch step {
                    case let .pages(kind): PageReviewView(model: model, kind: kind)
                    case .reviewBill: BillReviewView(model: model)
                    case .eobPrompt: EOBPromptView(model: model)
                    case .reviewEOB: EOBReviewView(model: model)
                    case .context: ContextQuestionsView(model: model)
                    case let .analysis(caseId): AnalysisProgressView(caseId: caseId) { onFinish(caseId) }
                    }
                }
        }
        .interactiveDismissDisabled()
    }
}

/// Source picker used for both the bill (screen 07) and the EOB.
struct SourcePicker: View {
    @Bindable var model: CaptureFlowModel
    @Binding var autoStart: CaptureSource?
    @State private var showScanner = false
    @State private var showPhotos = false
    @State private var showFiles = false
    @State private var photoItems: [PhotosPickerItem] = []

    var body: some View {
        VStack(spacing: 12) {
            option(.camera, "camera.fill", "Take a Photo", "Scan with your camera", BFColor.blue, BFColor.blueSoft)
            option(.photos, "photo.on.rectangle.angled", "Import from Photos", "Choose existing photos", BFColor.teal, BFColor.tealSoft)
            option(.pdf, "doc.fill", "Import PDF", "From Files, Mail or other apps", BFColor.violet, BFColor.violetSoft)
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScannerView { images in
                showScanner = false
                model.addImages(images, source: .camera)
            } onCancel: { showScanner = false }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showPhotos, selection: $photoItems, maxSelectionCount: 20, matching: .images)
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await model.loadPhotos(items); photoItems = [] }
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf]) { result in
            switch result {
            case let .success(url): Task { await model.importPDF(url) }
            case let .failure(error): Toast.error("Couldn’t open file", error.localizedDescription)
            }
        }
        .onAppear {
            if let s = autoStart { autoStart = nil; open(s) }
        }
    }

    private func option(_ source: CaptureSource, _ symbol: String, _ title: String, _ subtitle: String, _ tint: Color, _ fill: Color) -> some View {
        Button { open(source) } label: { ActionRow(symbol: symbol, title: title, subtitle: subtitle, tint: tint, fill: fill) }
            .buttonStyle(.pressable)
    }

    private func open(_ source: CaptureSource) {
        Haptics.tap()
        switch source {
        case .camera:
            if DocumentScannerView.isAvailable { showScanner = true } else { Toast.warning("Camera isn’t available", "Import a photo or PDF instead.") }
        case .photos: showPhotos = true
        case .pdf: showFiles = true
        }
    }
}

/// Screen 07.
struct CaptureOptionsView: View {
    @Bindable var model: CaptureFlowModel
    @State var initialSource: CaptureSource?
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Add Your Document").font(BFFont.title(28)).foregroundStyle(BFColor.text1)
                        Text("Upload your medical bill or EOB").font(BFFont.body).foregroundStyle(BFColor.text2)
                    }
                    Spacer()
                    IconButton(symbol: "xmark", label: "Close", action: onClose)
                }
                SourcePicker(model: model, autoStart: $initialSource)
                tipCard
                Label("Your documents are read on this iPhone. Images are never uploaded.", systemImage: "lock.shield.fill")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(BFColor.text3)
            }
            .padding(BFSpacing.screen)
        }
        .scenicBackground(.capture)
        .toolbar(.hidden, for: .navigationBar)
        .loadingOverlay(model.isProcessing, "Opening document…")
    }

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What should I upload?").font(BFFont.title3(17)).foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 5) {
                    tip("An itemized bill works best")
                    tip("Include every page")
                    tip("Add your EOB from your insurer next")
                }
            }
            Spacer()
            Image(systemName: "doc.text.magnifyingglass").font(.system(size: 46, weight: .light)).foregroundStyle(.white.opacity(0.85))
        }
        .padding(18)
        .background(BFGradient.blue, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .bfShadow(.navyButton)
    }

    private func tip(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.92))
    }
}
