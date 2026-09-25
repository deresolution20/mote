import Foundation
import MoteCleanup
import Testing
@testable import Mote

@MainActor
@Suite struct MotePreferencesTests {
    @Test func preferencesRoundTripOutputAndCaptureMode() {
        let suiteName = "MotePreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = MotePreferences(defaults: defaults, legacyDefaults: nil)
        preferences.outputFormat = .markdown
        preferences.captureMode = .toggle
        preferences.autoInsert = false
        preferences.modelDownloadsApproved = true

        let restored = MotePreferences(defaults: defaults, legacyDefaults: nil)
        #expect(restored.outputFormat == .markdown)
        #expect(restored.captureMode == .toggle)
        #expect(restored.autoInsert == false)
        #expect(restored.modelDownloadsApproved)
    }

    @Test func preferencesUseSafeCaptureDefaults() {
        let suiteName = "MotePreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = MotePreferences(defaults: defaults, legacyDefaults: nil)
        #expect(preferences.outputFormat == .plain)
        #expect(preferences.captureMode == .holdToTalk)
        #expect(!preferences.autoInsert)
        #expect(!preferences.modelDownloadsApproved)
        #expect(preferences.cleanupEnabled)
        #expect(preferences.hudEnabled)
        #expect(preferences.injectByTyping)
        #expect(!preferences.preserveCodeAndBackticks)
    }

    @Test func preferencesRoundTripHotkeyAndCaptureMode() {
        let suiteName = "MotePreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = MotePreferences(defaults: defaults, legacyDefaults: nil)
        preferences.captureMode = .toggle
        preferences.hotkeyConfiguration = .default

        let restored = MotePreferences(defaults: defaults, legacyDefaults: nil)
        #expect(restored.captureMode == .toggle)
        #expect(restored.hotkeyConfiguration == .default)
    }

    @Test func preferencesRoundTripSelectedMicrophoneWithoutForcingOneByDefault() {
        let suiteName = "MotePreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = MotePreferences(defaults: defaults, legacyDefaults: nil)
        #expect(preferences.selectedMicrophoneDeviceID == nil)
        preferences.selectedMicrophoneDeviceID = 42

        let restored = MotePreferences(defaults: defaults, legacyDefaults: nil)
        #expect(restored.selectedMicrophoneDeviceID == 42)
    }

    @Test func existingAutomaticInsertionPreferenceIsPreserved() {
        let suiteName = "MotePreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: "mote.autoInsert")

        let preferences = MotePreferences(defaults: defaults, legacyDefaults: nil)

        #expect(preferences.autoInsert)
    }

    @Test func migratesPreferencesFromTheLegacyBundleDomain() {
        let currentSuiteName = "MotePreferencesTests.current.\(UUID().uuidString)"
        let legacySuiteName = "MotePreferencesTests.legacy.\(UUID().uuidString)"
        let current = UserDefaults(suiteName: currentSuiteName)!
        let legacy = UserDefaults(suiteName: legacySuiteName)!
        defer {
            current.removePersistentDomain(forName: currentSuiteName)
            legacy.removePersistentDomain(forName: legacySuiteName)
        }

        legacy.set("markdown", forKey: "grotdown.outputFormat")
        legacy.set(true, forKey: "grotdown.autoInsert")
        legacy.set(42, forKey: "grotdown.selectedMicrophoneDeviceID")

        let preferences = MotePreferences(defaults: current, legacyDefaults: legacy)

        #expect(preferences.outputFormat == .markdown)
        #expect(preferences.autoInsert)
        #expect(preferences.selectedMicrophoneDeviceID == 42)
        #expect(current.string(forKey: "mote.outputFormat") == "markdown")
        #expect(current.bool(forKey: "mote.autoInsert"))
        #expect((current.object(forKey: "mote.selectedMicrophoneDeviceID") as? NSNumber)?.uint32Value == 42)
    }

    @Test func existingMotePreferencesWinOverLegacyValues() {
        let currentSuiteName = "MotePreferencesTests.current.\(UUID().uuidString)"
        let legacySuiteName = "MotePreferencesTests.legacy.\(UUID().uuidString)"
        let current = UserDefaults(suiteName: currentSuiteName)!
        let legacy = UserDefaults(suiteName: legacySuiteName)!
        defer {
            current.removePersistentDomain(forName: currentSuiteName)
            legacy.removePersistentDomain(forName: legacySuiteName)
        }

        current.set(false, forKey: "mote.autoInsert")
        legacy.set(true, forKey: "grotdown.autoInsert")

        let preferences = MotePreferences(defaults: current, legacyDefaults: legacy)

        #expect(!preferences.autoInsert)
    }

    @Test func completedMigrationDoesNotResurrectRemovedLegacyValues() {
        let currentSuiteName = "MotePreferencesTests.current.\(UUID().uuidString)"
        let legacySuiteName = "MotePreferencesTests.legacy.\(UUID().uuidString)"
        let current = UserDefaults(suiteName: currentSuiteName)!
        let legacy = UserDefaults(suiteName: legacySuiteName)!
        defer {
            current.removePersistentDomain(forName: currentSuiteName)
            legacy.removePersistentDomain(forName: legacySuiteName)
        }

        legacy.set(true, forKey: "grotdown.autoInsert")
        _ = MotePreferences(defaults: current, legacyDefaults: legacy)
        current.removeObject(forKey: "mote.autoInsert")

        let preferences = MotePreferences(defaults: current, legacyDefaults: legacy)

        #expect(!preferences.autoInsert)
    }
}
