import LocalFlowCleanup
import SwiftUI

struct HistoryList: View {
    let records: [DictationRecord]
    @Binding var selection: UUID?

    var body: some View {
        List(records, selection: $selection) { record in
            VStack(alignment: .leading, spacing: 5) {
                Text(LibraryPresentation.rowTitle(for: record.finalText))
                    .font(GrotdownTheme.Typography.body(14).weight(.medium))
                    .foregroundStyle(GrotdownTheme.Colors.primaryText)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    Text("•")
                    Text(String(format: "%.1fs", record.duration))
                    FormatPill(format: record.format)
                }
                .font(GrotdownTheme.Typography.mono(10))
                .foregroundStyle(GrotdownTheme.Colors.mutedText)
            }
            .padding(.vertical, 4)
            .tag(record.id)
        }
        .navigationTitle("History")
        .overlay {
            if records.isEmpty {
                ContentUnavailableView("No dictations", systemImage: "clock.arrow.circlepath")
                    .foregroundStyle(GrotdownTheme.Colors.secondaryText)
            }
        }
    }
}

struct HistoryDetail: View {
    @EnvironmentObject private var state: AppState
    let record: DictationRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                detailHeader
                textSection(title: "Final output", text: record.finalText, prominent: true)
                textSection(title: "Raw transcript", text: record.rawText, prominent: false)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Dictation")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Copy", systemImage: "doc.on.doc") {
                    state.copyHistoryRecord(record)
                }
                Button("Insert", systemImage: "arrow.down.doc") {
                    state.insertHistoryRecord(record)
                }
                Button("Save Snippet", systemImage: "bookmark.badge.plus") {
                    state.saveAsSnippet(record)
                }
                Button("Delete", systemImage: "trash", role: .destructive) {
                    state.deleteHistoryRecord(record)
                }
            }
        }
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                FormatPill(format: record.format)
                Text(record.insertionOutcome.label)
                    .font(GrotdownTheme.Typography.body(12))
                    .foregroundStyle(GrotdownTheme.Colors.secondaryText)
            }
            Text(record.createdAt.formatted(date: .complete, time: .shortened))
                .font(GrotdownTheme.Typography.body(13))
                .foregroundStyle(GrotdownTheme.Colors.secondaryText)
            HStack(spacing: 5) {
                Text(String(format: "%.1f seconds", record.duration))
                if let target = record.targetApplication {
                    Text("•")
                    Text(target.name)
                }
            }
            .font(GrotdownTheme.Typography.mono(11))
            .foregroundStyle(GrotdownTheme.Colors.mutedText)
        }
    }

    private func textSection(title: String, text: String, prominent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(GrotdownTheme.Typography.body(13).weight(.semibold))
                .foregroundStyle(GrotdownTheme.Colors.primaryText)
            Text(text)
                .font(GrotdownTheme.Typography.body(14))
                .foregroundStyle(prominent ? GrotdownTheme.Colors.primaryText : GrotdownTheme.Colors.secondaryText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    prominent ? GrotdownTheme.Colors.input : GrotdownTheme.Colors.raised,
                    in: RoundedRectangle(cornerRadius: GrotdownTheme.Metrics.controlCornerRadius, style: .continuous)
                )
        }
    }
}

struct FormatPill: View {
    let format: OutputFormat

    var body: some View {
        Text(format == .markdown ? "Markdown" : "Plain text")
            .font(GrotdownTheme.Typography.mono(10).weight(.semibold))
            .foregroundStyle(GrotdownTheme.Colors.secondaryText)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(GrotdownTheme.Colors.raised, in: Capsule())
    }
}

private extension InsertionOutcome {
    var label: String {
        switch self {
        case .pending: "Pending"
        case .typedAttempted: "Inserted"
        case .copiedNoFocusedTarget: "Copied — no text field"
        case .copiedByUser: "Copied"
        case .notInserted: "Not inserted"
        }
    }
}
