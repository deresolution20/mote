import Testing
@testable import LocalFlow

@Suite struct TextInjectorTests {
    @Test func restoresClipboardOnlyWhileGrotdownStillOwnsIt() {
        #expect(PasteboardRestorationPolicy.shouldRestore(ownedChangeCount: 12, currentChangeCount: 12))
    }

    @Test func preservesNewerClipboardContentFromAnotherApp() {
        #expect(!PasteboardRestorationPolicy.shouldRestore(ownedChangeCount: 12, currentChangeCount: 13))
    }
}
