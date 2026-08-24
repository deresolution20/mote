import AppKit
import CoreGraphics

enum PasteboardRestorationPolicy {
    static func shouldRestore(ownedChangeCount: Int, currentChangeCount: Int) -> Bool {
        ownedChangeCount == currentChangeCount
    }
}

/// Inserts transcribed text at the cursor of the frontmost app. Requires
/// Accessibility permission for synthesized events to be delivered.
enum TextInjector {
    enum Method: Equatable {
        /// Types the text directly as synthesized Unicode key events. Never
        /// touches the clipboard — preferred where clipboard managers or DLP
        /// agents may capture pasted content (e.g. managed work machines).
        case type
        /// Saves the clipboard, sets the text, synthesizes ⌘V, restores. Faster
        /// for long text and more compatible with a few apps, but the text
        /// transits the system clipboard briefly.
        case clipboard
    }

    static func insert(_ text: String, method: Method) {
        guard !text.isEmpty else { return }
        switch method {
        case .type: typeText(text)
        case .clipboard: pasteViaClipboard(text)
        }
    }

    static func copy(_ text: String) {
        guard !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // MARK: - Direct typing (no clipboard)

    private static func typeText(_ text: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let units = Array(text.utf16)
        // CGEvent's Unicode buffer is bounded; chunk to a safe size.
        let chunkSize = 16
        var index = 0
        while index < units.count {
            let slice = Array(units[index..<min(index + chunkSize, units.count)])
            guard
                let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else { return }
            down.keyboardSetUnicodeString(stringLength: slice.count, unicodeString: slice)
            up.keyboardSetUnicodeString(stringLength: slice.count, unicodeString: slice)
            down.post(tap: .cgSessionEventTap)
            up.post(tap: .cgSessionEventTap)
            index += chunkSize
        }
    }

    // MARK: - Clipboard + ⌘V (fallback)

    private static func pasteViaClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        let snapshot = snapshotPasteboard(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let ownedChangeCount = pasteboard.changeCount

        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9 // 'v'
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)

        // Restore the FULL previous clipboard (all types, not just plain text)
        // once the paste has been consumed, but never overwrite clipboard
        // content copied by the user or another application in the meantime.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard PasteboardRestorationPolicy.shouldRestore(
                ownedChangeCount: ownedChangeCount,
                currentChangeCount: pasteboard.changeCount
            ) else { return }
            restorePasteboard(pasteboard, from: snapshot)
        }
    }

    /// Every item and every type currently on the pasteboard.
    private static func snapshotPasteboard(_ pb: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        pb.pasteboardItems?.map { item in
            var typed: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { typed[type] = data }
            }
            return typed
        } ?? []
    }

    private static func restorePasteboard(_ pb: NSPasteboard, from snapshot: [[NSPasteboard.PasteboardType: Data]]) {
        pb.clearContents()
        guard !snapshot.isEmpty else { return }
        let items = snapshot.map { typed -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in typed { item.setData(data, forType: type) }
            return item
        }
        pb.writeObjects(items)
    }
}
