import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        MoteSettingsView()
            .environmentObject(state)
    }
}

struct SettingsPane<Content: View>: View {
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
                Button("Grant…", action: action)
            }
        }
    }
}

struct PersonalDictionarySection: View {
    @EnvironmentObject private var state: AppState
    @State private var newTerm = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Words the transcriber tends to mishear: proper nouns, product names, and jargon.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                TextField("Add a term…", text: $newTerm)
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
                                .accessibilityLabel("Remove \(term)")
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
