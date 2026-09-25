import ApplicationServices
import Testing
@testable import Mote

@Suite struct FocusedTargetInspectorTests {
    @Test func secureTextTargetsAreIdentifiedButNeverEligible() {
        let capabilities = TextTargetCapabilities(
            role: kAXTextFieldRole as String,
            subrole: kAXSecureTextFieldSubrole as String,
            selectedTextSettable: true,
            selectedRangeReadable: true
        )

        #expect(capabilities.isSecure)
        #expect(!capabilities.isEligible)
        #expect(!capabilities.canVerifySelectedTextReplacement)
    }

    @Test func selectedTextCapabilityMakesACustomRoleEligible() {
        let capabilities = TextTargetCapabilities(
            role: kAXGroupRole as String,
            subrole: nil,
            selectedTextSettable: true,
            selectedRangeReadable: true
        )

        #expect(capabilities.isEligible)
        #expect(capabilities.canVerifySelectedTextReplacement)
    }

    @Test func readableSelectionRangeMakesACustomEditorEligibleForVerifiedFallbacks() {
        let capabilities = TextTargetCapabilities(
            role: kAXGroupRole as String,
            subrole: nil,
            selectedTextSettable: false,
            selectedRangeReadable: true
        )

        #expect(capabilities.isEligible)
        #expect(!capabilities.canVerifySelectedTextReplacement)
    }

    @Test func roleNameAloneNeverMakesATargetEligible() {
        let capabilities = TextTargetCapabilities(
            role: kAXTextAreaRole as String,
            subrole: nil,
            selectedTextSettable: false,
            selectedRangeReadable: false
        )

        #expect(!capabilities.isEligible)
    }

    @Test func sameWindowRequiresTheSameProcessAndConcreteWindowToken() {
        let application = TargetApplication(name: "Editor", bundleIdentifier: "example.Editor")
        let original = FocusContext(
            application: application,
            processIdentifier: 42,
            applicationVersion: "1.0",
            windowToken: 7
        )

        #expect(original.isSameWindow(as: original))
        #expect(!original.isSameWindow(as: .init(
            application: application,
            processIdentifier: 42,
            applicationVersion: "1.0",
            windowToken: 8
        )))
        #expect(!original.isSameWindow(as: .init(
            application: application,
            processIdentifier: 43,
            applicationVersion: "1.0",
            windowToken: 7
        )))
        #expect(!original.isSameWindow(as: .init(
            application: application,
            processIdentifier: 42,
            applicationVersion: "1.0",
            windowToken: nil
        )))
    }

    @Test func systemWideFocusedElementFromFrontmostProcessTakesPrecedence() {
        let selected = FocusedTargetInspector.preferredFocusedElement(
            systemWide: "system-wide",
            systemWideProcessIdentifier: 42,
            frontmostProcessIdentifier: 42,
            frontmostApplication: "application"
        )

        #expect(selected == "system-wide")
    }

    @Test func systemWideFocusFromAnotherProcessFallsBackToTheFrontmostApplication() {
        let selected = FocusedTargetInspector.preferredFocusedElement(
            systemWide: "mote-hud",
            systemWideProcessIdentifier: 7,
            frontmostProcessIdentifier: 42,
            frontmostApplication: "codex-composer"
        )

        #expect(selected == "codex-composer")
    }

    @Test func systemWideFocusWithUnknownOwnerIsNotTrusted() {
        let selected = FocusedTargetInspector.preferredFocusedElement(
            systemWide: "unknown-owner",
            systemWideProcessIdentifier: nil,
            frontmostProcessIdentifier: 42,
            frontmostApplication: "codex-composer"
        )

        #expect(selected == "codex-composer")
    }

    @Test func foreignSystemWideFocusCanStillUseTheFrontmostAppsAccessibilityFallback() {
        let selected = FocusedTargetInspector.preferredFocusedElement(
            systemWide: "mote-hud",
            systemWideProcessIdentifier: 7,
            frontmostProcessIdentifier: 42,
            frontmostApplication: nil as String?,
            afterEnablingManualAccessibility: "codex-composer"
        )

        #expect(selected == "codex-composer")
    }

    @Test func missingSystemWideFocusFallsBackToTheFrontmostApplication() {
        let selected = FocusedTargetInspector.preferredFocusedElement(
            systemWide: nil as String?,
            systemWideProcessIdentifier: nil,
            frontmostProcessIdentifier: 42,
            frontmostApplication: "application"
        )

        #expect(selected == "application")
    }

    @Test func chromiumFocusFallsBackAfterEnablingManualAccessibility() {
        let selected = FocusedTargetInspector.preferredFocusedElement(
            systemWide: nil as String?,
            systemWideProcessIdentifier: nil,
            frontmostProcessIdentifier: 42,
            frontmostApplication: nil,
            afterEnablingManualAccessibility: "chromium-editor"
        )

        #expect(selected == "chromium-editor")
    }

    @Test func chromeFocusFallsBackAfterEnablingEnhancedAccessibility() {
        let selected = FocusedTargetInspector.preferredFocusedElement(
            systemWide: nil as String?,
            systemWideProcessIdentifier: nil,
            frontmostProcessIdentifier: 42,
            frontmostApplication: nil,
            afterEnablingManualAccessibility: nil,
            afterEnablingEnhancedAccessibility: "chrome-editor"
        )

        #expect(selected == "chrome-editor")
    }
}
