import SwiftUI

/// Screen 11 — polls the server-side analysis job and shows each deterministic step completing.
struct AnalysisProgressView: View {
    let caseId: String
    let onDone: () -> Void
    @Environment(\.services) private var services
    @State private var steps: [JobStep] = AnalysisProgressView.defaultSteps
    @State private var progress: Double = 0
    @State private var failed: APIError?
    @State private var finished = false
    @State private var attempt = 0

    static let defaultSteps = [
        ("read", "Reading your bill…"), ("arithmetic", "Checking the math…"), ("duplicates", "Finding duplicate charges…"),
        ("eob_reconcile", "Comparing with your EOB…"), ("pricing", "Looking up hospital prices…"), ("rights", "Checking your rights…"),
        ("explain", "Building your action plan…"),
    ].map { JobStep(key: $0.0, label: $0.1, status: .pending) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text(finished ? "Analysis Complete" : "Analyzing Your Bill").font(BFFont.title(28)).foregroundStyle(BFColor.text1)
                    .contentTransition(.opacity)
                ProgressView(value: progress).tint(BFColor.teal).animation(BFMotion.smooth, value: progress)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.key) { i, step in
                    stepRow(step, isLast: i == steps.count - 1)
                }
            }
            .cardStyle(padding: 18, radius: 22)

            if let failed {
                VStack(spacing: 10) {
                    Text(failed.message).font(BFFont.subheadline).foregroundStyle(BFColor.text2).multilineTextAlignment(.center)
                    BFButton(title: "Try Again", icon: "arrow.clockwise", kind: .navy) { self.failed = nil; attempt += 1 }
                    BFButton(title: "View Case", kind: .outline) { onDone() }
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "clock.fill").foregroundStyle(BFColor.blue)
                    Text("This usually takes 30–60 seconds. You can leave — your results will be waiting in Cases.")
                        .font(.system(size: 14)).foregroundStyle(BFColor.text2)
                }
                .cardStyle(padding: 14, radius: 16, fill: BFColor.blueSoft, shadow: nil)
            }
            Spacer()
        }
        .padding(BFSpacing.screen)
        .scenicBackground(.analysis)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Close") { onDone() } }
        }
        .task(id: attempt) { await run() }
    }

    private func stepRow(_ step: JobStep, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(step.status == .complete ? BFColor.green : step.status == .failed ? BFColor.red : step.status == .running ? BFColor.blue : BFColor.line)
                        .frame(width: 26, height: 26)
                    if step.status == .running {
                        ProgressView().controlSize(.mini).tint(.white)
                    } else if step.status != .pending {
                        Image(systemName: step.status == .failed ? "xmark" : "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                if !isLast { Rectangle().fill(step.status == .complete ? BFColor.green.opacity(0.5) : BFColor.line).frame(width: 2, height: 22) }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(step.label.replacingOccurrences(of: "…", with: "")).font(.system(size: 15, weight: step.status == .running ? .semibold : .medium))
                    .foregroundStyle(step.status == .pending ? BFColor.text3 : BFColor.text1)
                Text(step.status == .complete ? "Completed" : step.status == .running ? "In progress…" : step.status == .failed ? "Skipped" : "")
                    .font(.system(size: 12)).foregroundStyle(step.status == .complete ? BFColor.green : BFColor.blue)
            }
            Spacer()
        }
        .animation(BFMotion.gentle, value: step.status)
        .accessibilityElement(children: .combine)
    }

    private func run() async {
        let started = ContinuousClock.now
        do {
            let final = try await JobPoller.wait(fetch: { try await services.analysis.status(caseId) }) { status in
                if !status.steps.isEmpty { steps = status.steps }
                progress = status.progress
            }
            let elapsed = ContinuousClock.now - started
            if elapsed < AppConfig.minimumAnalysisDisplay { try? await Task.sleep(for: AppConfig.minimumAnalysisDisplay - elapsed) }
            if final.status == "complete" {
                withAnimation(BFMotion.gentle) {
                    steps = steps.map { JobStep(key: $0.key, label: $0.label, status: $0.status == .failed ? .failed : .complete) }
                    progress = 1
                    finished = true
                }
                Haptics.success()
                try? await Task.sleep(for: .milliseconds(700))
                onDone()
            } else {
                failed = .server(status: 500, code: final.errorCode ?? "ANALYSIS_FAILED", message: "The analysis couldn’t finish. Your case is saved — try again.")
                Haptics.error()
            }
        } catch {
            let e = error.asAPIError
            if e != .cancelled { failed = e; Haptics.error() }
        }
    }
}
