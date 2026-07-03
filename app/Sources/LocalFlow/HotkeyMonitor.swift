import AppKit
import Foundation

/// Push-to-talk on the Fn (globe) key via global NSEvent flagsChanged monitors.
/// Modifier-flag events need only Accessibility — NOT Input Monitoring (that's
/// for real keystroke content, which we never read). This matters on
/// MDM-managed Macs where the Input Monitoring pane is profile-controlled.
/// Caveat: set System Settings → Keyboard → "Press 🌐 key to" = "Do Nothing"
/// so macOS doesn't also act on the key.
final class HotkeyMonitor {
    private let onKeyDown: () -> Void
    private let onKeyUp: () -> Void
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var fnIsDown = false

    init(onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void) {
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp
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
        let down = event.modifierFlags.contains(.function)
        guard down != fnIsDown else { return }
        fnIsDown = down
        let action = down ? onKeyDown : onKeyUp
        DispatchQueue.main.async(execute: action)
    }
}
