import AppKit
import LocalFlowCleanup
import Testing
@testable import LocalFlow

@Suite struct HotkeyConfigurationTests {
    @Test func defaultConfigurationIsOptionSpace() {
        #expect(HotkeyConfiguration.default.displayName == "⌥ Space")
        #expect(HotkeyConfiguration.default.keyCode == 49)
        #expect(HotkeyConfiguration.default.modifiers == [.option])
        #expect(HotkeyConfiguration.default.isValid)
    }

    @Test func emptyModifierSetIsInvalid() {
        let configuration = HotkeyConfiguration(keyCode: 49, modifiers: [])
        #expect(!configuration.isValid)
    }

    @Test func letterBindingsUseReadableShortcutLabels() {
        let configuration = HotkeyConfiguration(keyCode: 15, modifiers: [.option, .shift])
        #expect(configuration.displayName == "⌥⇧ R")
    }

    @Test func recorderInputRequiresAModifierAndMapsSupportedFlags() {
        #expect(HotkeyRecorderInput.configuration(keyCode: 15, modifierFlags: []) == nil)
        #expect(
            HotkeyRecorderInput.configuration(keyCode: 15, modifierFlags: [.option, .shift])
                == HotkeyConfiguration(keyCode: 15, modifiers: [.option, .shift])
        )
    }

    @Test func holdModeBeginsOnPressAndEndsOnRelease() {
        var reducer = HotkeyInteractionReducer(mode: .holdToTalk)
        #expect(reducer.handle(.pressed) == .beginCapture)
        #expect(reducer.handle(.pressed) == .ignore)
        #expect(reducer.handle(.released) == .endCapture)
    }

    @Test func toggleModeStartsThenStopsOnSuccessivePresses() {
        var reducer = HotkeyInteractionReducer(mode: .toggle)
        #expect(reducer.handle(.pressed) == .beginCapture)
        #expect(reducer.handle(.pressed) == .endCapture)
        #expect(reducer.handle(.released) == .ignore)
    }

    @Test func cancellationStopsAnActiveCaptureInEitherMode() {
        var reducer = HotkeyInteractionReducer(mode: .toggle)
        _ = reducer.handle(.pressed)
        #expect(reducer.handle(.cancelled) == .cancelCapture)
    }
}
