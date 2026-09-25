import Testing
@testable import Mote

@Suite struct TextDeliveryPolicyTests {
    @Test func automaticUsesClipboardWithoutAStoredVerifiedMethod() {
        #expect(
            TextDeliveryPolicy.fallbackMethod(
                mode: .automatic,
                preferredVerifiedMethod: nil
            ) == .clipboard
        )
    }

    @Test func automaticUsesAStoredVerifiedDirectEventMethod() {
        #expect(
            TextDeliveryPolicy.fallbackMethod(
                mode: .automatic,
                preferredVerifiedMethod: .directEvents
            ) == .directEvents
        )
    }

    @Test func privacyFirstNeverChoosesClipboard() {
        #expect(
            TextDeliveryPolicy.fallbackMethod(
                mode: .privacyFirst,
                preferredVerifiedMethod: .clipboard
            ) == .directEvents
        )
    }

    @Test func compatibilityAlwaysChoosesClipboard() {
        #expect(
            TextDeliveryPolicy.fallbackMethod(
                mode: .compatibility,
                preferredVerifiedMethod: .directEvents
            ) == .clipboard
        )
    }
}
