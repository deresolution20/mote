import Foundation

public struct SettingsDiagnosticsSnapshot: Equatable {
    public let status: String
    public let cleanupModelLabel: String
    public let insertionModeLabel: String
    public let rawTranscriptDisplay: String
    public let cleanedTextDisplay: String

    public init(
        status: String,
        cleanupDisplayName: String,
        cleanupModel: String,
        insertionMode: String,
        lastRawTranscript: String,
        lastCleanedText: String
    ) {
        self.status = status
        cleanupModelLabel = "\(cleanupDisplayName): \(cleanupModel)"
        insertionModeLabel = insertionMode
        rawTranscriptDisplay = lastRawTranscript.isEmpty ? "No dictation yet." : lastRawTranscript
        cleanedTextDisplay = lastCleanedText.isEmpty ? "No cleaned text yet." : lastCleanedText
    }
}
