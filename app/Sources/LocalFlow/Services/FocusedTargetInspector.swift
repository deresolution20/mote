import AppKit
import ApplicationServices

@MainActor
protocol FocusedTargetInspecting {
    func focusedTarget() -> TargetApplication?
}

@MainActor
struct FocusedTargetInspector: FocusedTargetInspecting {
    func focusedTarget() -> TargetApplication? {
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
        return TargetApplication(
            name: frontmost?.localizedName ?? "Unknown application",
            bundleIdentifier: frontmost?.bundleIdentifier
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
