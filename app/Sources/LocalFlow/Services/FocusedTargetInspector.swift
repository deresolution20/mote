import AppKit
import ApplicationServices

@MainActor
protocol FocusedTargetInspecting {
    func focusedTarget() -> FocusedTarget?
}

/// The focused editable element at a specific point in time. The element token
/// is deliberately process-local and used only to reject a focus change before
/// injection; persisted history retains the human-readable application only.
struct FocusedTarget: Equatable {
    let application: TargetApplication
    let accessibilityElementToken: UInt
}

@MainActor
struct FocusedTargetInspector: FocusedTargetInspecting {
    func focusedTarget() -> FocusedTarget? {
        guard Permissions.accessibility else { return nil }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                systemWide,
                kAXFocusedUIElementAttribute as CFString,
                &focusedValue
            ) == .success,
            let focusedValue
        else {
            return nil
        }

        let focusedElement = unsafeBitCast(focusedValue, to: AXUIElement.self)
        var roleValue: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                focusedElement,
                kAXRoleAttribute as CFString,
                &roleValue
            ) == .success,
            let role = roleValue as? String,
            Self.isEditable(role: role)
        else {
            return nil
        }

        let frontmost = NSWorkspace.shared.frontmostApplication
        return FocusedTarget(
            application: TargetApplication(
                name: frontmost?.localizedName ?? "Unknown application",
                bundleIdentifier: frontmost?.bundleIdentifier
            ),
            accessibilityElementToken: CFHash(focusedElement)
        )
    }

    nonisolated static func isEditable(role: String) -> Bool {
        [
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            kAXComboBoxRole as String,
            "AXSearchField",
        ].contains(role)
    }
}
