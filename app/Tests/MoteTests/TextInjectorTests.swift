import Testing
@testable import Mote

@Suite struct TextInjectorTests {
    @Test func restoresClipboardOnlyWhileMoteStillOwnsIt() {
        #expect(PasteboardRestorationPolicy.shouldRestore(ownedChangeCount: 12, currentChangeCount: 12))
    }

    @Test func preservesNewerClipboardContentFromAnotherApp() {
        #expect(!PasteboardRestorationPolicy.shouldRestore(ownedChangeCount: 12, currentChangeCount: 13))
    }
}
