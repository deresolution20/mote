import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openSettings) private var openSettings
    @State private var timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Grotdown needs two permissions")
                .font(.title2.bold())
            Text("Your voice and your text stay on this Mac. Grotdown has no server.")
                .foregroundStyle(.secondary)

            PermissionRow(
                title: "Microphone",
                detail: "To hear you while you hold the hotkey.",
                granted: state.micGranted
            ) {
                Task {
                    _ = await Permissions.requestMicrophone()
                    state.refreshPermissions()
                    if !state.micGranted { Permissions.openSettings(anchor: Permissions.microphoneAnchor) }
                }
            }

            PermissionRow(
                title: "Accessibility",
                detail: "To notice the hotkey and type the transcript at your cursor.",
                granted: state.accessibilityGranted
            ) {
                Permissions.promptAccessibility()
                Permissions.openSettings(anchor: Permissions.accessibilityAnchor)
            }

            Divider()

            HStack {
                Image(systemName: "lightbulb")
                Text("Use \(state.hotkeyConfiguration.displayName) to dictate. Hold mode records while held; toggle mode starts and stops on each press.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Open Settings…") {
                    openSettings()
                }

                Spacer()
                if state.allPermissionsGranted {
                    Button("Start Dictating") {
                        Task { await state.startPipeline() }
                        NSApp.keyWindow?.close()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("Waiting for both permissions…")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .frame(width: 480)
        .onReceive(timer) { _ in
            state.refreshPermissions()
        }
    }
}
