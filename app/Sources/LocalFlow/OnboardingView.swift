import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openSettings) private var openSettings
    @State private var timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Set up Grotdown")
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

            VStack(alignment: .leading, spacing: 6) {
                Label("Local model download", systemImage: "arrow.down.circle")
                    .font(.headline)
                Text("Before first use, Grotdown downloads its transcription and text-cleanup models to this Mac. Your voice and transcripts are never uploaded.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(state.modelDownloadsApproved
                    ? "Local model downloads are approved."
                    : "Approval is required before any model download starts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    Button(state.modelDownloadsApproved ? "Start Dictating" : "Allow download and start") {
                        Task {
                            if state.modelDownloadsApproved {
                                await state.startPipeline()
                            } else {
                                await state.approveModelDownloadsAndStartPipeline()
                            }
                        }
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
