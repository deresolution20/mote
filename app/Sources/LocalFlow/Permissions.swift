import AVFoundation
import AppKit
import ApplicationServices
import CoreGraphics

enum Permissions {
    // MARK: Microphone (AVFoundation)
    static var microphone: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static func requestMicrophone() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    // MARK: Accessibility (synthesized ⌘V)
    static var accessibility: Bool {
        AXIsProcessTrusted()
    }

    static func promptAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: Input Monitoring (global Fn event tap)
    static var inputMonitoring: Bool {
        CGPreflightListenEventAccess()
    }

    static func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
    }

    // MARK: System Settings deep links
    static func openSettings(anchor: String) {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!
        NSWorkspace.shared.open(url)
    }

    static let microphoneAnchor = "Privacy_Microphone"
    static let accessibilityAnchor = "Privacy_Accessibility"
    static let inputMonitoringAnchor = "Privacy_ListenEvent"
}
