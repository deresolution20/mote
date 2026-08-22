import AppKit
import SwiftUI

enum HotkeyRecorderInput {
    static func configuration(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags
    ) -> HotkeyConfiguration? {
        var modifiers: HotkeyModifiers = []
        if modifierFlags.contains(.command) { modifiers.insert(.command) }
        if modifierFlags.contains(.option) { modifiers.insert(.option) }
        if modifierFlags.contains(.control) { modifiers.insert(.control) }
        if modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        guard !modifiers.isEmpty else { return nil }
        return HotkeyConfiguration(keyCode: UInt32(keyCode), modifiers: modifiers)
    }
}

struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var configuration: HotkeyConfiguration

    func makeCoordinator() -> Coordinator {
        Coordinator(configuration: $configuration)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(
            title: configuration.displayName,
            target: context.coordinator,
            action: #selector(Coordinator.beginRecording)
        )
        button.bezelStyle = .rounded
        context.coordinator.button = button
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        guard !context.coordinator.isRecording else { return }
        button.title = configuration.displayName
    }

    static func dismantleNSView(_ button: NSButton, coordinator: Coordinator) {
        coordinator.stopRecording()
    }

    @MainActor
    final class Coordinator: NSObject {
        @Binding private var configuration: HotkeyConfiguration
        weak var button: NSButton?
        private var monitor: Any?
        fileprivate private(set) var isRecording = false

        init(configuration: Binding<HotkeyConfiguration>) {
            _configuration = configuration
        }

        @objc func beginRecording() {
            guard !isRecording else { return }
            isRecording = true
            button?.title = "Press shortcut…"
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                guard let configuration = HotkeyRecorderInput.configuration(
                    keyCode: event.keyCode,
                    modifierFlags: event.modifierFlags
                ) else {
                    NSSound.beep()
                    return nil
                }
                self.configuration = configuration
                self.stopRecording()
                return nil
            }
        }

        fileprivate func stopRecording() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
            isRecording = false
            button?.title = configuration.displayName
        }
    }
}
