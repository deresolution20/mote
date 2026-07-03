import AppKit
import Foundation

/// Push-to-talk on a modifier key via global NSEvent flagsChanged monitors.
/// Modifier-flag events need only Accessibility — NOT Input Monitoring (that's
/// for keystroke content, which we never read). This matters on MDM-managed
/// Macs where the Input Monitoring pane is profile-controlled.
final class HotkeyMonitor {
    enum Key {
        case leftOption
        case fn

        var label: String {
            switch self {
            case .leftOption: return "Left ⌥"
            case .fn: return "Fn"
            }
        }
    }

    private let key: Key
    private let onKeyDown: () -> Void
    private let onKeyUp: () -> Void
    /// Fired when another modifier joins mid-hold (e.g. ⌥⌘ shortcut) — the
    /// press was a chord, not push-to-talk, so the recording should be discarded.
    private let onCancel: () -> Void
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var keyIsDown = false

    private static let leftOptionKeyCode: UInt16 = 58

    init(
        key: Key,
        onKeyDown: @escaping () -> Void,
        onKeyUp: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.key = key
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp
        self.onCancel = onCancel
    }

    func start() -> Bool {
        // Global monitors deliver nothing without Accessibility trust.
        guard Permissions.accessibility else { return false }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
        }
        // Global monitors skip events while our own app is frontmost (e.g. the
        // setup window) — the local monitor covers that case.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
            return event
        }
        return globalMonitor != nil
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handle(_ event: NSEvent) {
        // A second modifier joining mid-hold means a keyboard shortcut, not dictation.
        if keyIsDown, chordModifiers(in: event) {
            keyIsDown = false
            DispatchQueue.main.async(execute: onCancel)
            return
        }

        let down: Bool
        switch key {
        case .fn:
            down = event.modifierFlags.contains(.function)
        case .leftOption:
            // Release resilience: while held, ANY flags event without .option
            // means the key was let go — even if the keycode-58 up event itself
            // was swallowed (secure input fields, app switches).
            if keyIsDown, !event.modifierFlags.contains(.option) {
                keyIsDown = false
                DispatchQueue.main.async(execute: onKeyUp)
                return
            }
            guard event.keyCode == Self.leftOptionKeyCode else { return }
            down = event.modifierFlags.contains(.option)
        }
        guard down != keyIsDown else { return }
        keyIsDown = down
        let action = down ? onKeyDown : onKeyUp
        DispatchQueue.main.async(execute: action)
    }

    private func chordModifiers(in event: NSEvent) -> Bool {
        let others: NSEvent.ModifierFlags = [.command, .shift, .control]
        return !event.modifierFlags.intersection(others).isEmpty
    }
}
