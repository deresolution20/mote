import SwiftUI

struct LibraryRootView: View {
    @EnvironmentObject private var state: AppState
    @SceneStorage("grotdown.library.section") private var selectedSection: String?
    @State private var searchText = ""
    @State private var selectedHistoryID: UUID?
    @State private var selectedSnippetID: UUID?

    private var activeSection: LibrarySection {
        LibrarySection(rawValue: selectedSection ?? "") ?? LibraryPresentation.defaultSection
    }

    private var presentation: LibraryPresentation {
        LibraryPresentation(
            records: state.historyStore.records,
            snippets: state.snippetStore.snippets,
            searchText: searchText
        )
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Section("Library") {
                    ForEach(LibrarySection.allCases, id: \.self) { section in
                        Label(section.title, systemImage: section.symbolName)
                            .tag(section.rawValue)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Grotdown")
        } content: {
            switch activeSection {
            case .history:
                HistoryList(records: presentation.visibleRecords, selection: $selectedHistoryID)
            case .snippets:
                SnippetList(snippets: presentation.visibleSnippets, selection: $selectedSnippetID)
            }
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $searchText, prompt: "Search local history and snippets")
        .frame(minWidth: 800, minHeight: 520)
        .background(GrotdownTheme.Colors.canvas)
        .preferredColorScheme(.dark)
        .onAppear {
            if selectedSection == nil {
                selectedSection = LibraryPresentation.defaultSection.rawValue
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch activeSection {
        case .history:
            if let record = presentation.visibleRecords.first(where: { $0.id == selectedHistoryID }) {
                HistoryDetail(record: record)
            } else {
                LibraryEmptyDetail(
                    symbolName: "clock.arrow.circlepath",
                    title: presentation.visibleRecords.isEmpty ? "No dictations found" : "Choose a dictation",
                    message: presentation.visibleRecords.isEmpty
                        ? "Completed dictations stay on this Mac."
                        : "Select a dictation to inspect or reuse it."
                )
            }
        case .snippets:
            if let snippet = presentation.visibleSnippets.first(where: { $0.id == selectedSnippetID }) {
                SnippetDetail(snippet: snippet)
            } else {
                LibraryEmptyDetail(
                    symbolName: "bookmark",
                    title: presentation.visibleSnippets.isEmpty ? "No snippets found" : "Choose a snippet",
                    message: presentation.visibleSnippets.isEmpty
                        ? "Save a dictation as a snippet to reuse it here."
                        : "Select a snippet to inspect or reuse it."
                )
            }
        }
    }
}

private struct LibraryEmptyDetail: View {
    let symbolName: String
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbolName)
        } description: {
            Text(message)
        }
        .foregroundStyle(GrotdownTheme.Colors.secondaryText)
    }
}
