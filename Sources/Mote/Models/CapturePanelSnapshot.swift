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
    let pendingTitle: String?
    let pendingDetail: String?
    let showsFormatPicker: Bool
    let primaryAction: Action?
    let primaryActionTitle: String?
    let secondaryAction: Action?
    let recentTitles: [String]

    static func make(
        state: State,
        pending: PendingDictation?,
        recentRecords: [DictationRecord],
        hotkeyConfiguration: HotkeyConfiguration = .default
    ) -> Self {
        let pendingPreview = pending?.resolved.text
        let isManualReady = pending != nil
        let pendingPresentation = pending.map { presentation(for: $0.deliveryReason) }
        return Self(
            guidance: guidance(for: state, hotkeyConfiguration: hotkeyConfiguration),
            preview: pendingPreview,
            pendingTitle: pendingPresentation?.title,
            pendingDetail: pendingPresentation?.detail,
            showsFormatPicker: isManualReady,
            primaryAction: isManualReady ? .insert : nil,
            primaryActionTitle: pendingPresentation?.action,
            secondaryAction: isManualReady ? .copy : nil,
            recentTitles: recentRecords.prefix(3).map { boundedTitle($0.finalText) }
        )
    }

    private static func presentation(
        for reason: PendingDeliveryReason
    ) -> (title: String, detail: String, action: String) {
        switch reason {
        case .manual:
            ("Ready to insert", "Choose where the text should go, then insert it.", "Insert")
        case .unverified:
            (
                "Insertion could not be verified",
                "The text may already be present. Inserting again could duplicate it.",
                "Insert again"
            )
        case .blocked(let reason):
            switch reason {
            case .secureField:
                (
                    "Secure field protected",
                    "Mote never inserts automatically into secure text fields.",
                    "Try again here"
                )
            case .focusChanged:
                (
                    "Focus changed",
                    "Nothing was inserted. Select the destination and try again.",
                    "Try again here"
                )
            case .noEditableTarget:
                (
                    "No editable field found",
                    "Nothing was inserted. Select a text field and try again.",
                    "Try again here"
                )
            case .deliveryUnavailable:
                (
                    "Text delivery unavailable",
                    "Nothing was inserted. Select the destination and try again or copy the text.",
                    "Try again here"
                )
            }
        }
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
