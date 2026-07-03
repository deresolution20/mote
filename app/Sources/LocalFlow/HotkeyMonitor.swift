import CoreGraphics
import Foundation

/// Push-to-talk on the Fn (globe) key via a listen-only CGEvent tap.
/// Fn arrives as .flagsChanged with .maskSecondaryFn — hold = down, release = up.
/// Requires Input Monitoring. Caveat: set System Settings → Keyboard →
/// "Press 🌐 key to" = "Do Nothing" so macOS doesn't also act on it.
final class HotkeyMonitor {
    private let onKeyDown: () -> Void
    private let onKeyUp: () -> Void
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var fnIsDown = false

    init(onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void) {
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp
    }

    func start() -> Bool {
        let mask = (1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            monitor.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        // The system disables quiet taps; re-arm immediately.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard type == .flagsChanged else { return }
        let down = event.flags.contains(.maskSecondaryFn)
        guard down != fnIsDown else { return }
        fnIsDown = down
        let action = down ? onKeyDown : onKeyUp
        DispatchQueue.main.async(execute: action)
    }
}
