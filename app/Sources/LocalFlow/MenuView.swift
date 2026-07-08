import LocalFlowCleanup
import SwiftUI

struct MenuView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let snapshot = MenuRuntimeSnapshot(
            statusLabel: state.status.label,
            control: state.menuRuntimeControl,
            lastRawTranscript: state.lastTranscript,
            lastCleanedText: state.lastCleaned
        )

        Text(snapshot.statusLabel)

        if let controlTitle = snapshot.controlTitle {
            Button(controlTitle) {
                run(snapshot.control)
            }
            Divider()
        }

        Button("Settings…") {
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        if snapshot.hasLastDictation {
            Divider()
            Text("Last Dictation")
            if let rawPreview = snapshot.rawPreview {
                Text(rawPreview)
            }
            if snapshot.canCopyRaw {
                Button("Copy Last Raw") {
                    copy(state.lastTranscript)
                }
            }
            if let cleanedPreview = snapshot.cleanedPreview {
                Text(cleanedPreview)
            }
            if snapshot.canCopyCleaned {
                Button("Copy Last Cleaned") {
                    copy(state.lastCleaned)
                }
            }
        }

        Divider()

        Button("Quit Local Flow") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func run(_ control: MenuRuntimeControl) {
        switch control {
        case .none:
            break
        case .start:
            Task { await state.startPipeline() }
        case .pause:
            state.pauseDictation()
        case .resume:
            Task { await state.resumeDictation() }
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
