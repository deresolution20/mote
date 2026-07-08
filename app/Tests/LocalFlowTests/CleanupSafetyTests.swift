import Foundation
import Testing
@testable import LocalFlowCleanup

@Suite struct CleanupSafetyTests {
    @Test func acceptsInlineCodeFormattingWhenSanitizedWordsComeFromRaw() {
        let raw = "so like the query takes uh forever when i add the group by"
        let output = "So, the query takes forever when I add the `GROUP BY`."

        let accepted = CleanupSafety.acceptedCandidate(from: output, raw: raw)

        #expect(accepted == "So, the query takes forever when I add the GROUP BY.")
    }

    @Test func acceptsWholeOutputCodeFenceWhenBodyIsSafe() {
        let raw = "um remind me to follow up with sarah tomorrow morning"
        let output = """
        ```text
        Remind me to follow up with Sarah tomorrow morning.
        ```
        """

        let accepted = CleanupSafety.acceptedCandidate(from: output, raw: raw)

        #expect(accepted == "Remind me to follow up with Sarah tomorrow morning.")
    }

    @Test func rejectsAssistantStyleWrapper() {
        let raw = "uh are you there"
        let output = "Here is the cleaned text: Are you there?"

        let accepted = CleanupSafety.acceptedCandidate(from: output, raw: raw)

        #expect(accepted == nil)
    }

    @Test func rejectsMarkdownLinksAndURLs() {
        let raw = "send me the link to that doc"
        let output = "Send me the link to [that doc](https://example.com)."

        let accepted = CleanupSafety.acceptedCandidate(from: output, raw: raw)

        #expect(accepted == nil)
    }

    @Test func rejectsAddedContentFromSwiftMLXBenchmark() {
        let raw = "so like the query takes uh forever when i add the group by"
        let output = "The query takes a long time to execute when I add the `GROUP BY` clause."

        let accepted = CleanupSafety.acceptedCandidate(from: output, raw: raw)

        #expect(accepted == nil)
    }

    @Test func rejectsAddedArticleFromStandupFinding() {
        let raw = "so i was thinking maybe we uh we grab lunch after standup"
        let output = "So, I was thinking maybe we grab lunch after the Standup."

        let accepted = CleanupSafety.acceptedCandidate(from: output, raw: raw)

        #expect(accepted == nil)
    }

    @Test func polishesStandaloneFilledPauseFromAcceptedCandidate() {
        let raw = "okay um long story short we we missed the deadline by two days"
        let output = "Okay, uh, long story short, we missed the deadline by two days."

        let evaluation = CleanupSafety.evaluate(rawOutput: output, raw: raw)

        #expect(evaluation.acceptedText == "Okay, long story short, we missed the deadline by two days.")
        #expect(evaluation.sanitizedCandidate == "Okay, long story short, we missed the deadline by two days.")
        #expect(evaluation.rejection == nil)
    }

    @Test func polishesOpeningSoLikeFromAcceptedCandidate() {
        let raw = "so like the query takes uh forever when i add the group by"
        let output = "so like the query takes forever when i add the group by"

        let evaluation = CleanupSafety.evaluate(rawOutput: output, raw: raw)

        #expect(evaluation.acceptedText == "the query takes forever when i add the group by")
        #expect(evaluation.sanitizedCandidate == "the query takes forever when i add the group by")
        #expect(evaluation.rejection == nil)
    }

    @Test func polishesInternalDiscourseLikeFromAcceptedCandidate() {
        let raw = "um so you're saying like uh dashboards down"
        let output = "You're saying like dashboards down?"

        let evaluation = CleanupSafety.evaluate(rawOutput: output, raw: raw)

        #expect(evaluation.acceptedText == "You're saying dashboards down?")
        #expect(evaluation.sanitizedCandidate == "You're saying dashboards down?")
        #expect(evaluation.rejection == nil)
    }

    @Test func polishesCopulaDiscourseLikeFromAcceptedCandidate() {
        let raw = "um you're like saying like um like the dashboards are down or like for real"
        let output = "You're like saying the dashboards are down or for real?"

        let evaluation = CleanupSafety.evaluate(rawOutput: output, raw: raw)

        #expect(evaluation.acceptedText == "You're saying the dashboards are down or for real?")
        #expect(evaluation.sanitizedCandidate == "You're saying the dashboards are down or for real?")
        #expect(evaluation.rejection == nil)
    }

    @Test func preservesContextualLikeWhenPolishingFillers() {
        let raw = "uh my flight gets in at like seven so dinner at eight works"
        let output = "My flight gets in at like seven so dinner at eight works."

        let evaluation = CleanupSafety.evaluate(rawOutput: output, raw: raw)

        #expect(evaluation.acceptedText == output)
        #expect(evaluation.sanitizedCandidate == output)
        #expect(evaluation.rejection == nil)
    }

    @Test func preservesVerbLikeBeforeDiscourseGerund() {
        let raw = "i like saying the dashboards are down because it is precise"
        let output = "I like saying the dashboards are down because it is precise."

        let evaluation = CleanupSafety.evaluate(rawOutput: output, raw: raw)

        #expect(evaluation.acceptedText == output)
        #expect(evaluation.sanitizedCandidate == output)
        #expect(evaluation.rejection == nil)
    }

    @Test func reportsAddedMeaningTokenRejectionReason() {
        let raw = "so i was thinking maybe we uh we grab lunch after standup"
        let output = "So, I was thinking maybe we grab lunch after the Standup."

        let evaluation = CleanupSafety.evaluate(rawOutput: output, raw: raw)

        #expect(evaluation.acceptedText == nil)
        #expect(evaluation.sanitizedCandidate == output)
        #expect(evaluation.rejection?.reason == .addedMeaningToken)
        #expect(evaluation.rejection?.detail == "the")
    }

    @Test func rejectsProtectedMarkerLoss() {
        let raw = "honestly i think the the second option is is way better"
        let output = "The second option is way better."

        let accepted = CleanupSafety.acceptedCandidate(from: output, raw: raw)

        #expect(accepted == nil)
    }

    @Test func reportsProtectedMarkerLossRejectionReason() {
        let raw = "honestly i think the the second option is is way better"
        let output = "The second option is way better."

        let evaluation = CleanupSafety.evaluate(rawOutput: output, raw: raw)

        #expect(evaluation.acceptedText == nil)
        #expect(evaluation.sanitizedCandidate == output)
        #expect(evaluation.rejection?.reason == .protectedMarkerLoss)
        #expect(evaluation.rejection?.detail == "i think")
    }

    @Test func rejectsSampleSeventeenCandidateWithAddedNextAndMissingHedge() {
        let raw = "yeah the uh the new hire starts monday i think"
        let output = "Yeah, the new hire starts next Monday."

        let evaluation = CleanupSafety.evaluate(rawOutput: output, raw: raw)

        #expect(evaluation.acceptedText == nil)
        #expect(evaluation.sanitizedCandidate == output)
        #expect(evaluation.rejection?.reason == .protectedMarkerLoss)
        #expect(evaluation.rejection?.detail == "i think")
    }
}
