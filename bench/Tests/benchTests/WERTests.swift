import Testing
@testable import bench

@Suite struct WERTests {
    @Test func identical() {
        #expect(wordErrorRate(reference: "ship it friday", hypothesis: "ship it friday") == 0)
    }

    @Test func caseAndPunctuationInsensitive() {
        #expect(wordErrorRate(
            reference: "um so like i think we should uh ship it friday",
            hypothesis: "Um, so like I think we should — uh — ship it Friday."
        ) == 0)
    }

    @Test func singleSubstitution() {
        // 1 error over 4 reference words
        #expect(wordErrorRate(reference: "ship it on friday", hypothesis: "ship it on monday") == 0.25)
    }

    @Test func deletion() {
        let wer = wordErrorRate(reference: "ship it friday", hypothesis: "ship friday")
        #expect(abs(wer - 1.0 / 3.0) < 1e-9)
    }

    @Test func insertion() {
        #expect(wordErrorRate(reference: "ship friday", hypothesis: "ship it friday") == 0.5)
    }

    @Test func emptyHypothesis() {
        #expect(wordErrorRate(reference: "ship it", hypothesis: "") == 1)
    }

    @Test func emptyReference() {
        #expect(wordErrorRate(reference: "", hypothesis: "") == 0)
        #expect(wordErrorRate(reference: "", hypothesis: "hello there") == 2)
    }

    @Test func apostrophesKept() {
        #expect(wordErrorRate(reference: "it's fine", hypothesis: "its fine") == 0.5)
    }

    @Test func normalizer() {
        #expect(normalizedWords("Um, so — it's 3:30 already!") == ["um", "so", "it's", "3", "30", "already"])
    }
}
