import SwiftUI

struct SnippetList: View {
    let snippets: [Snippet]
    @Binding var selection: UUID?

    var body: some View {
        List(snippets, selection: $selection) { snippet in
            VStack(alignment: .leading, spacing: 5) {
                Text(snippet.title)
                    .font(MoteTheme.Typography.body(14).weight(.medium))
                    .foregroundStyle(MoteTheme.Colors.primaryText)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(LibraryPresentation.rowTitle(for: snippet.text))
                        .lineLimit(1)
                    FormatPill(format: snippet.format)
                }
                .font(MoteTheme.Typography.body(11))
                .foregroundStyle(MoteTheme.Colors.mutedText)
            }
            .padding(.vertical, 4)
            .tag(snippet.id)
        }
        .navigationTitle("Snippets")
        .overlay {
            if snippets.isEmpty {
                ContentUnavailableView("No snippets", systemImage: "bookmark")
                    .foregroundStyle(MoteTheme.Colors.secondaryText)
            }
        }
    }
}

struct SnippetDetail: View {
    @EnvironmentObject private var state: AppState
    let snippet: Snippet

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    FormatPill(format: snippet.format)
                    Text(snippet.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(MoteTheme.Typography.body(12))
                        .foregroundStyle(MoteTheme.Colors.secondaryText)
                }
                Text(snippet.title)
                    .font(MoteTheme.Typography.display(26).weight(.bold))
                    .foregroundStyle(MoteTheme.Colors.primaryText)
                Text(snippet.text)
                    .font(MoteTheme.Typography.body(15))
                    .foregroundStyle(MoteTheme.Colors.primaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        MoteTheme.Colors.input,
                        in: RoundedRectangle(cornerRadius: MoteTheme.Metrics.controlCornerRadius, style: .continuous)
                    )
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Snippet")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Copy", systemImage: "doc.on.doc") {
                    state.copySnippet(snippet)
                }
                Button("Insert", systemImage: "arrow.down.doc") {
                    state.insertSnippet(snippet)
                }
                Button("Delete", systemImage: "trash", role: .destructive) {
                    state.deleteSnippet(snippet)
                }
            }
        }
    }
}
