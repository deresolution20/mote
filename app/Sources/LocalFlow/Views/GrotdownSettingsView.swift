import LocalFlowCleanup
import SwiftUI

struct GrotdownSettingsSnapshot: Equatable {
    static let tabNames = ["General", "Model", "Hotkey", "Output", "Microphone"]

    let outputFormat: OutputFormat
    let hotkeyConfiguration: HotkeyConfiguration
    let captureMode: CaptureMode

    var outputFormatLabel: String {
        outputFormat == .markdown ? "Markdown (GFM)" : "Plain text"
    }

    var codeCommandHelp: String {
        "Say “start code block yaml”, dictate the code, then say “end code block”."
    }

    var modelDescription: String {
        "Parakeet transcription with MLX only local cleanup."
    }

    var hotkeyLabel: String {
        hotkeyConfiguration.displayName
    }

    var captureModeLabel: String {
        captureMode == .holdToTalk ? "Hold to talk" : "Tap to toggle"
    }

    static func fixture(
        outputFormat: OutputFormat = .plain,
        hotkeyConfiguration: HotkeyConfiguration = .default,
        captureMode: CaptureMode = .holdToTalk
    ) -> Self {
        Self(
            outputFormat: outputFormat,
            hotkeyConfiguration: hotkeyConfiguration,
            captureMode: captureMode
        )
    }
}

struct GrotdownSettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        TabView {
            GeneralSettingsPane()
                .environmentObject(state)
                .tabItem { Label("General", systemImage: "gearshape") }

            ModelSettingsPane()
                .environmentObject(state)
                .tabItem { Label("Model", systemImage: "cpu") }

            HotkeySettingsPane()
                .environmentObject(state)
                .tabItem { Label("Hotkey", systemImage: "command") }

            OutputSettingsPane()
                .environmentObject(state)
                .tabItem { Label("Output", systemImage: "text.alignleft") }

            MicrophoneSettingsPane(
                service: state.microphoneDeviceService,
                selectedDeviceID: $state.selectedMicrophoneDeviceID,
                refreshDevices: state.refreshMicrophoneDevices
            )
            .tabItem { Label("Microphone", systemImage: "mic") }
        }
        .frame(width: 720, height: 600)
        .onAppear(perform: state.refreshMicrophoneDevices)
    }
}

private struct GeneralSettingsPane: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        SettingsPane {
            Section("Privacy") {
                Text("Your voice and your text stay on this Mac. Grotdown has no server.")
                    .foregroundStyle(.secondary)
            }

            Section("Permissions") {
                PermissionRow(
                    title: "Microphone",
                    detail: "Lets Grotdown hear you while a capture is active.",
                    granted: state.micGranted
                ) {
                    Task {
                        _ = await Permissions.requestMicrophone()
                        state.refreshPermissions()
                        if !state.micGranted {
                            Permissions.openSettings(anchor: Permissions.microphoneAnchor)
                        }
                    }
                }

                PermissionRow(
                    title: "Accessibility",
                    detail: "Lets Grotdown react to the hotkey and type at your cursor.",
                    granted: state.accessibilityGranted
                ) {
                    Permissions.promptAccessibility()
                    Permissions.openSettings(anchor: Permissions.accessibilityAnchor)
                }
            }

            Section("Behavior") {
                Toggle("Show waveform overlay", isOn: $state.hudEnabled)
                Toggle("Insert automatically", isOn: $state.autoInsert)
                Picker("Insert text by", selection: $state.injectByTyping) {
                    Text("Direct typing").tag(true)
                    Text("Clipboard paste").tag(false)
                }
                .pickerStyle(.segmented)
            }

            Section("Personal Dictionary") {
                PersonalDictionarySection()
                    .environmentObject(state)
            }

            Section("Last Dictation") {
                let snapshot = diagnosticsSnapshot
                DiagnosticRow(title: "Status", value: snapshot.status)
                DiagnosticRow(title: "Raw transcript", value: snapshot.rawTranscriptDisplay)
                DiagnosticRow(title: "Final text", value: snapshot.cleanedTextDisplay)
            }
        }
    }

    private var diagnosticsSnapshot: SettingsDiagnosticsSnapshot {
        SettingsDiagnosticsSnapshot(
            status: state.status.label,
            cleanupDisplayName: Cleaner.displayName,
            cleanupModel: Cleaner.model,
            usesDirectTyping: state.injectByTyping,
            lastRawTranscript: state.lastTranscript,
            lastCleanedText: state.lastCleaned
        )
    }
}

private struct ModelSettingsPane: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        SettingsPane {
            Section("Speech recognition") {
                LabeledContent("Transcriber") {
                    Text("Parakeet")
                        .foregroundStyle(.secondary)
                }
                Text("Speech recognition runs on-device. Streaming captions remain display-only until they are explicitly promoted by a benchmark.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Text cleanup") {
                LabeledContent("Runtime") {
                    Text("MLX only")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Model") {
                    Text(Cleaner.model)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Text("If local cleanup is unavailable or unsafe, Grotdown keeps the raw transcript.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct HotkeySettingsPane: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        SettingsPane {
            Section("Shortcut") {
                LabeledContent("Current hotkey") {
                    HotkeyRecorderView(configuration: $state.hotkeyConfiguration)
                }
                Text("Click the shortcut, then press a key with ⌃, ⌥, ⇧, or ⌘. The binding applies immediately and stays on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Capture mode") {
                Picker("Interaction", selection: $state.captureMode) {
                    Text("Hold to talk").tag(CaptureMode.holdToTalk)
                    Text("Tap to toggle").tag(CaptureMode.toggle)
                }
                .pickerStyle(.segmented)
                Text(state.captureMode == .holdToTalk
                    ? "Hold the hotkey while speaking, then release to transcribe."
                    : "Press once to start recording and again to stop.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if case .failed(let message) = state.status {
                Section("Hotkey issue") {
                    Text(message)
                        .foregroundStyle(GrotdownTheme.Colors.danger)
                }
            }
        }
    }
}

private struct OutputSettingsPane: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        SettingsPane {
            Section("Default format") {
                Picker("Output", selection: $state.outputFormat) {
                    Text("Plain text").tag(OutputFormat.plain)
                    Text("Markdown (GFM)").tag(OutputFormat.markdown)
                }
                .pickerStyle(.segmented)
                Text(state.outputFormat == .markdown
                    ? "Uses guarded local GFM formatting. Unsafe output remains plain text."
                    : "Writes the cleaned transcription as plain text.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Cleanup") {
                Toggle("Clean up dictated text", isOn: $state.cleanupEnabled)
                Toggle("Preserve code-like text and backticks", isOn: $state.preserveCodeAndBackticks)
            }

            Section("Code blocks") {
                Text("For a fenced code block, say:")
                    .foregroundStyle(.secondary)
                Text("start code block yaml\nend code block")
                    .font(GrotdownTheme.Typography.mono(13))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(GrotdownTheme.Colors.input, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text("Say only the start and end commands; normal Markdown structure is inferred safely.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MicrophoneSettingsPane: View {
    @ObservedObject var service: MicrophoneDeviceService
    @Binding var selectedDeviceID: UInt32?
    let refreshDevices: () -> Void

    var body: some View {
        SettingsPane {
            Section("Input") {
                if service.devices.isEmpty {
                    Text(service.statusMessage)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Microphone", selection: $selectedDeviceID) {
                        Text("System default").tag(UInt32?.none)
                        ForEach(service.devices) { device in
                            Text(device.name).tag(Optional(device.id))
                        }
                    }
                    Button("Refresh devices", action: refreshDevices)
                }
            }

            Section("Input level") {
                ProgressView(value: service.level, total: 1) {
                    Text("Microphone input level")
                } currentValueLabel: {
                    Text("\(Int((service.level * 100).rounded()))%")
                }
                .accessibilityLabel("Microphone input level")
                .accessibilityValue("\(Int((service.level * 100).rounded())) percent")
                Text("The meter responds only while Grotdown is recording.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DiagnosticRow: View {
    let title: String
    let value: String

    var body: some View {
        LabeledContent(title) {
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
                .textSelection(.enabled)
        }
    }
}
