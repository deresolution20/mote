import AppKit
import ApplicationServices
import Foundation

protocol FocusChangeMonitoring: AnyObject {
    var invalidated: Bool { get }
}

final class FocusChangeState: FocusChangeMonitoring, @unchecked Sendable {
    private let lock = NSLock()
    private var storage = false

    var invalidated: Bool {
        lock.withLock { storage }
    }

    func invalidate() {
        lock.withLock { storage = true }
    }
}

/// Invalidates a target capture after the OS reports a focused element or
/// window change. It records one Boolean only: no text, titles, or AX values.
final class FocusChangeMonitor: FocusChangeMonitoring {
    private let state = FocusChangeState()
    private let applicationElement: AXUIElement
    private let observer: AXObserver
    private var observesWindowChanges = false
    private var workspaceObserver: NSObjectProtocol?

    var invalidated: Bool { state.invalidated }

    init?(processIdentifier: pid_t) {
        applicationElement = AXUIElementCreateApplication(processIdentifier)
        var createdObserver: AXObserver?
        guard AXObserverCreate(processIdentifier, Self.callback, &createdObserver) == .success,
              let createdObserver else {
            return nil
        }
        observer = createdObserver

        let context = Unmanaged.passUnretained(state).toOpaque()
        let elementResult = AXObserverAddNotification(
            observer,
            applicationElement,
            kAXFocusedUIElementChangedNotification as CFString,
            context
        )
        let windowResult = AXObserverAddNotification(
            observer,
            applicationElement,
            kAXFocusedWindowChangedNotification as CFString,
            context
        )
        guard Self.canProtectCapture(
            focusedElementResult: elementResult,
            focusedWindowResult: windowResult
        ) else {
            if windowResult == .success {
                AXObserverRemoveNotification(
                    observer,
                    applicationElement,
                    kAXFocusedWindowChangedNotification as CFString
                )
            }
            return nil
        }
        observesWindowChanges = windowResult == .success
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .commonModes
        )
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [state] notification in
            guard let activated = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else {
                state.invalidate()
                return
            }
            if Self.shouldInvalidate(
                activatedPID: activated.processIdentifier,
                capturedPID: processIdentifier
            ) {
                state.invalidate()
            }
        }
    }

    deinit {
        AXObserverRemoveNotification(
            observer,
            applicationElement,
            kAXFocusedUIElementChangedNotification as CFString
        )
        if observesWindowChanges {
            AXObserverRemoveNotification(
                observer,
                applicationElement,
                kAXFocusedWindowChangedNotification as CFString
            )
        }
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .commonModes
        )
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
    }

    private static let callback: AXObserverCallback = { _, _, _, context in
        guard let context else { return }
        Unmanaged<FocusChangeState>
            .fromOpaque(context)
            .takeUnretainedValue()
            .invalidate()
    }

    nonisolated static func shouldInvalidate(
        activatedPID: pid_t,
        capturedPID: pid_t
    ) -> Bool {
        activatedPID != capturedPID
    }

    nonisolated static func canProtectCapture(
        focusedElementResult: AXError,
        focusedWindowResult: AXError
    ) -> Bool {
        focusedElementResult == .success
    }
}
