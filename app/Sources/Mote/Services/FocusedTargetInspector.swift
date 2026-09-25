import AppKit
import ApplicationServices
import OSLog

@MainActor
protocol FocusedTargetInspecting {
    func snapshot() -> FocusSnapshot
}

struct FocusContext: Equatable {
    let application: TargetApplication
    let processIdentifier: pid_t
    let applicationVersion: String?
    let windowToken: UInt?

    func isSameWindow(as other: Self) -> Bool {
        guard let windowToken, let otherWindowToken = other.windowToken else { return false }
        return processIdentifier == other.processIdentifier && windowToken == otherWindowToken
    }
}

struct TextTargetCapabilities: Equatable {
    let role: String
    let subrole: String?
    let selectedTextSettable: Bool
    let selectedRangeReadable: Bool

    var isSecure: Bool {
        subrole == kAXSecureTextFieldSubrole as String
    }

    var isEligible: Bool {
        !isSecure && (selectedTextSettable || selectedRangeReadable)
    }

    var canVerifySelectedTextReplacement: Bool {
        isEligible && selectedTextSettable && selectedRangeReadable
    }
}

struct FocusSnapshot {
    let context: FocusContext?
    let target: FocusedTarget?
}

/// A capture-time reference to an editable or explicitly secure target. Only
/// opaque identity and capability metadata participate in equality. Mote never
/// reads or stores the target's text value.
struct FocusedTarget: Equatable {
    let context: FocusContext
    let accessibilityElementToken: UInt
    let capabilities: TextTargetCapabilities
    let accessibilityElement: AXUIElement?

    var application: TargetApplication { context.application }

    init(
        context: FocusContext,
        accessibilityElementToken: UInt,
        capabilities: TextTargetCapabilities,
        accessibilityElement: AXUIElement? = nil
    ) {
        self.context = context
        self.accessibilityElementToken = accessibilityElementToken
        self.capabilities = capabilities
        self.accessibilityElement = accessibilityElement
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.context == rhs.context
            && lhs.accessibilityElementToken == rhs.accessibilityElementToken
            && lhs.capabilities == rhs.capabilities
    }
}

@MainActor
struct FocusedTargetInspector: FocusedTargetInspecting {
    private static let logger = Logger(subsystem: "dev.brice.mote", category: "focused-target")

    func snapshot() -> FocusSnapshot {
        guard Permissions.accessibility else {
            Self.logger.info("rejected reason=accessibility-permission")
            return FocusSnapshot(context: nil, target: nil)
        }

        guard let runningApplication = NSWorkspace.shared.frontmostApplication else {
            Self.logger.info("rejected app=unknown reason=no-frontmost-application")
            return FocusSnapshot(context: nil, target: nil)
        }
        let frontmost = TargetApplication(
            name: runningApplication.localizedName ?? "Unknown application",
            bundleIdentifier: runningApplication.bundleIdentifier
        )

        let systemWide = AXUIElementCreateSystemWide()
        let systemWideFocusedElement = Self.focusedElement(in: systemWide)
        let systemWideFocusedElementProcessIdentifier = systemWideFocusedElement.flatMap {
            Self.processIdentifier(for: $0)
        }
        let applicationElement = AXUIElementCreateApplication(runningApplication.processIdentifier)
        let systemWideFocusBelongsToFrontmostApplication =
            systemWideFocusedElementProcessIdentifier == runningApplication.processIdentifier
        let context = FocusContext(
            application: frontmost,
            processIdentifier: runningApplication.processIdentifier,
            applicationVersion: Self.applicationVersion(for: runningApplication),
            windowToken: Self.focusedWindowToken(in: applicationElement)
        )
        let applicationFocusedElement: AXUIElement? = if !systemWideFocusBelongsToFrontmostApplication {
            Self.focusedElement(in: applicationElement)
        } else {
            nil
        }
        var manualAccessibilityFocusedElement: AXUIElement?
        var manualAccessibilityResult: AXError?
        if !systemWideFocusBelongsToFrontmostApplication, applicationFocusedElement == nil {
            manualAccessibilityResult = AXUIElementSetAttributeValue(
                applicationElement,
                "AXManualAccessibility" as CFString,
                kCFBooleanTrue
            )
            manualAccessibilityFocusedElement = Self.focusedElement(in: applicationElement)
        }
        var enhancedAccessibilityFocusedElement: AXUIElement?
        var enhancedAccessibilityResult: AXError?
        if !systemWideFocusBelongsToFrontmostApplication,
           applicationFocusedElement == nil,
           manualAccessibilityFocusedElement == nil {
            enhancedAccessibilityResult = AXUIElementSetAttributeValue(
                applicationElement,
                "AXEnhancedUserInterface" as CFString,
                kCFBooleanTrue
            )
            enhancedAccessibilityFocusedElement = Self.focusedElement(in: applicationElement)
        }
        guard let focusedElement = Self.preferredFocusedElement(
            systemWide: systemWideFocusedElement,
            systemWideProcessIdentifier: systemWideFocusedElementProcessIdentifier,
            frontmostProcessIdentifier: runningApplication.processIdentifier,
            frontmostApplication: applicationFocusedElement,
            afterEnablingManualAccessibility: manualAccessibilityFocusedElement,
            afterEnablingEnhancedAccessibility: enhancedAccessibilityFocusedElement
        ) else {
            Self.logger.info(
                "rejected app=\(frontmost.bundleIdentifier ?? "unknown", privacy: .public) reason=no-focused-element system-wide-process-match=\(systemWideFocusBelongsToFrontmostApplication, privacy: .public) manual-accessibility-result=\(manualAccessibilityResult?.rawValue ?? -1, privacy: .public) enhanced-accessibility-result=\(enhancedAccessibilityResult?.rawValue ?? -1, privacy: .public)"
            )
            return FocusSnapshot(context: context, target: nil)
        }

        var roleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focusedElement,
            kAXRoleAttribute as CFString,
            &roleValue
        ) == .success, let role = roleValue as? String else {
            Self.logger.info(
                "rejected app=\(frontmost.bundleIdentifier ?? "unknown", privacy: .public) reason=no-role"
            )
            return FocusSnapshot(context: context, target: nil)
        }

        var subroleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSubroleAttribute as CFString,
            &subroleValue
        )
        var selectedTextSettable = DarwinBoolean(false)
        AXUIElementIsAttributeSettable(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            &selectedTextSettable
        )
        var selectedRangeValue: CFTypeRef?
        let selectedRangeReadable = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeValue
        ) == .success
        let capabilities = TextTargetCapabilities(
            role: role,
            subrole: subroleValue as? String,
            selectedTextSettable: selectedTextSettable.boolValue,
            selectedRangeReadable: selectedRangeReadable
        )
        let source = if systemWideFocusBelongsToFrontmostApplication {
            "system-wide"
        } else if applicationFocusedElement != nil {
            "application"
        } else if manualAccessibilityFocusedElement != nil {
            "manual-accessibility"
        } else {
            "enhanced-accessibility"
        }
        Self.logger.info(
            "observed app=\(frontmost.bundleIdentifier ?? "unknown", privacy: .public) source=\(source, privacy: .public) system-wide-process-match=\(systemWideFocusBelongsToFrontmostApplication, privacy: .public) role=\(role, privacy: .public) subrole=\((subroleValue as? String) ?? "none", privacy: .public) selected-text-settable=\(selectedTextSettable.boolValue, privacy: .public) selected-range-readable=\(selectedRangeReadable, privacy: .public) secure=\(capabilities.isSecure, privacy: .public) eligible=\(capabilities.isEligible, privacy: .public)"
        )

        guard capabilities.isEligible || capabilities.isSecure else {
            return FocusSnapshot(context: context, target: nil)
        }
        return FocusSnapshot(
            context: context,
            target: FocusedTarget(
                context: context,
                accessibilityElementToken: CFHash(focusedElement),
                capabilities: capabilities,
                accessibilityElement: focusedElement
            )
        )
    }

    nonisolated static func preferredFocusedElement<Element>(
        systemWide: Element?,
        systemWideProcessIdentifier: pid_t?,
        frontmostProcessIdentifier: pid_t,
        frontmostApplication: @autoclosure () -> Element?,
        afterEnablingManualAccessibility: @autoclosure () -> Element? = nil,
        afterEnablingEnhancedAccessibility: @autoclosure () -> Element? = nil
    ) -> Element? {
        let trustedSystemWide = systemWideProcessIdentifier == frontmostProcessIdentifier
            ? systemWide
            : nil
        return trustedSystemWide
            ?? frontmostApplication()
            ?? afterEnablingManualAccessibility()
            ?? afterEnablingEnhancedAccessibility()
    }

    private static func focusedElement(in container: AXUIElement) -> AXUIElement? {
        var focusedValue: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                container,
                kAXFocusedUIElementAttribute as CFString,
                &focusedValue
            ) == .success,
            let focusedValue
        else {
            return nil
        }
        return unsafeBitCast(focusedValue, to: AXUIElement.self)
    }

    private static func processIdentifier(for element: AXUIElement) -> pid_t? {
        var processIdentifier: pid_t = 0
        guard AXUIElementGetPid(element, &processIdentifier) == .success else { return nil }
        return processIdentifier
    }

    private static func focusedWindowToken(in application: AXUIElement) -> UInt? {
        var windowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            application,
            kAXFocusedWindowAttribute as CFString,
            &windowValue
        ) == .success, let windowValue else {
            return nil
        }
        return CFHash(windowValue)
    }

    private static func applicationVersion(for application: NSRunningApplication) -> String? {
        guard let bundleURL = application.bundleURL, let bundle = Bundle(url: bundleURL) else {
            return nil
        }
        return bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }
}
