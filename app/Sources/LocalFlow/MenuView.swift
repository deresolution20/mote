import SwiftUI

struct MenuView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Text(state.status.label)

        if !state.lastTranscript.isEmpty {
            Text("Last: “\(String(state.lastTranscript.prefix(60)))\(state.lastTranscript.count > 60 ? "…" : "")”")
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
}
