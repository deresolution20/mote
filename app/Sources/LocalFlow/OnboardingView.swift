import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @State private var timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Local Flow needs three permissions")
                .font(.title2.bold())
            Text("Everything runs on this Mac — no audio or text ever leaves it.")
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
                title: "Input Monitoring",
                detail: "To notice the Fn key anywhere (listen-only).",
                granted: state.inputMonitoringGranted
            ) {
                Permissions.requestInputMonitoring()
                Permissions.openSettings(anchor: Permissions.inputMonitoringAnchor)
            }

            PermissionRow(
                title: "Accessibility",
                detail: "To type the transcript at your cursor (synthesized ⌘V).",
                granted: state.accessibilityGranted
            ) {
                Permissions.promptAccessibility()
                Permissions.openSettings(anchor: Permissions.accessibilityAnchor)
            }

            Divider()

            HStack {
                Image(systemName: "lightbulb")
                Text("Set System Settings → Keyboard → “Press 🌐 key to” = **Do Nothing**, so macOS doesn't also react to the hotkey.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                if state.allPermissionsGranted {
                    Button("Start Dictating") {
                        Task { await state.startPipeline() }
                        NSApp.keyWindow?.close()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("Waiting for all three permissions…")
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

private struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if !granted {
                Button("Grant…", action: action)
            }
        }
    }
}
