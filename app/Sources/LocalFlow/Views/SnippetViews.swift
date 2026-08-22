import SwiftUI

struct SnippetList: View {
    let snippets: [Snippet]
    @Binding var selection: UUID?

    var body: some View {
        List(snippets, selection: $selection) { snippet in
            VStack(alignment: .leading, spacing: 5) {
                Text(snippet.title)
                    .font(GrotdownTheme.Typography.body(14).weight(.medium))
                    .foregroundStyle(GrotdownTheme.Colors.primaryText)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(LibraryPresentation.rowTitle(for: snippet.text))
                        .lineLimit(1)
                    FormatPill(format: snippet.format)
                }
                .font(GrotdownTheme.Typography.body(11))
                .foregroundStyle(GrotdownTheme.Colors.mutedText)
            }
            .padding(.vertical, 4)
            .tag(snippet.id)
        }
        .navigationTitle("Snippets")
        .overlay {
            if snippets.isEmpty {
                ContentUnavailableView("No snippets", systemImage: "bookmark")
                    .foregroundStyle(GrotdownTheme.Colors.secondaryText)
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
                        .font(GrotdownTheme.Typography.body(12))
                        .foregroundStyle(GrotdownTheme.Colors.secondaryText)
                }
                Text(snippet.title)
                    .font(GrotdownTheme.Typography.display(26).weight(.bold))
                    .foregroundStyle(GrotdownTheme.Colors.primaryText)
                Text(snippet.text)
                    .font(GrotdownTheme.Typography.body(15))
                    .foregroundStyle(GrotdownTheme.Colors.primaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        GrotdownTheme.Colors.input,
                        in: RoundedRectangle(cornerRadius: GrotdownTheme.Metrics.controlCornerRadius, style: .continuous)
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
