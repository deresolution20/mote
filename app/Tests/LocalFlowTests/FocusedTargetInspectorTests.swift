import ApplicationServices
import Testing
@testable import LocalFlow

@Suite struct FocusedTargetInspectorTests {
    @Test func commonEditableAccessibilityRolesAreRecognized() {
        #expect(FocusedTargetInspector.isEditable(role: kAXTextFieldRole as String))
        #expect(FocusedTargetInspector.isEditable(role: kAXTextAreaRole as String))
        #expect(FocusedTargetInspector.isEditable(role: kAXComboBoxRole as String))
    }

    @Test func nonEditableAccessibilityRolesAreNotTargets() {
        #expect(!FocusedTargetInspector.isEditable(role: kAXButtonRole as String))
        #expect(!FocusedTargetInspector.isEditable(role: kAXStaticTextRole as String))
    }
}
