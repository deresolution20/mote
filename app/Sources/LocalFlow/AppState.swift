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
        case failed(String)

        var symbolName: String {
            switch self {
            case .needsPermissions: return "mic.badge.xmark"
            case .loadingModel: return "hourglass"
            case .idle: return "mic"
            case .recording: return "mic.fill"
            case .transcribing: return "waveform"
            case .failed: return "exclamationmark.triangle"
            }
        }

        var label: String {
            switch self {
            case .needsPermissions: return "Permissions needed — open Setup"
            case .loadingModel: return "Loading speech model…"
            case .idle: return "Ready — hold Fn and speak"
            case .recording: return "Recording…"
            case .transcribing: return "Transcribing…"
            case .failed(let msg): return "Error: \(msg)"
            }
        }
    }

    @Published var status: Status = .needsPermissions
    @Published var micGranted = false
    @Published var accessibilityGranted = false
    @Published var lastTranscript: String = ""

    private let capture = AudioCapture()
    private let transcriber = Transcriber()
    private var hotkey: HotkeyMonitor?
    private var pipelineStarted = false

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
        do {
            try await transcriber.load()
        } catch {
            status = .failed("model load failed: \(error.localizedDescription)")
            pipelineStarted = false
            return
        }

        let monitor = HotkeyMonitor(
            onKeyDown: { [weak self] in self?.hotkeyPressed() },
            onKeyUp: { [weak self] in self?.hotkeyReleased() }
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
        guard case .idle = status else { return }
        do {
            try capture.start()
            status = .recording
        } catch {
            status = .failed("mic capture failed: \(error.localizedDescription)")
        }
    }

    private func hotkeyReleased() {
        guard case .recording = status else { return }
        let samples = capture.stop()
        // Ignore accidental taps: < 0.3 s of audio.
        guard samples.count > 4800 else {
            status = .idle
            return
        }
        status = .transcribing
        Task {
            do {
                let text = try await transcriber.transcribe(samples)
                lastTranscript = text
                if !text.isEmpty {
                    TextInjector.paste(text)
                }
                status = .idle
            } catch {
                status = .failed("transcription failed: \(error.localizedDescription)")
                // Recover to idle after a beat so the next attempt works.
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if case .failed = status { status = .idle }
            }
        }
    }
}
