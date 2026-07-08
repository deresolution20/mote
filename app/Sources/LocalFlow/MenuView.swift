import SwiftUI

struct MenuView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text(state.status.label)

        if state.allPermissionsGranted, case .needsPermissions = state.status {
            Button("Start Dictation Engine") {
                Task { await state.startPipeline() }
            }
            Divider()
        }

        Button("Settings…") {
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        if !state.lastTranscript.isEmpty {
            Divider()
            Text("Last Dictation")
            Text("Raw: “\(truncated(state.lastTranscript))”")
            Button("Copy Last Raw") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(state.lastTranscript, forType: .string)
            }
            if !state.lastCleaned.isEmpty {
                Text("Cleaned: “\(truncated(state.lastCleaned))”")
                Button("Copy Last Cleaned") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(state.lastCleaned, forType: .string)
                }
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
