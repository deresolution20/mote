import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @State private var timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Local Flow needs two permissions")
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
                Text("Push-to-talk: **hold Left ⌥ (Option)**, speak, release. Quick taps and ⌥-shortcuts are ignored.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Keep cleanup model loaded for")
                    TextField("", value: $state.keepAliveMinutes, format: .number)
                        .frame(width: 52)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                    Stepper("minutes", value: $state.keepAliveMinutes, in: 0...1440)
                        .labelsHidden()
                    Text("minutes")
                }
                Text("Higher = faster first dictation (model stays warm); lower = frees ~4 GB sooner. 0 unloads it immediately after each use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            PersonalDictionarySection()

            HStack {
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

private struct PersonalDictionarySection: View {
    @EnvironmentObject var state: AppState
    @State private var newTerm = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Personal dictionary").font(.headline)
            Text("Words the transcriber tends to mishear — proper nouns, product names, jargon. Spoken tokens that sound like these get corrected automatically (e.g. “Grafana”, “Zendesk”, “Prometheus”).")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                TextField("Add a term…", text: $newTerm)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addTerm)
                Button("Add", action: addTerm)
                    .disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if state.dictionaryTerms.isEmpty {
                Text("No terms yet.").font(.caption).foregroundStyle(.tertiary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(state.dictionaryTerms, id: \.self) { term in
                            HStack {
                                Text(term)
                                Spacer()
                                Button {
                                    state.removeDictionaryTerm(term)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 1)
                        }
                    }
                }
                .frame(maxHeight: 110)
            }
        }
    }

    private func addTerm() {
        state.addDictionaryTerm(newTerm)
        newTerm = ""
    }
}
