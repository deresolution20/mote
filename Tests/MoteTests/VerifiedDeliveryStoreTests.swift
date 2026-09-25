import Foundation
import Testing
@testable import Mote

@MainActor
@Suite struct VerifiedDeliveryStoreTests {
    @Test func verifiedFallbackRoundTripsWithoutUserContent() {
        let suiteName = "VerifiedDeliveryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let key = DeliverySurfaceKey(
            bundleIdentifier: "com.example.Editor",
            applicationVersion: "4.2",
            operatingSystemVersion: "26.0",
            accessibilityRole: "AXTextArea"
        )

        VerifiedDeliveryStore(defaults: defaults).recordVerified(.directEvents, for: key)
        let restored = VerifiedDeliveryStore(defaults: defaults)

        #expect(restored.preferredMethod(for: key) == .directEvents)
    }

    @Test func accessibilityMethodIsNotStoredAsAFallback() {
        let suiteName = "VerifiedDeliveryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let key = DeliverySurfaceKey(
            bundleIdentifier: "com.example.Editor",
            applicationVersion: "4.2",
            operatingSystemVersion: "26.0",
            accessibilityRole: "AXTextArea"
        )

        let store = VerifiedDeliveryStore(defaults: defaults)
        store.recordVerified(.accessibility, for: key)

        #expect(store.preferredMethod(for: key) == nil)
    }

    @Test func resetRemovesAllLearnedMethods() {
        let suiteName = "VerifiedDeliveryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let key = DeliverySurfaceKey(
            bundleIdentifier: "com.example.Editor",
            applicationVersion: "4.2",
            operatingSystemVersion: "26.0",
            accessibilityRole: "AXTextArea"
        )

        let store = VerifiedDeliveryStore(defaults: defaults)
        store.recordVerified(.clipboard, for: key)
        store.reset()

        #expect(store.preferredMethod(for: key) == nil)
    }
}
