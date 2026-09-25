# Mote Reliable Text Delivery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Mote's global typing-or-paste switch with a small, capability-driven delivery pipeline that refuses secure targets, prevents focus drift, verifies text insertion where possible, and always preserves recoverable text.

**Out of scope:** Shipping an InputMethodKit input source, per-application bundle-ID branches, transcript/content telemetry, automatic duplicate-prone retries after an unverified attempt, and App Store sandboxing.

**Architecture:** A target snapshot captures process, window, element identity, security state, and readable/writable text capabilities. A pure policy selects Accessibility replacement first when verifiable, otherwise the user-selected Automatic, Privacy-first, or Compatibility fallback. OS adapters return verified, unverified, or unavailable; the coordinator converts that result into honest history and recovery state.

**Tech stack:** Swift 5.10, SwiftUI, AppKit Accessibility, Core Graphics events, NSPasteboard, Swift Testing, macOS 26.

**Spec:** `docs/reports/mote-universal-text-insertion-research.html`

## Global constraints

- Mote remains Developer ID distributed and unsandboxed because it inserts text across applications.
- Microphone audio and transcript text must remain on-device; no transcript, field-value, selection-text, or window-title telemetry may be added.
- New installations keep automatic insertion off until the user enables it.
- Secure text fields must never receive automatic or manual insertion from Mote.
- An unverified attempt must never trigger an automatic second attempt.
- Clipboard-backed insertion must use host-only pasteboard contents and must not overwrite a later clipboard change.
- Explicit user Copy remains a normal system copy operation; only temporary insertion paste is host-only.
- Capability routing must not contain application bundle-ID allowlists or deny-lists.
- Existing `mote.injectByTyping` preferences migrate to Privacy-first (`true`) or Compatibility (`false`); new installations default to Automatic.
- No git commit, push, merge, or tag is performed without Brice's explicit approval.

## File structure

- Create `app/Sources/Mote/Models/TextDelivery.swift`: delivery mode, method, block reason, adapter result, pending reason, and pure routing policy.
- Modify `app/Sources/Mote/Services/FocusedTargetInspector.swift`: one focus snapshot API; process/window identity; secure-field and text-capability discovery.
- Create `app/Sources/Mote/Services/FocusChangeMonitor.swift`: narrowly scoped AX observer that invalidates a capture after a real focused-element or focused-window notification.
- Create `app/Sources/Mote/Stores/VerifiedDeliveryStore.swift`: bounded local memory of bundle/app/OS/role and a previously verified fallback method; no user content.
- Modify `app/Sources/Mote/TextInjector.swift`: verified AX replacement, grapheme-safe event chunks, host-only temporary clipboard, adaptive restore, and injectable OS boundary.
- Modify `app/Sources/Mote/Services/OutputDeliveryCoordinator.swift`: async hybrid routing, strict capture validation, honest outcomes, and pending recovery.
- Modify `app/Sources/Mote/Models/PendingDictation.swift`: attach a human-readable recovery reason without persisting new sensitive data.
- Modify `app/Sources/Mote/Models/DictationRecord.swift`: add backward-compatible verified, unverified, and blocked outcome cases.
- Modify `app/Sources/Mote/Stores/MotePreferences.swift`, `app/Sources/Mote/Migration/MoteV1Migration.swift`, `app/Sources/Mote/AppState.swift`, and `app/Sources/Mote/Views/MoteSettingsView.swift`: replace the Boolean insertion implementation setting with three user-facing delivery modes.
- Modify `app/Sources/Mote/Views/CapturePanelView.swift`, `app/Sources/Mote/Models/CapturePanelSnapshot.swift`, and `app/Sources/Mote/Views/HistoryViews.swift`: show precise recovery and outcome language.
- Modify `SECURITY.md` and `README.md`: document the actual permission, pasteboard, secure-field, and compatibility boundaries.
- Add/update focused tests in `app/Tests/MoteTests` for every behavior below.

---

### Task 1: Delivery model and preference migration

**Files:** Create: `app/Sources/Mote/Models/TextDelivery.swift` / Modify: `app/Sources/Mote/Stores/MotePreferences.swift`, `app/Sources/Mote/Migration/MoteV1Migration.swift`, `app/Sources/Mote/AppState.swift`, `app/Tests/MoteTests/MotePreferencesTests.swift` / Test: `app/Tests/MoteTests/TextDeliveryPolicyTests.swift`

**Interfaces:** Consumes: existing `TargetApplication` and `UserDefaults` migration / Produces: `DeliveryMode`, `DeliveryMethod`, `DeliveryAttempt`, `DeliveryBlockReason`, `PendingDeliveryReason`, `DeliverySurfaceKey`, and `TextDeliveryPolicy.fallbackMethod(mode:preferredVerifiedMethod:)`.

- [ ] **Step 1: Write failing model and migration tests**

```swift
@Test func automaticFallsBackToClipboardWithoutVerifiedHistory() {
    #expect(TextDeliveryPolicy.fallbackMethod(mode: .automatic, preferredVerifiedMethod: nil) == .clipboard)
}

@Test func privacyFirstNeverChoosesClipboard() {
    #expect(TextDeliveryPolicy.fallbackMethod(mode: .privacyFirst, preferredVerifiedMethod: .clipboard) == .directEvents)
}

@Test func legacyDirectTypingPreferenceMigratesToPrivacyFirst() {
    let defaults = UserDefaults(suiteName: "MotePreferencesTests.\(UUID())")!
    defaults.set(true, forKey: "mote.injectByTyping")
    let preferences = MotePreferences(defaults: defaults, legacyDefaults: nil)
    #expect(preferences.deliveryMode == .privacyFirst)
}
```

- [ ] **Step 2: Run the focused tests**

Run: `cd app && swift test --filter 'TextDeliveryPolicyTests|MotePreferencesTests'`

Expected: FAIL because the delivery model and `deliveryMode` preference do not exist.

- [ ] **Step 3: Add the minimal model and migration**

```swift
enum DeliveryMode: String, Codable, CaseIterable, Sendable {
    case automatic
    case privacyFirst
    case compatibility
}

enum DeliveryMethod: String, Codable, Sendable {
    case accessibility
    case directEvents
    case clipboard
}

enum DeliveryAttempt: Equatable, Sendable {
    case verified(DeliveryMethod)
    case unverified(DeliveryMethod)
    case unavailable(DeliveryMethod)
}

enum DeliveryBlockReason: String, Equatable, Sendable {
    case noEditableTarget
    case focusChanged
    case secureField
}

enum PendingDeliveryReason: Equatable, Sendable {
    case manual
    case blocked(DeliveryBlockReason)
    case unverified(DeliveryMethod)
}

enum TextDeliveryPolicy {
    static func fallbackMethod(
        mode: DeliveryMode,
        preferredVerifiedMethod: DeliveryMethod?
    ) -> DeliveryMethod {
        switch mode {
        case .privacyFirst: .directEvents
        case .compatibility: .clipboard
        case .automatic:
            preferredVerifiedMethod == .directEvents ? .directEvents : .clipboard
        }
    }
}
```

Persist `mote.deliveryMode`. If it is absent but `mote.injectByTyping` exists, derive `.privacyFirst` from `true` and `.compatibility` from `false`, save the new raw value, and retain the old key only for backward rollback compatibility. Default to `.automatic` when neither key exists.

- [ ] **Step 4: Verify the focused tests**

Run: `cd app && swift test --filter 'TextDeliveryPolicyTests|MotePreferencesTests'`

Expected: PASS with the new delivery model and old-preference migration covered.

- [ ] **Step 5: Review checkpoint without committing**

Run: `git diff --check && git diff --stat`

Done: the policy is pure, the default is Automatic, existing user intent migrates deterministically, and no commit is created.

---

### Task 2: Security-aware target snapshot and focus lease

**Files:** Create: `app/Sources/Mote/Services/FocusChangeMonitor.swift` / Modify: `app/Sources/Mote/Services/FocusedTargetInspector.swift`, `app/Tests/MoteTests/FocusedTargetInspectorTests.swift`, `app/Tests/MoteTests/OutputDeliveryCoordinatorTests.swift`

**Interfaces:** Consumes: `TargetApplication` / Produces: `FocusContext`, `TextTargetCapabilities`, `FocusSnapshot`, `FocusedTarget`, `FocusedTargetInspecting.snapshot()`, and `FocusChangeMonitoring.invalidated`.

- [ ] **Step 1: Write failing focus-security tests**

```swift
@Test func secureSubroleIsAlwaysBlocked() {
    let capabilities = TextTargetCapabilities(
        role: kAXTextFieldRole as String,
        subrole: kAXSecureTextFieldSubrole as String,
        selectedTextSettable: true,
        selectedRangeReadable: true
    )
    #expect(capabilities.isSecure)
    #expect(!capabilities.isEligible)
}

@Test func settableSelectedTextMakesACustomRoleEligible() {
    let capabilities = TextTargetCapabilities(
        role: kAXGroupRole as String,
        subrole: nil,
        selectedTextSettable: true,
        selectedRangeReadable: true
    )
    #expect(capabilities.isEligible)
}

@Test func missingTargetCannotRebindAcrossWindows() {
    let capture = TargetCapture.fixture(windowToken: 1, target: nil)
    let current = FocusSnapshot.fixture(windowToken: 2, targetToken: 7)
    #expect(OutputDeliveryCoordinator.validatedTarget(capture: capture, current: current) == nil)
}
```

- [ ] **Step 2: Run the focused tests**

Run: `cd app && swift test --filter 'FocusedTargetInspectorTests|OutputDeliveryCoordinatorTests'`

Expected: FAIL because capability snapshots, window identity, and focus invalidation do not exist.

- [ ] **Step 3: Implement one snapshot boundary and one observer**

```swift
struct FocusContext: Equatable {
    let application: TargetApplication
    let processIdentifier: pid_t
    let applicationVersion: String?
    let windowToken: UInt?
}

struct TextTargetCapabilities: Equatable {
    let role: String
    let subrole: String?
    let selectedTextSettable: Bool
    let selectedRangeReadable: Bool

    var isSecure: Bool { subrole == kAXSecureTextFieldSubrole as String }
    var isEligible: Bool {
        !isSecure && (selectedTextSettable || Self.standardRoles.contains(role))
    }
}

struct FocusSnapshot {
    let context: FocusContext?
    let target: FocusedTarget?
}
```

`FocusedTargetInspector.snapshot()` must make one frontmost-app query, enable the documented Electron/Chromium accessibility switches before target classification, capture the focused window token, and return secure targets as identifiable-but-ineligible rather than silently treating them as no target. `FocusChangeMonitor` observes only `kAXFocusedUIElementChangedNotification` and `kAXFocusedWindowChangedNotification`; it stores one lock-protected Boolean and never records titles or field contents.

- [ ] **Step 4: Verify the focus tests**

Run: `cd app && swift test --filter 'FocusedTargetInspectorTests|OutputDeliveryCoordinatorTests'`

Expected: PASS for secure refusal, custom settable targets, same-window delayed exposure, different-window rejection, and invalidated-capture rejection.

- [ ] **Step 5: Review checkpoint without committing**

Run: `git diff --check && git diff --stat`

Done: focus identity includes PID and window, target capabilities replace the four-role gate, and the observer records no sensitive strings.

---

### Task 3: Verifiable and privacy-safe OS delivery adapters

**Files:** Modify: `app/Sources/Mote/TextInjector.swift`, `app/Tests/MoteTests/TextInjectorTests.swift` / Create: `app/Tests/MoteTests/TextDeliveryVerificationTests.swift`

**Interfaces:** Consumes: `FocusedTarget`, `DeliveryMethod`, `DeliveryAttempt` / Produces: `TextInjecting.insert(_:method:target:) async -> DeliveryAttempt`, `TextSelectionSnapshot.expectedRange(afterInsertingUTF16Count:)`, and `UnicodeEventChunker.chunks(_:maximumUTF16Units:)`.

- [ ] **Step 1: Write failing adapter-policy tests**

```swift
@Test func chunksNeverSplitExtendedGraphemeClusters() {
    let text = "123456789012345👨‍👩‍👧‍👦é"
    let chunks = UnicodeEventChunker.chunks(text, maximumUTF16Units: 16)
    #expect(chunks.joined() == text)
    #expect(chunks.allSatisfy { !$0.isEmpty })
}

@Test func expectedRangeAdvancesByInsertedUTF16Length() {
    let snapshot = TextSelectionSnapshot(range: CFRange(location: 4, length: 2))
    #expect(snapshot.expectedRange(afterInsertingUTF16Count: "🙂".utf16.count) == CFRange(location: 6, length: 0))
}

@Test func clipboardOwnershipLossPreventsRestoration() {
    #expect(!PasteboardRestorationPolicy.shouldRestore(ownedChangeCount: 4, currentChangeCount: 5))
}
```

- [ ] **Step 2: Run the focused tests**

Run: `cd app && swift test --filter 'TextInjectorTests|TextDeliveryVerificationTests'`

Expected: FAIL because grapheme-safe chunking and selection-range verification do not exist.

- [ ] **Step 3: Implement the minimal adapters**

```swift
protocol TextInjecting {
    func insert(_ text: String, method: DeliveryMethod, target: FocusedTarget) async -> DeliveryAttempt
}

enum UnicodeEventChunker {
    static func chunks(_ text: String, maximumUTF16Units: Int = 16) -> [String] {
        text.reduce(into: [String]()) { chunks, character in
            let value = String(character)
            if let last = chunks.indices.last,
               chunks[last].utf16.count + value.utf16.count <= maximumUTF16Units {
                chunks[last] += value
            } else {
                chunks.append(value)
            }
        }
    }
}
```

The Accessibility adapter may fall through only when `AXUIElementSetAttributeValue` returns a definite failure before mutation. After a successful setter call, return verified only if the selected range advances by the inserted UTF-16 length; otherwise return unverified and stop. Direct events post one grapheme-safe chunk at a time with a short bounded yield, then use the same range-only verification when readable. Temporary paste must call `prepareForNewContents(with: .currentHostOnly)`, snapshot every item/type, post Command-V, verify by selection range when readable, restore immediately on confirmation or after a conservative bounded wait, and restore only while `changeCount` ownership remains. Explicit `copy(_:)` keeps normal pasteboard semantics. No adapter reads `kAXValueAttribute`, selected text, or window titles.

- [ ] **Step 4: Verify adapter tests**

Run: `cd app && swift test --filter 'TextInjectorTests|TextDeliveryVerificationTests'`

Expected: PASS for Unicode boundaries, UTF-16 selection replacement, method outcomes, host-only preparation abstraction, and clipboard ownership.

- [ ] **Step 5: Review checkpoint without committing**

Run: `git diff --check && git diff --stat`

Done: no adapter logs text, no unverified method retries automatically, and temporary paste never propagates over Universal Clipboard.

---

### Task 4: Hybrid coordinator, local verified preference, and guaranteed recovery

**Files:** Create: `app/Sources/Mote/Stores/VerifiedDeliveryStore.swift`, `app/Tests/MoteTests/VerifiedDeliveryStoreTests.swift` / Modify: `app/Sources/Mote/Services/OutputDeliveryCoordinator.swift`, `app/Sources/Mote/Models/PendingDictation.swift`, `app/Sources/Mote/Models/DictationRecord.swift`, `app/Sources/Mote/AppState.swift`, `app/Tests/MoteTests/OutputDeliveryCoordinatorTests.swift`, `app/Tests/MoteTests/AppStateStreamingFailureTests.swift`

**Interfaces:** Consumes: `TargetCapture`, `DeliveryMode`, `TextInjecting`, target capabilities, and `VerifiedDeliveryStore` / Produces: `TextDeliveryResult`, `complete(raw:cleaned:format:formattingOptions:autoInsert:targetCapture:deliveryMode:duration:)`, async manual/history insertion, pending reasons, and bounded content-free compatibility memory.

- [ ] **Step 1: Write failing coordinator tests**

```swift
@Test func secureTargetIsBlockedWithoutCallingAnAdapter() async {
    let injector = RecordingInjector()
    let result = await coordinator(injector: injector).complete(
        raw: "secret", cleaned: "secret", format: .plain,
        formattingOptions: .init(preserveCodeAndBackticks: false),
        autoInsert: true, targetCapture: .secureFixture,
        deliveryMode: .automatic, duration: 0.5
    )
    #expect(result.delivery == .blocked(.secureField, .fixture))
    #expect(result.pending?.deliveryReason == .blocked(.secureField))
    #expect(injector.calls.isEmpty)
}

@Test func unavailableAXFallsBackOnceToClipboard() async {
    let injector = SequenceInjector(results: [.unavailable(.accessibility), .verified(.clipboard)])
    let result = await coordinator(injector: injector).complete(
        raw: "hello", cleaned: "Hello", format: .plain,
        formattingOptions: .init(preserveCodeAndBackticks: false),
        autoInsert: true, targetCapture: .editableFixture,
        deliveryMode: .automatic, duration: 0.5
    )
    #expect(result.delivery == .insertedVerified(.clipboard, .fixture))
    #expect(injector.methods == [.accessibility, .clipboard])
}

@Test func unverifiedAttemptIsPreservedAndNeverRetried() async {
    let injector = SequenceInjector(results: [.unverified(.directEvents)])
    let result = await coordinator(injector: injector).complete(
        raw: "hello", cleaned: "Hello", format: .plain,
        formattingOptions: .init(preserveCodeAndBackticks: false),
        autoInsert: true, targetCapture: .editableFixtureWithoutAXWrite,
        deliveryMode: .privacyFirst, duration: 0.5
    )
    #expect(result.pending?.deliveryReason == .unverified(.directEvents))
    #expect(injector.methods == [.directEvents])
}
```

- [ ] **Step 2: Run the focused tests**

Run: `cd app && swift test --filter 'OutputDeliveryCoordinatorTests|AppStateStreamingFailureTests'`

Expected: FAIL because the coordinator still accepts a global injection method and has no secure/unverified recovery state.

- [ ] **Step 3: Implement one auditable decision flow**

```swift
if capture.focusMonitor.invalidated { return blocked(.focusChanged) }
guard let target = validatedTarget(capture: capture, current: inspector.snapshot()) else {
    return blocked(.noEditableTarget)
}
guard !target.capabilities.isSecure else { return blocked(.secureField) }

if target.capabilities.canVerifySelectedTextReplacement {
    let attempt = await injector.insert(text, method: .accessibility, target: target)
    if attempt != .unavailable(.accessibility) { return finish(attempt) }
}
let fallback = TextDeliveryPolicy.fallbackMethod(mode: deliveryMode, preferredVerifiedMethod: nil)
return finish(await injector.insert(text, method: fallback, target: target))
```

In production, pass `verifiedStore.preferredMethod(for: target)` instead of `nil`; record only a verified `.directEvents` or `.clipboard` result. Key records by bundle identifier, application version, operating-system version, and Accessibility role; cap the dictionary at 128 entries and expose `reset()`. Keep pending text for manual mode, every block, and every unverified attempt. Clear pending only for verified insertion or explicit Copy. Preserve old history decoding by keeping `typedAttempted` as a legacy enum case while writing the new `insertedVerified`, `insertedUnverified`, `blockedFocusChanged`, `blockedSecureField`, and `blockedNoTarget` cases.

- [ ] **Step 4: Verify coordinator behavior**

Run: `cd app && swift test --filter 'OutputDeliveryCoordinatorTests|VerifiedDeliveryStoreTests|AppStateStreamingFailureTests|HistoryStoreTests'`

Expected: PASS for strict focus validation, secure refusal, safe AX fallback, no duplicate retries, recovery preservation, and old history decoding.

- [ ] **Step 5: Review checkpoint without committing**

Run: `git diff --check && git diff --stat`

Done: the complete routing decision fits in one coordinator flow and every failure produces a recoverable transcript.

---

### Task 5: User-facing modes, honest status, and security documentation

**Files:** Modify: `app/Sources/Mote/Views/MoteSettingsView.swift`, `app/Sources/Mote/Views/CapturePanelView.swift`, `app/Sources/Mote/Models/CapturePanelSnapshot.swift`, `app/Sources/Mote/Views/HistoryViews.swift`, `app/Tests/MoteTests/MoteSettingsSnapshotTests.swift`, `app/Tests/MoteTests/CapturePanelSnapshotTests.swift`, `README.md`, `SECURITY.md`

**Interfaces:** Consumes: `DeliveryMode`, `PendingDeliveryReason`, `InsertionOutcome` / Produces: human-readable mode descriptions, recovery titles, and security-review documentation.

- [ ] **Step 1: Write failing presentation tests**

```swift
@Test func deliveryModesExplainTheirPrivacyBoundary() {
    #expect(DeliveryMode.automatic.detail.contains("clipboard"))
    #expect(DeliveryMode.privacyFirst.detail.contains("Never uses the clipboard"))
    #expect(DeliveryMode.compatibility.detail.contains("Clipboard History"))
}

@Test func unverifiedDeliveryWarnsAgainstDuplicateRetry() {
    let pending = PendingDictation.fixture(reason: .unverified(.clipboard))
    let snapshot = CapturePanelSnapshot.make(state: .idle, pending: pending, autoInsert: true, recentRecords: [])
    #expect(snapshot.pendingTitle == "Sent, not confirmed")
    #expect(snapshot.pendingDetail.contains("may already be inserted"))
}

@Test func secureFieldBlockHasSpecificRecoveryCopy() {
    let pending = PendingDictation.fixture(reason: .blocked(.secureField))
    let snapshot = CapturePanelSnapshot.make(state: .idle, pending: pending, autoInsert: true, recentRecords: [])
    #expect(snapshot.pendingTitle == "Secure field blocked")
}
```

- [ ] **Step 2: Run the focused presentation tests**

Run: `cd app && swift test --filter 'MoteSettingsSnapshotTests|CapturePanelSnapshotTests'`

Expected: FAIL because the three modes and recovery-specific copy are not exposed.

- [ ] **Step 3: Implement the minimal UI and documentation changes**

Replace the Boolean segmented picker with a three-value picker bound to `deliveryMode`; put the privacy boundary directly below it. In the pending card, show `pendingTitle` and `pendingDetail`; label the retry button “Try again here” after a block and “Insert again” after an unverified attempt. Update history labels to distinguish Verified, Sent—not confirmed, Focus changed, Secure field blocked, and No editable field. Update `SECURITY.md` with host-only temporary paste, Clipboard History exposure, secure-field refusal, capability-only routing, no transcript telemetry, and the exact Accessibility observer notifications. Update README compatibility language from universal absolutes to “virtually any standard editable text field.”

- [ ] **Step 4: Run the complete Swift suite and build**

Run: `cd app && swift test && swift build`

Expected: all tests pass and the debug executable builds without a new warning from Mote sources.

- [ ] **Step 5: Run security and diff checks without committing**

Run: `cd app && ./test-bundle-security.sh && cd .. && git diff --check && git status --short && git diff --stat`

Done: security assertions pass; settings explain the real trade-off; recovery is always visible; no commit or release artifact is created.

## Plan self-review

- Spec coverage: Phase 0 is Task 5; focus safety and observability are Tasks 2–4; hybrid routing is Tasks 1, 3, and 4. The report explicitly makes InputMethodKit a later, kill-criteria-driven feasibility study rather than part of the production refactor; it will require a separate plan and action-time approval before installing an input source. Selective host plugins remain out of scope until matrix evidence exists.
- Security coverage: secure-field refusal, host-only temporary paste, clipboard ownership, no blind retry, no sensitive telemetry, recoverable transcripts, and permission documentation each have a code or documentation task.
- Small-code constraint: one domain model, one focus observer, one OS adapter, one bounded content-free preference store, and one coordinator own the behavior; no app-specific integration layer is introduced.
- Type consistency: `DeliveryMode`, `DeliveryMethod`, `DeliveryAttempt`, `DeliveryBlockReason`, `PendingDeliveryReason`, `FocusSnapshot`, and `TargetCapture` retain the same names across tasks.
- Verification: each production behavior begins with a failing Swift test, each task has a focused verification, and Task 5 runs the full suite, build, and security script.
