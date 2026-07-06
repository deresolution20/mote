import Foundation

public enum CleanupProviderOutcome: String, Codable, Equatable {
    case accepted
    case rejected
    case unavailable
    case timeout
    case error
}

public enum CleanupRejectionReason: String, Codable, Equatable {
    case unknown
    case emptyOutput
    case codeFenceArtifact
    case assistantWrapper
    case forbiddenMarkdownOrLink
    case bulletList
    case multilineOutput
    case outputTooLong
    case outputTooShort
    case lowSpeakerOverlap
    case protectedMarkerLoss
    case personalDictionaryTermLoss
    case addedMeaningToken
    case missingMetallib
    case httpStatus
    case requestTimedOut
    case emptyResponse
    case decodeFailed
    case providerError
}

public struct CleanupRejection: Codable, Equatable {
    public let reason: CleanupRejectionReason
    public let detail: String?

    public init(reason: CleanupRejectionReason, detail: String? = nil) {
        self.reason = reason
        self.detail = detail
    }
}

public struct CleanupSafetyEvaluation: Equatable {
    public let acceptedText: String?
    public let sanitizedCandidate: String?
    public let rejection: CleanupRejection?

    public init(
        acceptedText: String?,
        sanitizedCandidate: String?,
        rejection: CleanupRejection?
    ) {
        self.acceptedText = acceptedText
        self.sanitizedCandidate = sanitizedCandidate
        self.rejection = rejection
    }
}

public struct CleanupProviderResult: Equatable {
    public let outcome: CleanupProviderOutcome
    public let cleanedText: String?
    public let rawCandidate: String?
    public let sanitizedCandidate: String?
    public let rejection: CleanupRejection?
    public let errorDescription: String?

    public init(
        outcome: CleanupProviderOutcome,
        cleanedText: String?,
        rawCandidate: String?,
        sanitizedCandidate: String?,
        rejection: CleanupRejection?,
        errorDescription: String? = nil
    ) {
        self.outcome = outcome
        self.cleanedText = cleanedText
        self.rawCandidate = rawCandidate
        self.sanitizedCandidate = sanitizedCandidate
        self.rejection = rejection
        self.errorDescription = errorDescription
    }

    public static func accepted(
        cleanedText: String,
        rawCandidate: String? = nil,
        sanitizedCandidate: String? = nil
    ) -> CleanupProviderResult {
        CleanupProviderResult(
            outcome: .accepted,
            cleanedText: cleanedText,
            rawCandidate: rawCandidate,
            sanitizedCandidate: sanitizedCandidate ?? cleanedText,
            rejection: nil
        )
    }

    public static func rejected(
        rawCandidate: String?,
        sanitizedCandidate: String?,
        rejection: CleanupRejection
    ) -> CleanupProviderResult {
        CleanupProviderResult(
            outcome: .rejected,
            cleanedText: nil,
            rawCandidate: rawCandidate,
            sanitizedCandidate: sanitizedCandidate,
            rejection: rejection
        )
    }

    public static func unavailable(rejection: CleanupRejection) -> CleanupProviderResult {
        CleanupProviderResult(
            outcome: .unavailable,
            cleanedText: nil,
            rawCandidate: nil,
            sanitizedCandidate: nil,
            rejection: rejection
        )
    }

    public static func timeout(rejection: CleanupRejection) -> CleanupProviderResult {
        CleanupProviderResult(
            outcome: .timeout,
            cleanedText: nil,
            rawCandidate: nil,
            sanitizedCandidate: nil,
            rejection: rejection
        )
    }

    public static func error(rejection: CleanupRejection, description: String? = nil) -> CleanupProviderResult {
        CleanupProviderResult(
            outcome: .error,
            cleanedText: nil,
            rawCandidate: nil,
            sanitizedCandidate: nil,
            rejection: rejection,
            errorDescription: description
        )
    }
}

public struct CleanupProviderAttempt: Codable, Equatable {
    public let providerID: CleanupProviderID
    public let outcome: CleanupProviderOutcome
    public let latencySeconds: TimeInterval
    public let cleanedText: String?
    public let rawCandidate: String?
    public let sanitizedCandidate: String?
    public let rejection: CleanupRejection?
    public let errorDescription: String?

    public init(providerID: CleanupProviderID, latencySeconds: TimeInterval, result: CleanupProviderResult) {
        self.providerID = providerID
        self.outcome = result.outcome
        self.latencySeconds = latencySeconds
        self.cleanedText = result.cleanedText
        self.rawCandidate = result.rawCandidate
        self.sanitizedCandidate = result.sanitizedCandidate
        self.rejection = result.rejection
        self.errorDescription = result.errorDescription
    }
}
