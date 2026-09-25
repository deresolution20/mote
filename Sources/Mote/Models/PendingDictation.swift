import Foundation
import MoteCleanup

struct PendingDictation: Identifiable, Equatable {
    let id: UUID
    let rawText: String
    let plainText: String
    let resolved: ResolvedOutput
    let duration: TimeInterval
    let deliveryReason: PendingDeliveryReason

    init(
        id: UUID = UUID(),
        rawText: String,
        plainText: String,
        resolved: ResolvedOutput,
        duration: TimeInterval,
        deliveryReason: PendingDeliveryReason = .manual
    ) {
        self.id = id
        self.rawText = rawText
        self.plainText = plainText
        self.resolved = resolved
        self.duration = duration
        self.deliveryReason = deliveryReason
    }

    func replacingResolved(_ resolved: ResolvedOutput) -> Self {
        Self(
            id: id,
            rawText: rawText,
            plainText: plainText,
            resolved: resolved,
            duration: duration,
            deliveryReason: deliveryReason
        )
    }

    func replacingDeliveryReason(_ deliveryReason: PendingDeliveryReason) -> Self {
        Self(
            id: id,
            rawText: rawText,
            plainText: plainText,
            resolved: resolved,
            duration: duration,
            deliveryReason: deliveryReason
        )
    }
}
