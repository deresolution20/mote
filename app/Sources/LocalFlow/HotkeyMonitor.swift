import Carbon
import Foundation
import LocalFlowCleanup

/// Registers one explicit Carbon hotkey. Unlike a global key monitor, this
/// receives no keystroke content and needs no Input Monitoring permission.
final class HotkeyMonitor {
    private static let signature: OSType = 0x47525444 // "GRTD"
    private static let identifier: UInt32 = 1

    private let configuration: HotkeyConfiguration
    private var reducer: HotkeyInteractionReducer
    private let onBeginCapture: () -> Void
    private let onEndCapture: () -> Void
    private let onCancelCapture: () -> Void

    private var hotkeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(
        configuration: HotkeyConfiguration,
        mode: CaptureMode,
        onBeginCapture: @escaping () -> Void,
        onEndCapture: @escaping () -> Void,
        onCancelCapture: @escaping () -> Void
    ) {
        self.configuration = configuration
        reducer = HotkeyInteractionReducer(mode: mode)
        self.onBeginCapture = onBeginCapture
        self.onEndCapture = onEndCapture
        self.onCancelCapture = onCancelCapture
    }

    deinit {
        stop()
    }

    func start() -> Bool {
        guard configuration.isValid, Permissions.accessibility else { return false }
        guard installEventHandler() else { return false }

        let identifier = EventHotKeyID(signature: Self.signature, id: Self.identifier)
        let status = RegisterEventHotKey(
            configuration.keyCode,
            carbonModifiers(for: configuration.modifiers),
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        guard status == noErr else {
            removeEventHandler()
            return false
        }
        return true
    }

    func stop() {
        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
        }
        hotkeyRef = nil
        removeEventHandler()
    }

    private func installEventHandler() -> Bool {
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userData).takeUnretainedValue()
                return monitor.handle(event)
            },
            eventTypes.count,
            &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        return status == noErr
    }

    private func removeEventHandler() {
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
        handlerRef = nil
    }

    private func handle(_ event: EventRef) -> OSStatus {
        var receivedIdentifier = EventHotKeyID()
        let readStatus = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &receivedIdentifier
        )
        guard
            readStatus == noErr,
            receivedIdentifier.signature == Self.signature,
            receivedIdentifier.id == Self.identifier
        else {
            return noErr
        }

        let input: HotkeyInteractionReducer.Event = GetEventKind(event) == UInt32(kEventHotKeyPressed)
            ? .pressed
            : .released
        let action = reducer.handle(input)
        DispatchQueue.main.async { [weak self] in
            self?.perform(action)
        }
        return noErr
    }

    private func perform(_ action: HotkeyInteractionReducer.Action) {
        switch action {
        case .beginCapture: onBeginCapture()
        case .endCapture: onEndCapture()
        case .cancelCapture: onCancelCapture()
        case .ignore: break
        }
    }

    private func carbonModifiers(for modifiers: HotkeyModifiers) -> UInt32 {
        var flags: UInt32 = 0
        if modifiers.contains(.command) { flags |= UInt32(cmdKey) }
        if modifiers.contains(.option) { flags |= UInt32(optionKey) }
        if modifiers.contains(.control) { flags |= UInt32(controlKey) }
        if modifiers.contains(.shift) { flags |= UInt32(shiftKey) }
        return flags
    }
}
