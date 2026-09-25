import Foundation

enum DeliveryMode: String, Codable, CaseIterable, Sendable {
    case automatic
    case privacyFirst
    case compatibility

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .privacyFirst: "Privacy-first"
        case .compatibility: "Compatibility"
        }
    }

    var detail: String {
        switch self {
        case .automatic:
            "Uses verified Accessibility insertion when possible, then remembers a proven fallback for this app version."
        case .privacyFirst:
            "Avoids the clipboard by sending text events when Accessibility insertion is unavailable."
        case .compatibility:
            "Uses a temporary, Mac-only clipboard paste when Accessibility insertion is unavailable."
        }
    }
}

enum DeliveryMethod: String, Codable, Sendable {
    case accessibility
    case directEvents
    case clipboard
}

enum DeliveryAttempt: Equatable, Sendable {
    case verified(DeliveryMethod)
    case unverified(DeliveryMethod)
    case unavailable(DeliveryMethod)
}

enum DeliveryBlockReason: String, Equatable, Sendable {
    case noEditableTarget
    case focusChanged
    case secureField
    case deliveryUnavailable
}

enum PendingDeliveryReason: Equatable, Sendable {
    case manual
    case blocked(DeliveryBlockReason)
    case unverified(DeliveryMethod)
}

struct DeliverySurfaceKey: Hashable, Codable, Sendable {
    let bundleIdentifier: String
    let applicationVersion: String
    let operatingSystemVersion: String
    let accessibilityRole: String
}

extension FocusedTarget {
    func deliverySurfaceKey(
        operatingSystemVersion: String = ProcessInfo.processInfo.operatingSystemVersionString
    ) -> DeliverySurfaceKey? {
        guard let bundleIdentifier = application.bundleIdentifier,
              let applicationVersion = context.applicationVersion else {
            return nil
        }
        return DeliverySurfaceKey(
            bundleIdentifier: bundleIdentifier,
            applicationVersion: applicationVersion,
            operatingSystemVersion: operatingSystemVersion,
            accessibilityRole: capabilities.role
        )
    }
}

enum TextDeliveryPolicy {
    static func fallbackMethod(
        mode: DeliveryMode,
        preferredVerifiedMethod: DeliveryMethod?
    ) -> DeliveryMethod {
        switch mode {
        case .automatic:
            preferredVerifiedMethod == .directEvents ? .directEvents : .clipboard
        case .privacyFirst:
            .directEvents
        case .compatibility:
            .clipboard
        }
    }
}
