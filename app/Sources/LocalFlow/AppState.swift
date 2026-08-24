import AppKit
import LocalFlowCleanup
import OSLog
import SwiftUI

private let streamingLatencyLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "dev.brice.localflow",
    category: "StreamingLatency"
)

private final class StreamingAppendSerialQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var activeToken: Int?
    private var acceptsEnqueues = false
    private var tail: Task<Void, Never>?

    func startSession(token: Int) {
        lock.lock()
        activeToken = token
        acceptsEnqueues = true
        tail = nil
        lock.unlock()
    }

    func enqueue(for token: Int, _ operation: @escaping @Sendable () async -> Void) {
        lock.lock()
        guard activeToken == token, acceptsEnqueues else {
            lock.unlock()
            return
        }

        let previousTail = tail
        let task = Task { [weak self] in
            await previousTail?.value
            guard let self, self.isActive(token: token) else { return }
            await operation()
        }
        tail = task
        lock.unlock()
    }

    func freeze(token: Int) {
        lock.lock()
        if activeToken == token {
            acceptsEnqueues = false
        }
        lock.unlock()
    }

    func invalidate(token: Int) {
        lock.lock()
        if activeToken == token {
            activeToken = nil
            acceptsEnqueues = false
        }
        tail = nil
        lock.unlock()
    }

    func waitForDrain(token: Int) async {
        let task = drainTask(for: token)
        await task?.value
    }

    private func isActive(token: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeToken == token
    }

    private func drainTask(for token: Int) -> Task<Void, Never>? {
        lock.lock()
        defer { lock.unlock() }
        return activeToken == token ? tail : nil
    }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    enum Status {
        case needsPermissions
        case needsModelDownloadApproval
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
            case .needsModelDownloadApproval: return "arrow.down.circle"
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
            case .needsModelDownloadApproval: return "Approve local model download to start"
            case .loadingModel: return "Loading speech model…"
            case .idle: return "Ready — use your configured hotkey"
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
    @Published var pendingDictation: PendingDictation?
    let historyStore = HistoryStore()
    let snippetStore = SnippetStore()
    let microphoneDeviceService = MicrophoneDeviceService()

    private let preferences = GrotdownPreferences()
    private let outputDeliveryCoordinator = OutputDeliveryCoordinator()

    @Published var outputFormat: OutputFormat = .plain {
        didSet { preferences.outputFormat = outputFormat }
    }
    @Published var captureMode: CaptureMode = .holdToTalk {
        didSet {
            preferences.captureMode = captureMode
            reconfigureHotkeyIfIdle()
        }
    }
    @Published var hotkeyConfiguration: HotkeyConfiguration = .default {
        didSet {
            preferences.hotkeyConfiguration = hotkeyConfiguration
            reconfigureHotkeyIfIdle()
        }
    }
    @Published var autoInsert = false {
        didSet { preferences.autoInsert = autoInsert }
    }
    /// Explicit consent is required before any local model artifact is fetched.
    @Published var modelDownloadsApproved = false {
        didSet {
            preferences.modelDownloadsApproved = modelDownloadsApproved
            if !modelDownloadsApproved {
                streamingWarmupTask?.cancel()
                streamingWarmupTask = nil
            }
        }
    }
    @Published var preserveCodeAndBackticks = false {
        didSet { preferences.preserveCodeAndBackticks = preserveCodeAndBackticks }
    }
    @Published var selectedMicrophoneDeviceID: UInt32? {
        didSet { preferences.selectedMicrophoneDeviceID = selectedMicrophoneDeviceID }
    }
    @Published var cleanupEnabled = true {
        didSet {
            preferences.cleanupEnabled = cleanupEnabled
            if cleanupEnabled, modelDownloadsApproved { Cleaner.warmUp() }
        }
    }
    @Published var hudEnabled = true {
        didSet {
            preferences.hudEnabled = hudEnabled
            if !hudEnabled { HUDController.shared.hide() }
        }
    }
    /// Insert by typing (no clipboard) by default — safer on managed machines
    /// where clipboard managers / DLP tools may capture pasted content.
    @Published var injectByTyping = true {
        didSet { preferences.injectByTyping = injectByTyping }
    }
    /// Custom vocabulary terms, mirrored for SwiftUI binding.
    @Published var dictionaryTerms: [String] = PersonalDictionary.shared.terms

    init() {
        outputFormat = preferences.outputFormat
        captureMode = preferences.captureMode
        hotkeyConfiguration = preferences.hotkeyConfiguration
        autoInsert = preferences.autoInsert
        modelDownloadsApproved = preferences.modelDownloadsApproved
        preserveCodeAndBackticks = preferences.preserveCodeAndBackticks
        cleanupEnabled = preferences.cleanupEnabled
        hudEnabled = preferences.hudEnabled
        injectByTyping = preferences.injectByTyping
        selectedMicrophoneDeviceID = preferences.selectedMicrophoneDeviceID
    }

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
    private let streamingAppendQueue = StreamingAppendSerialQueue()
    private var hotkeyActive = false
    private var pauseRequested = false
    private var currentHUDTail = ""
    private var streamingSessionToken = 0
    private var streamingSessionFailed = false
    private var acceptsStreamingPartials = false
    private var recordingWatchdog: Task<Void, Never>?
    private var streamingSetupTask: Task<Void, Never>?
    private var streamingWarmupTask: Task<Void, Never>?
    private var hasLoggedFirstHUDPartial = false
    private var captureOutputFormat: OutputFormat = .plain
    private var capturePreserveCodeAndBackticks = false
    /// Longest sensible push-to-talk hold; past this the release event was lost.
    private let maxRecordingSeconds: UInt64 = 30

    private var injectionMethod: TextInjector.Method {
        injectByTyping ? .type : .clipboard
    }

    private var useStreamingFinalTranscript: Bool {
        ProcessInfo.processInfo.environment["LOCALFLOW_STREAMING_FINAL"] == "1"
    }

    var allPermissionsGranted: Bool {
        micGranted && accessibilityGranted
    }

    var menuRuntimeControl: MenuRuntimeControl {
        if case .paused = status { return .resume }
        if pauseRequested { return .resume }
        if allPermissionsGranted {
            if case .needsPermissions = status { return .start }
            if case .needsModelDownloadApproval = status { return .start }
        }
        guard hotkeyActive else { return .none }
        switch status {
        case .idle, .recording, .transcribing, .cleaning:
            return .pause
        case .needsPermissions, .needsModelDownloadApproval, .loadingModel, .paused, .failed:
            return .none
        }
    }

    func refreshPermissions() {
        micGranted = Permissions.microphone
        accessibilityGranted = Permissions.accessibility
        if !allPermissionsGranted, case .idle = status { status = .needsPermissions }
    }

    func refreshMicrophoneDevices() {
        microphoneDeviceService.refresh()
    }

    private var onboardingWindow: NSWindow?

    func showOnboarding() {
        if onboardingWindow == nil {
            let window = NSWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false
            )
            window.title = "Grotdown Setup"
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
        guard modelDownloadsApproved else {
            status = .needsModelDownloadApproval
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
                guard modelDownloadsApproved else {
                    status = .needsModelDownloadApproval
                    return
                }
                engineLoaded = true
            } catch {
                status = .failed("model load failed: \(error.localizedDescription)")
                return
            }
        }
        // Off the critical path: dictation is usable via TDT as soon as the
        // hotkey installs; streaming captions switch on when warmup finishes.
        ensureStreamingWarmedUp()

        if installHotkeyMonitor() {
            status = .idle
        } else {
            status = .failed("could not install hotkey listener — check Accessibility permission")
        }
    }

    /// Loads and warms the streaming model without blocking dictation readiness.
    /// Safe to call on every pipeline start/resume: it retries after a failed
    /// attempt, never runs two attempts concurrently, and sessions fall back to
    /// TDT-only until it succeeds.
    private func ensureStreamingWarmedUp() {
        guard modelDownloadsApproved else { return }
        guard !streamingLoaded, streamingWarmupTask == nil else { return }
        let streamingTranscriber = self.streamingTranscriber
        streamingWarmupTask = Task { [weak self] in
            defer { self?.streamingWarmupTask = nil }
            guard self?.modelDownloadsApproved == true else { return }
            do {
                try await streamingTranscriber.load()
            } catch {
                streamingLatencyLogger.error(
                    "Streaming model load failed; continuing with TDT: \(error.localizedDescription, privacy: .public)"
                )
                return
            }
            do {
                guard self?.modelDownloadsApproved == true else { return }
                let warmupStartedAt = ProcessInfo.processInfo.systemUptime
                try await streamingTranscriber.warmUp()
                let warmupMilliseconds = Int(
                    (ProcessInfo.processInfo.systemUptime - warmupStartedAt) * 1_000
                )
                streamingLatencyLogger.info(
                    "Streaming warmup completed in \(warmupMilliseconds, privacy: .public) ms"
                )
                self?.streamingLoaded = true
            } catch {
                streamingLatencyLogger.error(
                    "Streaming warmup failed; continuing with TDT: \(error.localizedDescription, privacy: .public)"
                )
            }
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
            microphoneDeviceService.resetLevel()
            clearStreamingSession()
            HUDController.shared.hide()
            status = .paused
        case .idle:
            clearStreamingSession()
            status = .paused
        case .transcribing, .cleaning:
            break
        case .needsPermissions, .needsModelDownloadApproval, .loadingModel, .paused, .failed:
            if engineLoaded { status = .paused }
        }
    }

    func resumeDictation() async {
        guard allPermissionsGranted else {
            status = .needsPermissions
            showOnboarding()
            return
        }
        guard modelDownloadsApproved else {
            status = .needsModelDownloadApproval
            showOnboarding()
            return
        }
        pauseRequested = false
        if engineLoaded {
            ensureStreamingWarmedUp()
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

    func approveModelDownloadsAndStartPipeline() async {
        modelDownloadsApproved = true
        await startPipeline()
    }

    private func installHotkeyMonitor() -> Bool {
        let monitor = HotkeyMonitor(
            configuration: hotkeyConfiguration,
            mode: captureMode,
            onBeginCapture: { [weak self] in self?.hotkeyPressed() },
            onEndCapture: { [weak self] in self?.hotkeyReleased() },
            onCancelCapture: { [weak self] in self?.hotkeyCancelled() }
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

    private func reconfigureHotkeyIfIdle() {
        guard hotkeyActive, case .idle = status else { return }
        stopHotkeyMonitor()
        if !installHotkeyMonitor() {
            status = .failed("could not register \(hotkeyConfiguration.displayName)")
        }
    }

    private func hotkeyPressed() {
        // A press always clears a lingering error state.
        if case .failed = status { status = .idle }
        guard !pauseRequested else { return }
        guard case .idle = status else { return }
        captureOutputFormat = outputFormat
        capturePreserveCodeAndBackticks = preserveCodeAndBackticks
        let sessionToken = beginStreamingSession()
        let sessionStartedAt = ProcessInfo.processInfo.systemUptime
        streamingLatencyLogger.info("Streaming session \(sessionToken, privacy: .public) started")
        let streamingLoaded = self.streamingLoaded
        let streamingAppendQueue = self.streamingAppendQueue
        let streamingTranscriber = self.streamingTranscriber
        if streamingLoaded {
            let setupTask = Task { [weak self] in
                await streamingTranscriber.reset()
                let hasFailed = await streamingTranscriber.hasFailedCurrentSession
                guard !Task.isCancelled else { return }
                if hasFailed {
                    await MainActor.run {
                        self?.markStreamingSessionFailed(sessionToken)
                    }
                    return
                }
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
                    if !self.hasLoggedFirstHUDPartial, !tail.isEmpty {
                        self.hasLoggedFirstHUDPartial = true
                        let elapsedMilliseconds = Int(
                            (ProcessInfo.processInfo.systemUptime - sessionStartedAt) * 1_000
                        )
                        streamingLatencyLogger.info(
                            "Session \(sessionToken, privacy: .public) first HUD partial at \(elapsedMilliseconds, privacy: .public) ms"
                        )
                    }
                    self.currentHUDTail = tail
                    HUDController.shared.updateCaptionTail(tail)
                }
            }
            streamingSetupTask = setupTask
        }
        let setupTask = streamingSetupTask
        var streamedSampleCount = 0
        do {
            microphoneDeviceService.refresh()
            let deviceID = microphoneDeviceService.resolvedDeviceID(preferred: selectedMicrophoneDeviceID)
            try capture.start(deviceID: deviceID, liveSamplesHandler: streamingLoaded ? { chunk in
                let chunkReceivedAt = ProcessInfo.processInfo.systemUptime
                let previousSampleCount = streamedSampleCount
                streamedSampleCount += chunk.count
                let isFirstChunk = previousSampleCount == 0
                let chunkSamples = StreamingHUDLatencyTuning.streamingModelChunkSamples
                let crossesFirstInferenceBoundary =
                    previousSampleCount < chunkSamples && streamedSampleCount >= chunkSamples
                if isFirstChunk {
                    let elapsedMilliseconds = Int((chunkReceivedAt - sessionStartedAt) * 1_000)
                    streamingLatencyLogger.info(
                        "Session \(sessionToken, privacy: .public) first microphone chunk at \(elapsedMilliseconds, privacy: .public) ms (\(chunk.count, privacy: .public) samples)"
                    )
                }
                streamingAppendQueue.enqueue(for: sessionToken) { [weak self] in
                    await setupTask?.value
                    guard let self else { return }
                    let shouldAppend = await MainActor.run {
                        self.canRunStreamingAppend(for: sessionToken)
                    }
                    guard shouldAppend else { return }
                    let inferenceRan = await streamingTranscriber.append(samples: chunk)
                    if inferenceRan, crossesFirstInferenceBoundary {
                        let elapsedMilliseconds = Int(
                            (ProcessInfo.processInfo.systemUptime - sessionStartedAt) * 1_000
                        )
                        streamingLatencyLogger.info(
                            "Session \(sessionToken, privacy: .public) first inference completed at \(elapsedMilliseconds, privacy: .public) ms"
                        )
                    }
                    let hasFailed = await streamingTranscriber.hasFailedCurrentSession
                    if hasFailed {
                        await MainActor.run {
                            self.markStreamingSessionFailed(sessionToken)
                        }
                    }
                }
            } : nil, levelHandler: { [weak self] level in
                Task { @MainActor [weak self] in
                    self?.microphoneDeviceService.updateLevel(level)
                }
            })
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
            microphoneDeviceService.resetLevel()
            status = .failed("mic capture failed: \(error.localizedDescription)")
        }
    }

    private func hotkeyCancelled() {
        recordingWatchdog?.cancel()
        guard case .recording = status else { return }
        _ = capture.stop()
        microphoneDeviceService.resetLevel()
        invalidateStreamingSession()
        status = .idle
        HUDController.shared.hide()
    }

    private func hotkeyReleased() {
        recordingWatchdog?.cancel()
        guard case .recording = status else { return }
        let samples = capture.stop()
        microphoneDeviceService.resetLevel()
        // Ignore accidental taps: < 0.3 s of audio.
        guard samples.count > 4800 else {
            invalidateStreamingSession()
            status = pauseRequested ? .paused : .idle
            HUDController.shared.hide()
            return
        }
        let sessionToken = streamingSessionToken
        let releasedHUDTail = currentHUDTail
        let setupTask = streamingSetupTask
        let streamingAppendQueue = self.streamingAppendQueue
        let streamingTranscriber = self.streamingTranscriber
        freezeStreamingSessionForRelease(sessionToken)
        status = .transcribing
        HUDController.shared.show(
            .transcribing,
            captionTail: hudCaptionTailForReleasedSession(releasedHUDTail, token: sessionToken)
        )
        let streamingFinishTask: Task<String, Never>? = streamingLoaded ? Task { [weak self] in
            await setupTask?.value
            await streamingAppendQueue.waitForDrain(token: sessionToken)
            let shouldFinish = await MainActor.run {
                guard let self else { return false }
                return self.canRunStreamingAppend(for: sessionToken)
            }
            guard shouldFinish else { return "" }
            return (try? await streamingTranscriber.finish()) ?? ""
        } : nil
        Task {
            defer {
                currentHUDTail = ""
                clearStreamingSession()
            }
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
                if cleanupEnabled, modelDownloadsApproved {
                    status = .cleaning
                    HUDController.shared.show(
                        .cleaning,
                        captionTail: hudCaptionTailForReleasedSession(releasedHUDTail, token: sessionToken)
                    )
                    // Nil = MLX unavailable/error/implausible output → paste raw.
                    if let cleaned = await Cleaner.clean(raw) {
                        lastCleaned = cleaned
                        textToPaste = cleaned
                    }
                }
                let completion = await outputDeliveryCoordinator.complete(
                    raw: raw,
                    cleaned: textToPaste,
                    format: captureOutputFormat,
                    formattingOptions: FormattingOptions(
                        preserveCodeAndBackticks: capturePreserveCodeAndBackticks
                    ),
                    autoInsert: autoInsert,
                    method: injectionMethod,
                    duration: Double(samples.count) / 16_000
                )
                historyStore.append(completion.record)
                pendingDictation = completion.pending
                lastCleaned = completion.record.finalText
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

    func insertPending() {
        guard let pendingDictation else { return }
        let delivery = outputDeliveryCoordinator.insert(pendingDictation, method: injectionMethod)
        historyStore.updateOutcome(for: pendingDictation.id, to: delivery.insertionOutcome)
        self.pendingDictation = nil
    }

    func copyPending() {
        guard let pendingDictation else { return }
        let delivery = outputDeliveryCoordinator.copy(pendingDictation)
        historyStore.updateOutcome(for: pendingDictation.id, to: delivery.insertionOutcome)
        self.pendingDictation = nil
    }

    func setPendingFormat(_ format: OutputFormat) {
        guard let pending = pendingDictation else { return }
        Task { [weak self] in
            guard let self else { return }
            let resolved = await outputDeliveryCoordinator.resolve(
                pending,
                format: format,
                options: FormattingOptions(preserveCodeAndBackticks: preserveCodeAndBackticks)
            )
            guard pendingDictation?.id == resolved.id else { return }
            pendingDictation = resolved
            guard let existing = historyStore.records.first(where: { $0.id == resolved.id }) else { return }
            historyStore.replace(
                DictationRecord(
                    id: existing.id,
                    createdAt: existing.createdAt,
                    duration: existing.duration,
                    rawText: existing.rawText,
                    finalText: resolved.resolved.text,
                    format: resolved.resolved.effectiveFormat,
                    targetApplication: existing.targetApplication,
                    insertionOutcome: existing.insertionOutcome
                )
            )
        }
    }

    func insertHistoryRecord(_ record: DictationRecord) {
        let delivery = outputDeliveryCoordinator.insert(record.finalText, method: injectionMethod)
        historyStore.updateOutcome(for: record.id, to: delivery.insertionOutcome)
    }

    func copyHistoryRecord(_ record: DictationRecord) {
        let delivery = outputDeliveryCoordinator.copy(record.finalText)
        historyStore.updateOutcome(for: record.id, to: delivery.insertionOutcome)
    }

    func saveAsSnippet(_ record: DictationRecord) {
        snippetStore.append(
            record.asSnippet(title: LibraryPresentation.snippetTitle(for: record.finalText))
        )
    }

    func deleteHistoryRecord(_ record: DictationRecord) {
        historyStore.delete(id: record.id)
    }

    func insertSnippet(_ snippet: Snippet) {
        _ = outputDeliveryCoordinator.insert(snippet.text, method: injectionMethod)
    }

    func copySnippet(_ snippet: Snippet) {
        _ = outputDeliveryCoordinator.copy(snippet.text)
    }

    func deleteSnippet(_ snippet: Snippet) {
        snippetStore.delete(id: snippet.id)
    }

    private func clearStreamingSession(clearHUD: Bool = true) {
        invalidateStreamingSession(clearHUD: clearHUD)
    }

    private func beginStreamingSession() -> Int {
        currentHUDTail = ""
        hasLoggedFirstHUDPartial = false
        streamingSessionFailed = false
        streamingSetupTask?.cancel()
        streamingSetupTask = nil
        streamingSessionToken += 1
        streamingAppendQueue.startSession(token: streamingSessionToken)
        acceptsStreamingPartials = true
        HUDController.shared.updateCaptionTail("")
        return streamingSessionToken
    }

    @discardableResult
    private func invalidateStreamingSession(clearHUD: Bool = true, clearTail: Bool = true) -> Int {
        let expiredSessionToken = streamingSessionToken
        streamingAppendQueue.invalidate(token: expiredSessionToken)
        streamingSetupTask?.cancel()
        streamingSetupTask = nil
        streamingSessionToken += 1
        let invalidatedStateToken = streamingSessionToken
        acceptsStreamingPartials = false
        if clearTail {
            currentHUDTail = ""
        }
        if clearHUD {
            HUDController.shared.updateCaptionTail("")
        }
        clearStreamingPartialHandlerIfStillInvalidated(invalidatedStateToken)
        return invalidatedStateToken
    }

    private func canAcceptStreamingPartials(for sessionToken: Int) -> Bool {
        sessionToken == streamingSessionToken && acceptsStreamingPartials && !streamingSessionFailed
    }

    private func canRunStreamingAppend(for sessionToken: Int) -> Bool {
        sessionToken == streamingSessionToken && !streamingSessionFailed
    }

    private func freezeStreamingSessionForRelease(_ sessionToken: Int) {
        guard sessionToken == streamingSessionToken else { return }
        acceptsStreamingPartials = false
        streamingAppendQueue.freeze(token: sessionToken)
    }

    private func markStreamingSessionFailed(_ sessionToken: Int) {
        guard sessionToken == streamingSessionToken else { return }
        streamingSessionFailed = true
        acceptsStreamingPartials = false
        streamingAppendQueue.freeze(token: sessionToken)
        currentHUDTail = ""
        HUDController.shared.updateCaptionTail("")
    }

    private func hudCaptionTailForReleasedSession(_ releasedHUDTail: String, token sessionToken: Int) -> String {
        guard sessionToken == streamingSessionToken, !streamingSessionFailed else { return "" }
        return releasedHUDTail
    }

    #if DEBUG
    func testingBeginStreamingSession() -> Int {
        beginStreamingSession()
    }

    func testingMarkStreamingSessionFailed(_ sessionToken: Int) {
        markStreamingSessionFailed(sessionToken)
    }

    func testingHUDCaptionTailForReleasedSession(_ releasedHUDTail: String, token sessionToken: Int) -> String {
        hudCaptionTailForReleasedSession(releasedHUDTail, token: sessionToken)
    }

    var testingStreamingSessionFailed: Bool {
        streamingSessionFailed
    }

    var testingCurrentHUDTail: String {
        currentHUDTail
    }

    func testingSetCurrentHUDTail(_ tail: String) {
        currentHUDTail = tail
    }
    #endif

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
