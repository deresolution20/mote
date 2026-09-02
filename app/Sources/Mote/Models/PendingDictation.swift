import Foundation
import MoteCleanup

struct PendingDictation: Identifiable, Equatable {
    let id: UUID
    let rawText: String
    let plainText: String
    let resolved: ResolvedOutput
    let duration: TimeInterval

    init(
        id: UUID = UUID(),
        rawText: String,
        plainText: String,
        resolved: ResolvedOutput,
        duration: TimeInterval
    ) {
        self.id = id
        self.rawText = rawText
        self.plainText = plainText
        self.resolved = resolved
        self.duration = duration
    }

    func replacingResolved(_ resolved: ResolvedOutput) -> Self {
        Self(id: id, rawText: rawText, plainText: plainText, resolved: resolved, duration: duration)
    }
}
