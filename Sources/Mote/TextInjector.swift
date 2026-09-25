import AppKit
import ApplicationServices
import CoreGraphics

enum PasteboardRestorationPolicy {
    static func shouldRestore(ownedChangeCount: Int, currentChangeCount: Int) -> Bool {
        ownedChangeCount == currentChangeCount
    }
}

struct TextSelectionSnapshot: Equatable {
    let range: CFRange

    func expectedRange(afterInsertingUTF16Count count: Int) -> CFRange {
        CFRange(location: range.location + count, length: 0)
    }

    static func read(from element: AXUIElement) -> Self? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &value
        ) == .success, let value, CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        var range = CFRange()
        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetValue(axValue, .cfRange, &range) else { return nil }
        return Self(range: range)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.range.location == rhs.range.location && lhs.range.length == rhs.range.length
    }
}

enum UnicodeEventChunker {
    static func chunks(_ text: String, maximumUTF16Units: Int = 16) -> [String] {
        guard !text.isEmpty else { return [] }
        guard maximumUTF16Units > 0 else { return [text] }

        var chunks: [String] = []
        var current = ""
        for character in text {
            let next = String(character)
            if !current.isEmpty,
               current.utf16.count + next.utf16.count > maximumUTF16Units {
                chunks.append(current)
                current = next
            } else {
                current += next
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}

@MainActor
protocol TextInjecting {
    func insert(
        _ text: String,
        method: DeliveryMethod,
        target: FocusedTarget
    ) async -> DeliveryAttempt
}

@MainActor
struct SystemTextInjector: TextInjecting {
    func insert(
        _ text: String,
        method: DeliveryMethod,
        target: FocusedTarget
    ) async -> DeliveryAttempt {
        await TextInjector.insert(text, method: method, target: target)
    }
}

/// Inserts transcribed text at the cursor of the frontmost app. Requires
/// Accessibility permission for synthesized events to be delivered.
@MainActor
enum TextInjector {
    static func insert(
        _ text: String,
        method: DeliveryMethod,
        target: FocusedTarget
    ) async -> DeliveryAttempt {
        guard !text.isEmpty else { return .unavailable(method) }
        switch method {
        case .accessibility:
            return await replaceSelectedText(text, in: target)
        case .directEvents:
            return await typeTextAndVerify(text, in: target)
        case .clipboard:
            return await pasteViaClipboardAndVerify(text, in: target)
        }
    }

    static func copy(_ text: String) {
        guard !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private static func replaceSelectedText(
        _ text: String,
        in target: FocusedTarget
    ) async -> DeliveryAttempt {
        guard target.capabilities.canVerifySelectedTextReplacement,
              let element = target.accessibilityElement else {
            return .unavailable(.accessibility)
        }
        let before = TextSelectionSnapshot.read(from: element)
        let result = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFString
        )
        // Once the setter has been called, conservatively assume a mutation
        // may have happened even when the API reports an error. Retrying via a
        // second mechanism could duplicate sensitive text.
        guard result == .success else { return .unverified(.accessibility) }
        return await verifiesSelectionChange(
            from: before,
            insertedUTF16Count: text.utf16.count,
            element: element,
            attempts: 8
        ) ? .verified(.accessibility) : .unverified(.accessibility)
    }

    private static func typeTextAndVerify(
        _ text: String,
        in target: FocusedTarget
    ) async -> DeliveryAttempt {
        let before = target.accessibilityElement.flatMap(TextSelectionSnapshot.read)
        let source = CGEventSource(stateID: .combinedSessionState)
        var postedAnyChunk = false
        for chunk in UnicodeEventChunker.chunks(text) {
            let units = Array(chunk.utf16)
            guard
                let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else {
                return postedAnyChunk
                    ? .unverified(.directEvents)
                    : .unavailable(.directEvents)
            }
            down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            down.post(tap: .cgSessionEventTap)
            up.post(tap: .cgSessionEventTap)
            postedAnyChunk = true
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        guard let element = target.accessibilityElement, before != nil else {
            return .unverified(.directEvents)
        }
        return await verifiesSelectionChange(
            from: before,
            insertedUTF16Count: text.utf16.count,
            element: element,
            attempts: 12
        ) ? .verified(.directEvents) : .unverified(.directEvents)
    }

    // MARK: - Clipboard + ⌘V (fallback)

    private static func pasteViaClipboardAndVerify(
        _ text: String,
        in target: FocusedTarget
    ) async -> DeliveryAttempt {
        let pasteboard = NSPasteboard.general
        let snapshot = snapshotPasteboard(pasteboard)
        let before = target.accessibilityElement.flatMap(TextSelectionSnapshot.read)

        pasteboard.prepareForNewContents(with: .currentHostOnly)
        guard pasteboard.setString(text, forType: .string) else {
            restorePasteboard(pasteboard, from: snapshot)
            return .unavailable(.clipboard)
        }
        let ownedChangeCount = pasteboard.changeCount

        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        else {
            restorePasteboardIfOwned(
                pasteboard,
                snapshot: snapshot,
                ownedChangeCount: ownedChangeCount
            )
            return .unavailable(.clipboard)
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)

        let verified: Bool
        if let element = target.accessibilityElement, before != nil {
            verified = await verifiesSelectionChange(
                from: before,
                insertedUTF16Count: text.utf16.count,
                element: element,
                attempts: 30
            )
        } else {
            try? await Task.sleep(nanoseconds: 750_000_000)
            verified = false
        }
        restorePasteboardIfOwned(
            pasteboard,
            snapshot: snapshot,
            ownedChangeCount: ownedChangeCount
        )
        return verified ? .verified(.clipboard) : .unverified(.clipboard)
    }

    private static func verifiesSelectionChange(
        from before: TextSelectionSnapshot?,
        insertedUTF16Count: Int,
        element: AXUIElement,
        attempts: Int
    ) async -> Bool {
        guard let expected = before?.expectedRange(
            afterInsertingUTF16Count: insertedUTF16Count
        ) else {
            return false
        }
        for _ in 0..<attempts {
            if TextSelectionSnapshot.read(from: element) == TextSelectionSnapshot(range: expected) {
                return true
            }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        return false
    }

    private static func restorePasteboardIfOwned(
        _ pasteboard: NSPasteboard,
        snapshot: [[NSPasteboard.PasteboardType: Data]],
        ownedChangeCount: Int
    ) {
        guard PasteboardRestorationPolicy.shouldRestore(
            ownedChangeCount: ownedChangeCount,
            currentChangeCount: pasteboard.changeCount
        ) else { return }
        restorePasteboard(pasteboard, from: snapshot)
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
        pb.prepareForNewContents(with: .currentHostOnly)
        guard !snapshot.isEmpty else { return }
        let items = snapshot.map { typed -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in typed { item.setData(data, forType: type) }
            return item
        }
        pb.writeObjects(items)
    }
}
