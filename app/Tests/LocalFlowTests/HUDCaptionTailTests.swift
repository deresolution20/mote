import Testing
@testable import LocalFlowCleanup

@Suite struct HUDCaptionTailTests {
    @Test func returnsEmptyForWhitespaceOnlyInput() {
        #expect(HUDCaptionTail.tail(from: "   \n\t  ") == "")
    }

    @Test func normalizesWhitespaceForShortInput() {
        #expect(HUDCaptionTail.tail(from: "so   basically\nit works") == "so basically it works")
    }

    @Test func keepsShortInputWithoutPrefix() {
        #expect(HUDCaptionTail.tail(from: "the dashboard is broken again") == "the dashboard is broken again")
    }

    @Test func returnsLastWordsWithPrefixWhenTruncated() {
        let partial = "so basically the dashboard is broken again"
        #expect(HUDCaptionTail.tail(from: partial, maxWords: 4) == "...dashboard is broken again")
    }

    @Test func preservesPunctuationOnTailWords() {
        let partial = "okay so the customer said the alerts are firing twice."
        #expect(HUDCaptionTail.tail(from: partial, maxWords: 5) == "...the alerts are firing twice.")
    }

    @Test func treatsNegativeLimitAsNoCaption() {
        #expect(HUDCaptionTail.tail(from: "hello world", maxWords: -1) == "")
    }
}
