import Foundation
import MoteCleanup

enum InsertionOutcome: String, Codable, Sendable {
    case pending
    case insertedVerified
    case insertedUnverified
    case blockedFocusChanged
    case blockedSecureField
    case blockedNoTarget
    case blockedDeliveryUnavailable

    // Retained so history written by older Mote builds remains decodable.
    case typedAttempted
    case copiedNoFocusedTarget
    case copiedByUser
    case notInserted
}

struct TargetApplication: Codable, Equatable, Sendable {
    let name: String
    let bundleIdentifier: String?
}

struct DictationRecord: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    let duration: TimeInterval
    let rawText: String
    let finalText: String
    let format: OutputFormat
    let targetApplication: TargetApplication?
    let insertionOutcome: InsertionOutcome

    func replacingOutcome(_ outcome: InsertionOutcome) -> Self {
        Self(
            id: id,
            createdAt: createdAt,
            duration: duration,
            rawText: rawText,
            finalText: finalText,
            format: format,
            targetApplication: targetApplication,
            insertionOutcome: outcome
        )
    }

    func asSnippet(title: String) -> Snippet {
        Snippet(title: title, text: finalText, format: format)
    }
}

struct Snippet: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    let title: String
    let text: String
    let format: OutputFormat

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        title: String,
        text: String,
        format: OutputFormat
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.text = text
        self.format = format
    }
}
