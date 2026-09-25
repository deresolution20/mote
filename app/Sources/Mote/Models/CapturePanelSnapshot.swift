import MoteCleanup

struct CapturePanelSnapshot: Equatable {
    enum State: Equatable {
        case ready
        case idle
        case recording
        case processing
        case paused
        case needsPermissions
        case needsModelDownloadApproval
        case failed
    }

    enum Action: Equatable {
        case insert
        case copy
    }

    let guidance: String
    let preview: String?
    let showsFormatPicker: Bool
    let primaryAction: Action?
    let secondaryAction: Action?
    let recentTitles: [String]

    static func make(
        state: State,
        pending: PendingDictation?,
        autoInsert: Bool,
        recentRecords: [DictationRecord],
        hotkeyConfiguration: HotkeyConfiguration = .default
    ) -> Self {
        let pendingPreview = pending?.resolved.text
        let isManualReady = pending != nil
        return Self(
            guidance: guidance(for: state, hotkeyConfiguration: hotkeyConfiguration),
            preview: pendingPreview,
            showsFormatPicker: isManualReady,
            primaryAction: isManualReady ? .insert : nil,
            secondaryAction: isManualReady ? .copy : nil,
            recentTitles: recentRecords.prefix(3).map { boundedTitle($0.finalText) }
        )
    }

    static func formatLabel(for format: OutputFormat) -> String {
        switch format {
        case .plain: "Plain text"
        case .markdown: "Markdown"
        }
    }

    private static func guidance(for state: State, hotkeyConfiguration: HotkeyConfiguration) -> String {
        switch state {
        case .ready, .idle: "Use \(hotkeyConfiguration.displayName) to dictate"
        case .recording: "Listening on this Mac"
        case .processing: "Finishing your dictation"
        case .paused: "Dictation is paused"
        case .needsPermissions: "Microphone and Accessibility are required"
        case .needsModelDownloadApproval: "Approve local model download to begin"
        case .failed: "Dictation needs attention"
        }
    }

    private static func boundedTitle(_ text: String, limit: Int = 30) -> String {
        let normalized = text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard normalized.count > limit else { return normalized }
        return String(normalized.prefix(limit - 1)) + "…"
    }
}
