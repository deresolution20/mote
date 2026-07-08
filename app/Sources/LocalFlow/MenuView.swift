import LocalFlowCleanup
import SwiftUI

struct MenuView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text(state.status.label)

        if !state.lastTranscript.isEmpty {
            Divider()
            Text("Raw: “\(truncated(state.lastTranscript))”")
            if !state.lastCleaned.isEmpty {
                Text("Cleaned: “\(truncated(state.lastCleaned))”")
                Button("Copy Cleaned Text") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(state.lastCleaned, forType: .string)
                }
            }
            Button("Copy Raw Transcript") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(state.lastTranscript, forType: .string)
            }
        }

        Divider()

        Button("Settings…") {
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

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
}
