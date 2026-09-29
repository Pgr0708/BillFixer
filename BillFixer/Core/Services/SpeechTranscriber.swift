import AVFoundation
import Speech

/// Voice → text for call notes. Audio is streamed straight into Apple's recognizer and never saved or sent to
/// our server; recognition stays on the iPhone whenever the on-device model is available.
@Observable
final class SpeechTranscriber {
    private(set) var isRecording = false
    /// Text heard since the last `start()`; updates live while speaking.
    private(set) var transcript = ""
    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    enum Failure: LocalizedError {
        case denied, unavailable
        var errorDescription: String? {
            switch self {
            case .denied: "Allow Microphone and Speech Recognition for BillFixer in Settings to dictate notes."
            case .unavailable: "Voice typing isn’t available right now. Please try again or type your note."
            }
        }
    }

    func start() async throws {
        guard !isRecording else { return }
        guard await Self.authorize() else { throw Failure.denied }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), recognizer.isAvailable else { throw Failure.unavailable }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }

        let engine = AVAudioEngine()
        Self.installTap(on: engine.inputNode, feeding: request)
        engine.prepare()
        do { try engine.start() } catch { engine.inputNode.removeTap(onBus: 0); throw error }

        transcript = ""
        self.engine = engine
        self.request = request
        task = Self.recognize(recognizer, request) { [weak self] text, done in
            Task { @MainActor in
                guard let self else { return }
                if let text { self.transcript = text }
                if done { self.stop(); self.task = nil }
            }
        }
        isRecording = true
    }

    /// Stops listening; the recognizer still delivers its final text for what was already said.
    func stop() {
        guard let engine else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        self.engine = nil
        request = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Stops and throws away any pending result (sheet dismissed).
    func cancel() {
        stop()
        task?.cancel()
        task = nil
    }

    // Audio and recognizer callbacks run on background threads, so they must not be MainActor-isolated.

    nonisolated private static func authorize() async -> Bool {
        let speech = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    nonisolated private static func installTap(on node: AVAudioInputNode, feeding request: SFSpeechAudioBufferRecognitionRequest) {
        nonisolated(unsafe) let request = request
        node.installTap(onBus: 0, bufferSize: 1024, format: node.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
    }

    nonisolated private static func recognize(_ recognizer: SFSpeechRecognizer, _ request: SFSpeechAudioBufferRecognitionRequest,
                                              onUpdate: @escaping @Sendable (String?, Bool) -> Void) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            onUpdate(result?.bestTranscription.formattedString, error != nil || (result?.isFinal ?? false))
        }
    }
}
