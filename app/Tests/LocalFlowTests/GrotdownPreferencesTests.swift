import Foundation
import LocalFlowCleanup
import Testing
@testable import LocalFlow

@MainActor
@Suite struct GrotdownPreferencesTests {
    @Test func preferencesRoundTripOutputAndCaptureMode() {
        let suiteName = "GrotdownPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = GrotdownPreferences(defaults: defaults)
        preferences.outputFormat = .markdown
        preferences.captureMode = .toggle
        preferences.autoInsert = false
        preferences.modelDownloadsApproved = true

        let restored = GrotdownPreferences(defaults: defaults)
        #expect(restored.outputFormat == .markdown)
        #expect(restored.captureMode == .toggle)
        #expect(restored.autoInsert == false)
        #expect(restored.modelDownloadsApproved)
    }

    @Test func preferencesUseSafeCaptureDefaults() {
        let suiteName = "GrotdownPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = GrotdownPreferences(defaults: defaults)
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
        let suiteName = "GrotdownPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = GrotdownPreferences(defaults: defaults)
        preferences.captureMode = .toggle
        preferences.hotkeyConfiguration = .default

        let restored = GrotdownPreferences(defaults: defaults)
        #expect(restored.captureMode == .toggle)
        #expect(restored.hotkeyConfiguration == .default)
    }

    @Test func preferencesRoundTripSelectedMicrophoneWithoutForcingOneByDefault() {
        let suiteName = "GrotdownPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = GrotdownPreferences(defaults: defaults)
        #expect(preferences.selectedMicrophoneDeviceID == nil)
        preferences.selectedMicrophoneDeviceID = 42

        let restored = GrotdownPreferences(defaults: defaults)
        #expect(restored.selectedMicrophoneDeviceID == 42)
    }

    @Test func existingAutomaticInsertionPreferenceIsPreserved() {
        let suiteName = "GrotdownPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: "grotdown.autoInsert")

        let preferences = GrotdownPreferences(defaults: defaults)

        #expect(preferences.autoInsert)
    }
}
