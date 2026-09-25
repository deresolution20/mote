import ApplicationServices
import Testing
@testable import Mote

@Suite struct TextDeliveryVerificationTests {
    @Test func unicodeChunksPreserveExtendedGraphemeClusters() {
        let text = "123456789012345👨‍👩‍👧‍👦é"

        let chunks = UnicodeEventChunker.chunks(text, maximumUTF16Units: 16)

        #expect(chunks.joined() == text)
        #expect(chunks == ["123456789012345", "👨‍👩‍👧‍👦é"])
    }

    @Test func aSingleOversizedGraphemeIsNeverSplit() {
        let grapheme = "👩🏽‍❤️‍💋‍👨🏻"

        let chunks = UnicodeEventChunker.chunks(grapheme, maximumUTF16Units: 2)

        #expect(chunks == [grapheme])
    }

    @Test func emptyInputProducesNoEventChunks() {
        #expect(UnicodeEventChunker.chunks("").isEmpty)
    }

    @Test func expectedSelectionRangeUsesUTF16Length() {
        let snapshot = TextSelectionSnapshot(range: CFRange(location: 4, length: 7))

        let expected = snapshot.expectedRange(afterInsertingUTF16Count: "🙂".utf16.count)

        #expect(expected.location == 6)
        #expect(expected.length == 0)
    }
}
