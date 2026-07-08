public enum MenuRuntimeControl: Equatable {
    case none
    case start
    case pause
    case resume

    public var title: String? {
        switch self {
        case .none: return nil
        case .start: return "Start Dictation Engine"
        case .pause: return "Pause Dictation"
        case .resume: return "Resume Dictation"
        }
    }
}

public struct MenuRuntimeSnapshot: Equatable {
    public let statusLabel: String
    public let control: MenuRuntimeControl
    public let controlTitle: String?
    public let hasLastDictation: Bool
    public let rawPreview: String?
    public let cleanedPreview: String?
    public let canCopyRaw: Bool
    public let canCopyCleaned: Bool

    public init(
        statusLabel: String,
        control: MenuRuntimeControl,
        lastRawTranscript: String,
        lastCleanedText: String,
        previewLimit: Int = 60
    ) {
        self.statusLabel = statusLabel
        self.control = control
        controlTitle = control.title
        hasLastDictation = !lastRawTranscript.isEmpty
        canCopyRaw = !lastRawTranscript.isEmpty
        canCopyCleaned = !lastCleanedText.isEmpty
        rawPreview = lastRawTranscript.isEmpty ? nil : "Raw: \"\(Self.truncated(lastRawTranscript, limit: previewLimit))\""
        cleanedPreview = lastCleanedText.isEmpty ? nil : "Cleaned: \"\(Self.truncated(lastCleanedText, limit: previewLimit))\""
    }

    private static func truncated(_ text: String, limit: Int) -> String {
        let safeLimit = max(limit, 0)
        guard text.count > safeLimit else { return text }
        return String(text.prefix(safeLimit)) + "..."
    }
}
