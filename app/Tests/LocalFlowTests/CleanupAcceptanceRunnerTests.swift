import Foundation
import Testing
@testable import LocalFlowCleanup

@Suite struct CleanupAcceptanceRunnerTests {
    @Test func usesPrimaryProviderWhenItReturnsCleanedText() async {
        let primary = StubCleanupProvider(id: .mlx, response: "I think we should ship it Friday.")

        let result = await CleanupAcceptanceRunner.run(
            raw: "um so i think we should ship it friday",
            providers: [primary]
        )

        #expect(result.textToPaste == "I think we should ship it Friday.")
        #expect(result.cleanedText == "I think we should ship it Friday.")
        #expect(result.path == .provider(.mlx))
        #expect(result.attemptedProviders == [.mlx])
    }

    @Test func usesFallbackProviderWhenPrimaryUnavailable() async {
        let primary = DiagnosticCleanupProvider(
            id: .mlx,
            result: .unavailable(rejection: CleanupRejection(reason: .missingMetallib))
        )
        let fallback = StubCleanupProvider(id: .ollama, response: "I think we should ship it Friday.")

        let result = await CleanupAcceptanceRunner.run(
            raw: "um so i think we should ship it friday",
            providers: [primary, fallback]
        )

        #expect(result.textToPaste == "I think we should ship it Friday.")
        #expect(result.cleanedText == "I think we should ship it Friday.")
        #expect(result.path == .provider(.ollama))
        #expect(result.attemptedProviders == [.mlx, .ollama])
    }

    @Test func rejectedProviderStopsAtRawFallbackAndPreservesAttemptDiagnostics() async {
        let fallbackCounter = CallCounter()
        let primary = DiagnosticCleanupProvider(
            id: .mlx,
            result: .rejected(
                rawCandidate: "The new hire starts Monday.",
                sanitizedCandidate: "The new hire starts Monday.",
                rejection: CleanupRejection(reason: .protectedMarkerLoss, detail: "i think")
            )
        )
        let fallback = DiagnosticCleanupProvider(
            id: .ollama,
            result: .accepted(
                cleanedText: "Yeah, the new hire starts Monday, I think.",
                rawCandidate: "Yeah, the new hire starts Monday, I think.",
                sanitizedCandidate: "Yeah, the new hire starts Monday, I think."
            ),
            counter: fallbackCounter
        )
        let raw = "yeah the uh the new hire starts monday i think"

        let result = await CleanupAcceptanceRunner.run(
            raw: raw,
            providers: [primary, fallback]
        )

        #expect(result.textToPaste == raw)
        #expect(result.cleanedText == nil)
        #expect(result.path == .rawFallback)
        #expect(result.attemptedProviders == [.mlx])
        #expect(result.attempts.count == 1)
        #expect(result.attempts[0].providerID == .mlx)
        #expect(result.attempts[0].outcome == .rejected)
        #expect(result.attempts[0].rawCandidate == "The new hire starts Monday.")
        #expect(result.attempts[0].sanitizedCandidate == "The new hire starts Monday.")
        #expect(result.attempts[0].rejection?.reason == .protectedMarkerLoss)
        #expect(result.attempts[0].latencySeconds >= 0)
        #expect(await fallbackCounter.count == 0)
    }

    @Test func errorProviderContinuesToFallbackProvider() async {
        let fallbackCounter = CallCounter()
        let primary = DiagnosticCleanupProvider(
            id: .mlx,
            result: .error(
                rejection: CleanupRejection(reason: .providerError),
                description: "model failed"
            )
        )
        let fallback = DiagnosticCleanupProvider(
            id: .ollama,
            result: .accepted(cleanedText: "I think we should ship it Friday."),
            counter: fallbackCounter
        )

        let result = await CleanupAcceptanceRunner.run(
            raw: "um so i think we should ship it friday",
            providers: [primary, fallback]
        )

        #expect(result.textToPaste == "I think we should ship it Friday.")
        #expect(result.cleanedText == "I think we should ship it Friday.")
        #expect(result.path == .provider(.ollama))
        #expect(result.attemptedProviders == [.mlx, .ollama])
        #expect(result.attempts.map(\.outcome) == [.error, .accepted])
        #expect(result.attempts[0].errorDescription == "model failed")
        #expect(await fallbackCounter.count == 1)
    }

    @Test func usesRawFallbackWhenAllProvidersUnavailable() async {
        let primary = DiagnosticCleanupProvider(
            id: .mlx,
            result: .unavailable(rejection: CleanupRejection(reason: .missingMetallib))
        )
        let fallback = DiagnosticCleanupProvider(
            id: .ollama,
            result: .unavailable(rejection: CleanupRejection(reason: .providerError))
        )
        let raw = "can you um can you send me the link to that doc"

        let result = await CleanupAcceptanceRunner.run(raw: raw, providers: [primary, fallback])

        #expect(result.textToPaste == raw)
        #expect(result.cleanedText == nil)
        #expect(result.path == .rawFallback)
        #expect(result.attemptedProviders == [.mlx, .ollama])
    }

    @Test func usesRawFallbackWhenProviderListIsEmpty() async {
        let raw = "okay so um the customer said the alerts are firing twice"

        let result = await CleanupAcceptanceRunner.run(raw: raw, providers: [])

        #expect(result.textToPaste == raw)
        #expect(result.cleanedText == nil)
        #expect(result.path == .rawFallback)
        #expect(result.attemptedProviders.isEmpty)
    }

    @Test func doesNotCallFallbackProviderWhenPrimarySucceeds() async {
        let primaryCounter = CallCounter()
        let fallbackCounter = CallCounter()
        let primary = StubCleanupProvider(id: .mlx, response: "Cleaned.", counter: primaryCounter)
        let fallback = StubCleanupProvider(id: .ollama, response: "Fallback.", counter: fallbackCounter)

        _ = await CleanupAcceptanceRunner.run(raw: "cleaned", providers: [primary, fallback])

        #expect(await primaryCounter.count == 1)
        #expect(await fallbackCounter.count == 0)
    }

    @Test func batchRunnerPreservesSampleIDs() async {
        let provider = MappingCleanupProvider(
            id: .mlx,
            responses: [
                "raw one": "Clean one.",
                "raw two": nil,
            ]
        )
        let samples = [
            CleanupAcceptanceSample(id: "01", raw: "raw one"),
            CleanupAcceptanceSample(id: "02", raw: "raw two"),
        ]

        let results = await CleanupAcceptanceRunner.run(samples: samples, providers: [provider])

        #expect(results.map(\.sample.id) == ["01", "02"])
        #expect(results[0].result.path == .provider(.mlx))
        #expect(results[1].result.path == .rawFallback)
        #expect(results[1].result.textToPaste == "raw two")
    }

    @Test func batchRunnerHandlesEmptySamples() async {
        let provider = StubCleanupProvider(id: .mlx, response: "Cleaned.")

        let results = await CleanupAcceptanceRunner.run(samples: [], providers: [provider])

        #expect(results.isEmpty)
    }
}

private actor CallCounter {
    private var value = 0

    func increment() {
        value += 1
    }

    var count: Int {
        value
    }
}

private final class StubCleanupProvider: CleanupProvider {
    let id: CleanupProviderID
    let displayName = "Stub"
    let modelName = "stub"

    private let response: String?
    private let counter: CallCounter?

    init(id: CleanupProviderID, response: String?, counter: CallCounter? = nil) {
        self.id = id
        self.response = response
        self.counter = counter
    }

    func clean(_ raw: String) async -> String? {
        await counter?.increment()
        return response
    }
}

private final class MappingCleanupProvider: CleanupProvider {
    let id: CleanupProviderID
    let displayName = "Mapping Stub"
    let modelName = "mapping-stub"

    private let responses: [String: String?]

    init(id: CleanupProviderID, responses: [String: String?]) {
        self.id = id
        self.responses = responses
    }

    func clean(_ raw: String) async -> String? {
        responses[raw] ?? nil
    }
}

private final class DiagnosticCleanupProvider: CleanupProvider {
    let id: CleanupProviderID
    let displayName = "Diagnostic Stub"
    let modelName = "diagnostic-stub"

    private let result: CleanupProviderResult
    private let counter: CallCounter?

    init(id: CleanupProviderID, result: CleanupProviderResult, counter: CallCounter? = nil) {
        self.id = id
        self.result = result
        self.counter = counter
    }

    func clean(_ raw: String) async -> String? {
        result.cleanedText
    }

    func cleanWithDiagnostics(_ raw: String) async -> CleanupProviderResult {
        await counter?.increment()
        return result
    }
}
