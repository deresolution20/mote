import LocalFlowCleanup
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView {
            GeneralSettingsPane()
                .environmentObject(state)
                .tabItem { Label("General", systemImage: "gearshape") }

            DictationSettingsPane()
                .environmentObject(state)
                .tabItem { Label("Dictation", systemImage: "waveform") }

            InsertionSettingsPane()
                .environmentObject(state)
                .tabItem { Label("Insertion", systemImage: "keyboard") }

            DictionarySettingsPane()
                .environmentObject(state)
                .tabItem { Label("Dictionary", systemImage: "book.closed") }

            DiagnosticsSettingsPane(snapshot: diagnosticsSnapshot)
                .tabItem { Label("Diagnostics", systemImage: "stethoscope") }
        }
        .frame(width: 660)
        .frame(minHeight: 560)
        .onReceive(timer) { _ in
            state.refreshPermissions()
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

private struct SettingsPane<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Form {
            content
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct GeneralSettingsPane: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        SettingsPane {
            Section("Permissions") {
                PermissionRow(
                    title: "Microphone",
                    detail: "Allows Local Flow to hear you while you hold the hotkey.",
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
                    detail: "Allows Local Flow to notice the hotkey and type at your cursor.",
                    granted: state.accessibilityGranted
                ) {
                    Permissions.promptAccessibility()
                    Permissions.openSettings(anchor: Permissions.accessibilityAnchor)
                }
            }

            Section("General") {
                Toggle("Show waveform overlay", isOn: $state.hudEnabled)
            }
        }
    }
}

private struct DictationSettingsPane: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        SettingsPane {
            Section("Dictation") {
                Toggle("Clean up dictated text", isOn: $state.cleanupEnabled)
                LabeledContent("Cleanup model") {
                    Text("\(Cleaner.displayName): \(Cleaner.model)")
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

private struct InsertionSettingsPane: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        SettingsPane {
            Section("Insertion") {
                Picker("Insert text by", selection: $state.injectByTyping) {
                    Text("Direct typing").tag(true)
                    Text("Clipboard paste").tag(false)
                }
                .pickerStyle(.segmented)

                Text("Direct typing avoids the system clipboard. Clipboard paste is available for apps that reject synthetic typing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DictionarySettingsPane: View {
    var body: some View {
        SettingsPane {
            Section("Personal Dictionary") {
                PersonalDictionarySection()
            }
        }
    }
}

private struct DiagnosticsSettingsPane: View {
    let snapshot: SettingsDiagnosticsSnapshot

    var body: some View {
        SettingsPane {
            Section("Runtime") {
                DiagnosticRow(title: "Status", value: snapshot.status)
                DiagnosticRow(title: "Cleanup model", value: snapshot.cleanupModelLabel)
                DiagnosticRow(title: "Insertion mode", value: snapshot.insertionModeLabel)
            }

            Section("Last Dictation") {
                DiagnosticRow(title: "Raw transcript", value: snapshot.rawTranscriptDisplay)
                DiagnosticRow(title: "Cleaned text", value: snapshot.cleanedTextDisplay)
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

struct PermissionRow: View {
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
            if granted {
                Text("Granted")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Button("Grant...", action: action)
            }
        }
    }
}

struct PersonalDictionarySection: View {
    @EnvironmentObject var state: AppState
    @State private var newTerm = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Words the transcriber tends to mishear: proper nouns, product names, jargon. Spoken tokens that sound like these get corrected automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                TextField("Add a term...", text: $newTerm)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addTerm)
                Button("Add", action: addTerm)
                    .disabled(newTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if state.dictionaryTerms.isEmpty {
                Text("No terms yet.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
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
                .frame(maxHeight: 120)
            }
        }
    }

    private func addTerm() {
        state.addDictionaryTerm(newTerm)
        newTerm = ""
    }
}
