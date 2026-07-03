import AppKit
import CoreGraphics

/// Inserts text at the cursor of the frontmost app: save clipboard → set text →
/// synthesize ⌘V → restore clipboard. Requires Accessibility permission for the
/// synthesized keystroke to be delivered.
enum TextInjector {
    static func paste(_ text: String) {
        let pasteboard = NSPasteboard.general
        let saved = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)

        // Restore the previous clipboard once the paste has been consumed.
        if let saved {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pasteboard.clearContents()
                pasteboard.setString(saved, forType: .string)
            }
        }
    }
}
