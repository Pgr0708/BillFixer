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
            option(.camera, "camera", "Take a Photo", "Scan with your camera", [0x6FA8FF, 0x2468FF])
                .staggeredAppear(1)
            option(.photos, "photo", "Import from Photos", "Choose existing photos", [0xB3A0FF, 0x7C5CFF])
                .staggeredAppear(2)
            option(.pdf, "doc", "Import PDF", "From Files, Mail or other apps", [0xFF8A7A, 0xE5484D])
                .staggeredAppear(3)
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

    /// Board 07 row: bold gradient circle icon, title, subtitle, chevron.
    private func option(_ source: CaptureSource, _ symbol: String, _ title: String, _ subtitle: String, _ colors: [UInt32]) -> some View {
        Button { open(source) } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(LinearGradient(colors: colors.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1.5))
                    .shadow(color: Color(hex: colors[1]).opacity(0.4), radius: 8, y: 4)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(BFColor.text1)
                    Text(subtitle).font(.system(size: 14)).foregroundStyle(BFColor.text3)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(BFColor.text4)
            }
            .cardStyle(padding: 16, radius: 22)
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
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
                HStack {
                    Spacer()
                    IconButton(symbol: "xmark", label: "Close", action: onClose)
                }
                VStack(spacing: 6) {
                    Text("Add Your Document").font(BFFont.title(28)).foregroundStyle(BFColor.text1)
                    Text("Upload your medical bill or EOB").font(BFFont.body).foregroundStyle(BFColor.text3)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .staggeredAppear(0)
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

    /// Board 07 tip card with the girl-with-phone vector on a circle.
    private var tipCard: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What should I upload?").font(BFFont.title3(17)).foregroundStyle(BFColor.text1)
                Text("Your medical bill, your EOB, or both. Having both gives you the most accurate analysis.")
                    .font(.system(size: 14)).foregroundStyle(BFColor.text2).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 20)
            Spacer(minLength: 0)
            Image("GirlPhone")
                .resizable()
                .scaledToFit()
                .frame(width: 104, height: 112)
                .floating(amplitude: 3, duration: 3.2)
                .accessibilityHidden(true)
        }
        .padding(.leading, 20)
        .padding(.trailing, 12)
        .background {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(BFColor.blueSoft)
                Circle().fill(BFColor.surface.opacity(0.55)).frame(width: 170).offset(x: 40, y: -30)
                Circle().strokeBorder(BFColor.blue.opacity(0.2), lineWidth: 1.5).frame(width: 120).offset(x: 10, y: 40)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .staggeredAppear(4)
    }
}
