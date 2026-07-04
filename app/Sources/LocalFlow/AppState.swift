import AppKit
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    enum Status {
        case needsPermissions
        case loadingModel
        case idle
        case recording
        case transcribing
        case cleaning
        case failed(String)

        var symbolName: String {
            switch self {
            case .needsPermissions: return "mic.badge.xmark"
            case .loadingModel: return "hourglass"
            case .idle: return "mic"
            case .recording: return "mic.fill"
            case .transcribing: return "waveform"
            case .cleaning: return "sparkles"
            case .failed: return "exclamationmark.triangle"
            }
        }

        var label: String {
            switch self {
            case .needsPermissions: return "Permissions needed — open Setup"
            case .loadingModel: return "Loading speech model…"
            case .idle: return "Ready — hold Left ⌥ and speak"
            case .recording: return "Recording…"
            case .transcribing: return "Transcribing…"
            case .cleaning: return "Cleaning up…"
            case .failed(let msg): return "Error: \(msg)"
            }
        }
    }

    @Published var status: Status = .needsPermissions
    @Published var micGranted = false
    @Published var accessibilityGranted = false
    /// Raw transcript of the last dictation — always kept, even when cleanup pasted.
    @Published var lastTranscript: String = ""
    /// What cleanup produced for the last dictation (empty if off / fell back).
    @Published var lastCleaned: String = ""
    @Published var cleanupEnabled: Bool = UserDefaults.standard.object(forKey: "cleanupEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(cleanupEnabled, forKey: "cleanupEnabled")
            if cleanupEnabled { Cleaner.warmUp() }
        }
    }
    @Published var hudEnabled: Bool = UserDefaults.standard.object(forKey: "hudEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(hudEnabled, forKey: "hudEnabled")
            if !hudEnabled { HUDController.shared.hide() }
        }
    }
    /// Minutes Ollama keeps the cleanup model resident after use (0 = unload now).
    @Published var keepAliveMinutes: Int = Cleaner.keepAliveMinutes {
        didSet {
            let clamped = max(0, keepAliveMinutes)
            if clamped != keepAliveMinutes { keepAliveMinutes = clamped; return }
            Cleaner.keepAliveMinutes = clamped
            // Re-warm so the new residency window starts from a loaded model.
            if cleanupEnabled { Cleaner.warmUp() }
        }
    }

    private let capture = AudioCapture()
    private let transcriber = Transcriber()
    private var hotkey: HotkeyMonitor?
    private var pipelineStarted = false
    private var recordingWatchdog: Task<Void, Never>?
    /// Longest sensible push-to-talk hold; past this the release event was lost.
    private let maxRecordingSeconds: UInt64 = 30

    var allPermissionsGranted: Bool {
        micGranted && accessibilityGranted
    }

    func refreshPermissions() {
        micGranted = Permissions.microphone
        accessibilityGranted = Permissions.accessibility
        if !allPermissionsGranted, case .idle = status { status = .needsPermissions }
    }

    private var onboardingWindow: NSWindow?

    func showOnboarding() {
        if onboardingWindow == nil {
            let window = NSWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false
            )
            window.title = "Local Flow Setup"
            window.contentViewController = NSHostingController(
                rootView: OnboardingView().environmentObject(self)
            )
            window.isReleasedWhenClosed = false
            window.center()
            onboardingWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }

    func startPipeline() async {
        guard !pipelineStarted else { return }
        pipelineStarted = true
        status = .loadingModel
        if cleanupEnabled { Cleaner.warmUp() }
        do {
            try await transcriber.load()
        } catch {
            status = .failed("model load failed: \(error.localizedDescription)")
            pipelineStarted = false
            return
        }

        let monitor = HotkeyMonitor(
            key: .leftOption,
            onKeyDown: { [weak self] in self?.hotkeyPressed() },
            onKeyUp: { [weak self] in self?.hotkeyReleased() },
            onCancel: { [weak self] in self?.hotkeyCancelled() }
        )
        if monitor.start() {
            hotkey = monitor
            status = .idle
        } else {
            status = .failed("could not install hotkey listener — check Accessibility permission")
            pipelineStarted = false
        }
    }

    private func hotkeyPressed() {
        // A press always clears a lingering error state.
        if case .failed = status { status = .idle }
        guard case .idle = status else { return }
        do {
            try capture.start()
            status = .recording
            HUDController.shared.show(.recording)
            // Watchdog: if the release event is ever lost, don't record forever.
            recordingWatchdog = Task { [weak self] in
                try? await Task.sleep(nanoseconds: (self?.maxRecordingSeconds ?? 30) * 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                if case .recording = self.status { self.hotkeyReleased() }
            }
        } catch {
            status = .failed("mic capture failed: \(error.localizedDescription)")
        }
    }

    private func hotkeyCancelled() {
        recordingWatchdog?.cancel()
        guard case .recording = status else { return }
        _ = capture.stop()
        status = .idle
        HUDController.shared.hide()
    }

    private func hotkeyReleased() {
        recordingWatchdog?.cancel()
        guard case .recording = status else { return }
        let samples = capture.stop()
        // Ignore accidental taps: < 0.3 s of audio.
        guard samples.count > 4800 else {
            status = .idle
            HUDController.shared.hide()
            return
        }
        status = .transcribing
        HUDController.shared.show(.transcribing)
        Task {
            do {
                let raw = try await transcriber.transcribe(samples)
                lastTranscript = raw
                lastCleaned = ""
                guard !raw.isEmpty else {
                    status = .idle
                    HUDController.shared.hide()
                    return
                }
                var textToPaste = raw
                if cleanupEnabled {
                    status = .cleaning
                    HUDController.shared.show(.cleaning)
                    // Nil = Ollama down/slow/implausible output → paste raw.
                    if let cleaned = await Cleaner.clean(raw) {
                        lastCleaned = cleaned
                        textToPaste = cleaned
                    }
                }
                TextInjector.paste(textToPaste)
                status = .idle
                HUDController.shared.finishAndHide()
            } catch {
                status = .failed("transcription failed: \(error.localizedDescription)")
                HUDController.shared.hide()
                // Recover to idle after a beat so the next attempt works.
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if case .failed = status { status = .idle }
            }
        }
    }
}
