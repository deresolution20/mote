import AppKit
import LocalFlowCleanup
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
        case paused
        case failed(String)

        var symbolName: String {
            switch self {
            case .needsPermissions: return "mic.badge.xmark"
            case .loadingModel: return "hourglass"
            case .idle: return "mic"
            case .recording: return "mic.fill"
            case .transcribing: return "waveform"
            case .cleaning: return "sparkles"
            case .paused: return "pause.circle"
            case .failed: return "exclamationmark.triangle"
            }
        }

        var label: String {
            switch self {
            case .needsPermissions: return "Permissions needed — open Settings"
            case .loadingModel: return "Loading speech model…"
            case .idle: return "Ready — hold Left ⌥ and speak"
            case .recording: return "Recording…"
            case .transcribing: return "Transcribing…"
            case .cleaning: return "Cleaning up…"
            case .paused: return "Paused — choose Resume Dictation"
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
    /// Insert by typing (no clipboard) by default — safer on managed machines
    /// where clipboard managers / DLP tools may capture pasted content.
    @Published var injectByTyping: Bool = UserDefaults.standard.object(forKey: "injectByTyping") as? Bool ?? true {
        didSet { UserDefaults.standard.set(injectByTyping, forKey: "injectByTyping") }
    }
    /// Custom vocabulary terms, mirrored for SwiftUI binding.
    @Published var dictionaryTerms: [String] = PersonalDictionary.shared.terms

    func addDictionaryTerm(_ term: String) {
        PersonalDictionary.shared.add(term)
        dictionaryTerms = PersonalDictionary.shared.terms
    }

    func removeDictionaryTerm(_ term: String) {
        PersonalDictionary.shared.remove(term)
        dictionaryTerms = PersonalDictionary.shared.terms
    }

    private let capture = AudioCapture()
    private let transcriber = Transcriber()
    private let streamingTranscriber = StreamingTranscriber()
    private var hotkey: HotkeyMonitor?
    private var engineLoaded = false
    private var streamingLoaded = false
    private var hotkeyActive = false
    private var pauseRequested = false
    private var currentHUDTail = ""
    private var streamingSessionToken = 0
    private var acceptsStreamingPartials = false
    private var recordingWatchdog: Task<Void, Never>?
    private var streamingSetupTask: Task<Void, Never>?
    /// Longest sensible push-to-talk hold; past this the release event was lost.
    private let maxRecordingSeconds: UInt64 = 30

    private var useStreamingFinalTranscript: Bool {
        ProcessInfo.processInfo.environment["LOCALFLOW_STREAMING_FINAL"] == "1"
    }

    var allPermissionsGranted: Bool {
        micGranted && accessibilityGranted
    }

    var menuRuntimeControl: MenuRuntimeControl {
        if case .paused = status { return .resume }
        if pauseRequested { return .resume }
        if allPermissionsGranted, case .needsPermissions = status { return .start }
        guard hotkeyActive else { return .none }
        switch status {
        case .idle, .recording, .transcribing, .cleaning:
            return .pause
        case .needsPermissions, .loadingModel, .paused, .failed:
            return .none
        }
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
        guard allPermissionsGranted else {
            status = .needsPermissions
            showOnboarding()
            return
        }
        guard !hotkeyActive else { return }
        pauseRequested = false
        if !engineLoaded {
            status = .loadingModel
            if cleanupEnabled { Cleaner.warmUp() }
            do {
                try await transcriber.load()
                do {
                    try await streamingTranscriber.load()
                    streamingLoaded = true
                } catch {
                    streamingLoaded = false
                }
                engineLoaded = true
            } catch {
                status = .failed("model load failed: \(error.localizedDescription)")
                return
            }
        }

        if installHotkeyMonitor() {
            status = .idle
        } else {
            status = .failed("could not install hotkey listener — check Accessibility permission")
        }
    }

    func pauseDictation() {
        guard engineLoaded || hotkeyActive else { return }
        pauseRequested = true
        stopHotkeyMonitor()

        switch status {
        case .recording:
            recordingWatchdog?.cancel()
            _ = capture.stop()
            clearStreamingSession()
            HUDController.shared.hide()
            status = .paused
        case .idle:
            clearStreamingSession()
            status = .paused
        case .transcribing, .cleaning:
            break
        case .needsPermissions, .loadingModel, .paused, .failed:
            if engineLoaded { status = .paused }
        }
    }

    func resumeDictation() async {
        guard allPermissionsGranted else {
            status = .needsPermissions
            showOnboarding()
            return
        }
        pauseRequested = false
        if engineLoaded {
            guard !hotkeyActive else {
                if case .paused = status { status = .idle }
                return
            }
            if installHotkeyMonitor() {
                if case .paused = status { status = .idle }
            } else {
                status = .failed("could not install hotkey listener — check Accessibility permission")
            }
        } else {
            await startPipeline()
        }
    }

    private func installHotkeyMonitor() -> Bool {
        let monitor = HotkeyMonitor(
            key: .leftOption,
            onKeyDown: { [weak self] in self?.hotkeyPressed() },
            onKeyUp: { [weak self] in self?.hotkeyReleased() },
            onCancel: { [weak self] in self?.hotkeyCancelled() }
        )
        if monitor.start() {
            hotkey = monitor
            hotkeyActive = true
            return true
        } else {
            return false
        }
    }

    private func stopHotkeyMonitor() {
        hotkey?.stop()
        hotkey = nil
        hotkeyActive = false
    }

    private func hotkeyPressed() {
        // A press always clears a lingering error state.
        if case .failed = status { status = .idle }
        guard !pauseRequested else { return }
        guard case .idle = status else { return }
        let sessionToken = beginStreamingSession()
        let streamingLoaded = self.streamingLoaded
        let streamingTranscriber = self.streamingTranscriber
        if streamingLoaded {
            let setupTask = Task { [weak self] in
                await streamingTranscriber.reset()
                guard !Task.isCancelled else { return }
                let shouldInstallHandler = await MainActor.run {
                    guard let self else { return false }
                    return self.canAcceptStreamingPartials(for: sessionToken)
                }
                guard shouldInstallHandler else { return }
                await streamingTranscriber.setPartialHandler { [weak self] partial in
                    guard let self else { return }
                    guard self.canAcceptStreamingPartials(for: sessionToken) else { return }
                    let tail = HUDCaptionTail.tail(from: partial)
                    guard tail != self.currentHUDTail else { return }
                    self.currentHUDTail = tail
                    HUDController.shared.updateCaptionTail(tail)
                }
            }
            streamingSetupTask = setupTask
        }
        let setupTask = streamingSetupTask
        do {
            try capture.start(liveSamplesHandler: streamingLoaded ? { chunk in
                Task { [weak self] in
                    await setupTask?.value
                    let shouldAppend = await MainActor.run {
                        guard let self else { return false }
                        return self.canAppendStreamingSamples(for: sessionToken)
                    }
                    guard shouldAppend else { return }
                    await streamingTranscriber.append(samples: chunk)
                }
            } : nil)
            status = .recording
            HUDController.shared.show(.recording, captionTail: currentHUDTail)
            // Watchdog: if the release event is ever lost, don't record forever.
            recordingWatchdog = Task { [weak self] in
                try? await Task.sleep(nanoseconds: (self?.maxRecordingSeconds ?? 30) * 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                if case .recording = self.status { self.hotkeyReleased() }
            }
        } catch {
            invalidateStreamingSession()
            status = .failed("mic capture failed: \(error.localizedDescription)")
        }
    }

    private func hotkeyCancelled() {
        recordingWatchdog?.cancel()
        guard case .recording = status else { return }
        _ = capture.stop()
        invalidateStreamingSession()
        status = .idle
        HUDController.shared.hide()
    }

    private func hotkeyReleased() {
        recordingWatchdog?.cancel()
        guard case .recording = status else { return }
        let samples = capture.stop()
        // Ignore accidental taps: < 0.3 s of audio.
        guard samples.count > 4800 else {
            invalidateStreamingSession()
            status = pauseRequested ? .paused : .idle
            HUDController.shared.hide()
            return
        }
        let releasedHUDTail = currentHUDTail
        let setupTask = streamingSetupTask
        invalidateStreamingSession(clearHUD: false, clearTail: false)
        status = .transcribing
        HUDController.shared.show(.transcribing, captionTail: releasedHUDTail)
        let streamingFinishTask: Task<String, Never>? = streamingLoaded ? Task {
            await setupTask?.value
            return (try? await streamingTranscriber.finish()) ?? ""
        } : nil
        Task {
            defer { currentHUDTail = "" }
            do {
                let tdtHeard = try await transcriber.transcribe(samples)
                let streamingHeard = await streamingFinishTask?.value ?? ""
                let heard = useStreamingFinalTranscript && !streamingHeard.isEmpty ? streamingHeard : tdtHeard
                // Personal-dictionary correction on the raw ASR output, before cleanup.
                let raw = PersonalDictionary.shared.correct(heard)
                lastTranscript = raw
                lastCleaned = ""
                guard !raw.isEmpty else {
                    status = pauseRequested ? .paused : .idle
                    HUDController.shared.hide()
                    return
                }
                var textToPaste = raw
                if cleanupEnabled {
                    status = .cleaning
                    HUDController.shared.show(.cleaning, captionTail: releasedHUDTail)
                    // Nil = MLX unavailable/error/implausible output → paste raw.
                    if let cleaned = await Cleaner.clean(raw) {
                        lastCleaned = cleaned
                        textToPaste = cleaned
                    }
                }
                TextInjector.insert(textToPaste, method: injectByTyping ? .type : .clipboard)
                status = pauseRequested ? .paused : .idle
                HUDController.shared.finishAndHide()
            } catch {
                status = .failed("transcription failed: \(error.localizedDescription)")
                HUDController.shared.hide()
                // Recover to idle after a beat so the next attempt works.
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if case .failed = status { status = pauseRequested ? .paused : .idle }
            }
        }
    }

    private func clearStreamingSession(clearHUD: Bool = true) {
        invalidateStreamingSession(clearHUD: clearHUD)
    }

    private func beginStreamingSession() -> Int {
        currentHUDTail = ""
        streamingSetupTask?.cancel()
        streamingSetupTask = nil
        streamingSessionToken += 1
        acceptsStreamingPartials = true
        HUDController.shared.updateCaptionTail("")
        return streamingSessionToken
    }

    @discardableResult
    private func invalidateStreamingSession(clearHUD: Bool = true, clearTail: Bool = true) -> Int {
        streamingSetupTask?.cancel()
        streamingSetupTask = nil
        streamingSessionToken += 1
        let invalidatedToken = streamingSessionToken
        acceptsStreamingPartials = false
        if clearTail {
            currentHUDTail = ""
        }
        if clearHUD {
            HUDController.shared.updateCaptionTail("")
        }
        clearStreamingPartialHandlerIfStillInvalidated(invalidatedToken)
        return invalidatedToken
    }

    private func canAcceptStreamingPartials(for sessionToken: Int) -> Bool {
        sessionToken == streamingSessionToken && acceptsStreamingPartials
    }

    private func canAppendStreamingSamples(for sessionToken: Int) -> Bool {
        guard canAcceptStreamingPartials(for: sessionToken) else { return false }
        if case .recording = status {
            return true
        }
        return false
    }

    private func clearStreamingPartialHandlerIfStillInvalidated(_ invalidatedToken: Int) {
        let streamingTranscriber = self.streamingTranscriber
        Task { [weak self] in
            let shouldClear = await MainActor.run {
                guard let self else { return false }
                return self.streamingSessionToken == invalidatedToken && !self.acceptsStreamingPartials
            }
            guard shouldClear else { return }
            await streamingTranscriber.setPartialHandler(nil)
        }
    }
}
