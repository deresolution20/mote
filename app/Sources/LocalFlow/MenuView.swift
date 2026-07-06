import LocalFlowCleanup
import SwiftUI

struct MenuView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Text(state.status.label)

        Toggle("Clean up with AI (\(Cleaner.displayName): \(Cleaner.model))", isOn: $state.cleanupEnabled)

        Toggle("Show waveform overlay", isOn: $state.hudEnabled)

        Toggle("Insert by typing (skip clipboard)", isOn: $state.injectByTyping)

        Menu("Keep model loaded: \(keepAliveLabel)") {
            ForEach([0, 5, 10, 30, 60], id: \.self) { minutes in
                Button {
                    state.keepAliveMinutes = minutes
                } label: {
                    Label(
                        minutes == 0 ? "Unload immediately" : "\(minutes) min",
                        systemImage: state.keepAliveMinutes == minutes ? "checkmark" : ""
                    )
                }
            }
            Divider()
            Text("Custom values in Setup & Permissions…")
        }
        .disabled(!state.cleanupEnabled)

        if !state.lastTranscript.isEmpty {
            Divider()
            Text("Raw: “\(truncated(state.lastTranscript))”")
            if !state.lastCleaned.isEmpty {
                Text("Cleaned: “\(truncated(state.lastCleaned))”")
            }
            Button("Copy Raw Transcript") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(state.lastTranscript, forType: .string)
            }
        }

        Divider()

        Button("Setup & Permissions…") {
            state.showOnboarding()
        }

        if state.allPermissionsGranted, case .needsPermissions = state.status {
            Button("Start Dictation Engine") {
                Task { await state.startPipeline() }
            }
        }

        Divider()

        Button("Quit Local Flow") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func truncated(_ text: String) -> String {
        text.count > 60 ? String(text.prefix(60)) + "…" : text
    }

    private var keepAliveLabel: String {
        state.keepAliveMinutes <= 0 ? "off" : "\(state.keepAliveMinutes) min"
    }
}
