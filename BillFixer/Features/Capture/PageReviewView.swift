import SwiftUI

/// Screen 09 — review pages before reading them.
struct PageReviewView: View {
    @Bindable var model: CaptureFlowModel
    let kind: DocKind
    @State private var selected = 0
    @State private var addMore: CaptureSource?
    @State private var showAddSheet = false

    private var pages: [UIImage] { kind == .bill ? model.billPages : model.eobPages }

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(kind == .bill ? "Review Your Document" : "Review Your EOB").font(BFFont.title(26)).foregroundStyle(BFColor.text1)
                Text(pages.isEmpty ? "No pages" : "Page \(min(selected, pages.count - 1) + 1) of \(pages.count)")
                    .font(BFFont.subheadline).foregroundStyle(BFColor.text2).contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TabView(selection: $selected) {
                ForEach(Array(pages.enumerated()), id: \.offset) { i, page in
                    Image(uiImage: page).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .bfShadow(.float)
                        .padding(.horizontal, 6)
                        .tag(i)
                        .accessibilityLabel("Page \(i + 1)")
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: .infinity)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { i, page in
                        Button { withAnimation(BFMotion.snappy) { selected = i } } label: {
                            Image(uiImage: page).resizable().scaledToFill().frame(width: 54, height: 70).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(i == selected ? BFColor.blue : BFColor.line, lineWidth: i == selected ? 2.5 : 1))
                        }
                        .buttonStyle(.pressableQuiet)
                    }
                    if pages.count < 20 {
                        Button { showAddSheet = true } label: {
                            Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundStyle(BFColor.blue)
                                .frame(width: 54, height: 70)
                                .background(BFColor.blueSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .accessibilityLabel("Add pages")
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 12) {
                BFButton(title: "Remove", icon: "trash", kind: .outline, size: .lg, isDisabled: pages.isEmpty, fullWidth: false) {
                    model.removePage(at: selected)
                    selected = max(0, min(selected, pages.count - 2))
                    if (kind == .bill ? model.billPages : model.eobPages).isEmpty { model.path.removeLast() }
                }
                BFButton(title: "Continue", trailingIcon: "arrow.right", kind: .navy, isLoading: model.isProcessing, isDisabled: pages.isEmpty) {
                    model.kind = kind
                    Task { await model.extract() }
                }
            }
        }
        .padding(BFSpacing.screen)
        .scenicBackground(.capture)
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if model.isProcessing { ProcessingOverlay(progress: model.processingProgress) } }
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                SourcePicker(model: model, autoStart: $addMore).padding(20)
                    .navigationTitle("Add pages").navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
        .onChange(of: pages.count) { old, new in if new > old { showAddSheet = false; selected = new - 1 } }
    }
}

/// "Reading your document" — shown while Vision runs.
struct ProcessingOverlay: View {
    let progress: Double
    @State private var sweep = false

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18).fill(BFColor.surface).frame(width: 120, height: 150).bfShadow(.float)
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(0..<6, id: \.self) { i in Capsule().fill(BFColor.line).frame(width: [80, 60, 86, 50, 74, 64][i], height: 7) }
                    }
                    Rectangle()
                        .fill(LinearGradient(colors: [BFColor.teal.opacity(0), BFColor.teal.opacity(0.55), BFColor.teal.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 120, height: 30)
                        .offset(y: sweep ? 60 : -60)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
                Text("Reading your document…").font(BFFont.title3()).foregroundStyle(BFColor.text1)
                ProgressView(value: max(progress, 0.05)).tint(BFColor.teal).frame(width: 200).animation(BFMotion.standard, value: progress)
                Text("On your iPhone — nothing is uploaded").font(.system(size: 13)).foregroundStyle(BFColor.text3)
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { sweep = true } }
        .accessibilityElement(children: .combine)
    }
}
