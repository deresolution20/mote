import Foundation

public struct CleanupAcceptanceSample: Equatable {
    public let id: String
    public let raw: String

    public init(id: String, raw: String) {
        self.id = id
        self.raw = raw
    }
}

public struct CleanupAcceptanceSampleResult: Equatable {
    public let sample: CleanupAcceptanceSample
    public let result: CleanupAcceptanceResult

    public init(sample: CleanupAcceptanceSample, result: CleanupAcceptanceResult) {
        self.sample = sample
        self.result = result
    }
}

public struct CleanupAcceptanceResult: Equatable {
    public let raw: String
    public let textToPaste: String
    public let cleanedText: String?
    public let path: CleanupAcceptancePath
    public let attemptedProviders: [CleanupProviderID]
    public let attempts: [CleanupProviderAttempt]

    private init(
        raw: String,
        textToPaste: String,
        cleanedText: String?,
        path: CleanupAcceptancePath,
        attemptedProviders: [CleanupProviderID],
        attempts: [CleanupProviderAttempt]
    ) {
        self.raw = raw
        self.textToPaste = textToPaste
        self.cleanedText = cleanedText
        self.path = path
        self.attemptedProviders = attemptedProviders
        self.attempts = attempts
    }

    public static func provider(
        raw: String,
        cleaned: String,
        providerID: CleanupProviderID,
        attemptedProviders: [CleanupProviderID],
        attempts: [CleanupProviderAttempt] = []
    ) -> CleanupAcceptanceResult {
        CleanupAcceptanceResult(
            raw: raw,
            textToPaste: cleaned,
            cleanedText: cleaned,
            path: .provider(providerID),
            attemptedProviders: attemptedProviders,
            attempts: attempts
        )
    }

    public static func rawFallback(
        raw: String,
        attemptedProviders: [CleanupProviderID],
        attempts: [CleanupProviderAttempt] = []
    ) -> CleanupAcceptanceResult {
        CleanupAcceptanceResult(
            raw: raw,
            textToPaste: raw,
            cleanedText: nil,
            path: .rawFallback,
            attemptedProviders: attemptedProviders,
            attempts: attempts
        )
    }
}

public enum CleanupAcceptancePath: Equatable {
    case provider(CleanupProviderID)
    case rawFallback

    public var label: String {
        switch self {
        case .provider(let providerID):
            return providerID.rawValue
        case .rawFallback:
            return "raw_fallback"
        }
    }
}

public enum CleanupAcceptanceRunner {
    public static func run(raw: String, providers: [any CleanupProvider]) async -> CleanupAcceptanceResult {
        var attemptedProviders: [CleanupProviderID] = []
        var attempts: [CleanupProviderAttempt] = []

        for provider in providers {
            attemptedProviders.append(provider.id)
            let started = Date()
            let providerResult = await provider.cleanWithDiagnostics(raw)
            let latency = Date().timeIntervalSince(started)
            let attempt = CleanupProviderAttempt(
                providerID: provider.id,
                latencySeconds: latency,
                result: providerResult
            )
            attempts.append(attempt)

            if providerResult.outcome == .accepted, let cleaned = providerResult.cleanedText {
                return .provider(
                    raw: raw,
                    cleaned: cleaned,
                    providerID: provider.id,
                    attemptedProviders: attemptedProviders,
                    attempts: attempts
                )
            }

            if !shouldContinueAfter(providerResult) {
                break
            }
        }

        return .rawFallback(raw: raw, attemptedProviders: attemptedProviders, attempts: attempts)
    }

    public static func run(
        samples: [CleanupAcceptanceSample],
        providers: [any CleanupProvider]
    ) async -> [CleanupAcceptanceSampleResult] {
        var results: [CleanupAcceptanceSampleResult] = []
        results.reserveCapacity(samples.count)

        for sample in samples {
            let result = await run(raw: sample.raw, providers: providers)
            results.append(CleanupAcceptanceSampleResult(sample: sample, result: result))
        }

        return results
    }

    private static func shouldContinueAfter(_ result: CleanupProviderResult) -> Bool {
        switch result.outcome {
        case .accepted, .rejected:
            return false
        case .unavailable, .timeout, .error:
            return true
        }
    }
}
