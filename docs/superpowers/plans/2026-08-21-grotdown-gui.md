# Grotdown GUI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Turn Local Flow into Grotdown: a dark, menu-bar-first support dictation app with a branded capture panel, durable local History/Snippets, and guarded Plain/GFM output.

**Architecture:** Preserve the accepted capture, Parakeet TDT, personal-dictionary, MLX cleanup, and terminal raw-fallback pipeline. Add isolated UI state, persistence, formatting, and AppKit bridge layers around it: AppState stays the live-session coordinator, stores own durable content, and a narrow status-item/popover coordinator owns only anchored AppKit presentation.

**Tech Stack:** Swift 6.3, SwiftPM, SwiftUI, AppKit/Carbon, AVFoundation/CoreAudio, FluidAudio Parakeet TDT, MLX Swift, Swift Testing.

**Spec:** docs/superpowers/specs/2026-08-21-grotdown-gui-prd.md

## Global Constraints

- Platform remains macOS 26.0+ and Apple Silicon.
- Dictation remains fully local; add no runtime network call, account, sync, telemetry, or server storage.
- Cleanup remains MLX-only; the raw transcript remains terminal fallback on unavailable, timeout, rejection, or error.
- Streaming ASR partials remain HUD-only until a benchmark explicitly promotes them as a final transcript source.
- Markdown is a separately guarded formatter and must fall back to the safe Plain result on any unsafe or unavailable result.
- Snapshot the output format at capture start. A changed preference affects the next dictation; only a non-auto-insert ready result may be recomputed.
- Keep direct Unicode typing as the default insertion method and preserve full clipboard contents for the explicit clipboard fallback.
- Keep the HUD non-activating and mouse-ignoring. It must never steal the receiver's focus.
- Keep Grotdown menu-bar-first. History/Snippets open on demand; Settings is a dedicated Settings scene.
- New controls require keyboard access, VoiceOver labels, contrast, and reduced-motion behavior.
- Do not commit, push, or alter existing .agents/ and .claude worktree content without express user authorization.

---

## File Structure

| Path | Responsibility |
| --- | --- |
| app/Sources/LocalFlow/App/LocalFlowApp.swift | Grotdown scene wiring and activation policy. |
| app/Sources/LocalFlowCleanup/OutputFormat.swift | Shared output/capture contracts used by cleanup and UI. |
| app/Sources/LocalFlow/Models/DictationRecord.swift | Codable History, Snippets, target metadata, insertion outcomes. |
| app/Sources/LocalFlow/Stores/GrotdownPreferences.swift | Durable user preferences. |
| app/Sources/LocalFlow/Stores/HistoryStore.swift | Versioned local History JSON. |
| app/Sources/LocalFlow/Stores/SnippetStore.swift | Versioned local Snippet JSON. |
| app/Sources/LocalFlow/Services/StatusItemPopoverCoordinator.swift | The only new long-lived AppKit presentation bridge. |
| app/Sources/LocalFlow/Services/HotkeyRegistrar.swift | Carbon global hotkey press/release registration. |
| app/Sources/LocalFlow/Services/MicrophoneDeviceService.swift | Input discovery and live-level snapshots. |
| app/Sources/LocalFlow/Support/GrotdownTheme.swift | Design/motion tokens and signal-mark geometry. |
| app/Sources/LocalFlow/Resources/Fonts/ | Bundled Space Grotesk, Hanken Grotesk, and Space Mono font faces. |
| app/Sources/LocalFlow/Views/CapturePanelView.swift | 340pt anchored capture panel. |
| app/Sources/LocalFlow/Views/LibraryRootView.swift | On-demand History/Snippets window. |
| app/Sources/LocalFlow/Views/GrotdownSettingsView.swift | General, Model, Hotkey, Output, Microphone tabs. |
| app/Sources/LocalFlowCleanup/MLXTextGenerator.swift | Shared serialized MLX text runtime. |
| app/Sources/LocalFlowCleanup/SpokenFormattingCommands.swift | Deterministic code-block command parser. |
| app/Sources/LocalFlowCleanup/MarkdownFormatter.swift | Guarded local GFM provider and Plain fallback. |
| app/Sources/LocalFlowCleanup/MarkdownFormattingSafety.swift | GFM structural and word-preservation guard. |
| app/Sources/LocalFlowCleanup/OutputResolution.swift | Pure Plain/GFM output selection. |

Existing AppState.swift, AudioCapture.swift, HotkeyMonitor.swift, TextInjector.swift, WaveformHUD.swift, MenuView.swift, SettingsView.swift, and LocalFlowApp.swift are narrowed only after their focused replacements pass their own tests.

---

### Task 1: Establish Grotdown identity, scenes, assets, and tokens

**Files:**
- Create: app/Sources/LocalFlow/App/LocalFlowApp.swift
- Create: app/Sources/LocalFlow/Support/GrotdownTheme.swift
- Create: app/Sources/LocalFlow/Support/GrotdownSignalMark.swift
- Create: app/Sources/LocalFlow/Resources/GrotdownMenuBarTemplate.pdf
- Create: app/Sources/LocalFlow/Resources/GrotdownSignalMark.pdf
- Create: app/Sources/LocalFlow/Resources/Fonts/SpaceGrotesk-SemiBold.ttf
- Create: app/Sources/LocalFlow/Resources/Fonts/HankenGrotesk-Regular.ttf
- Create: app/Sources/LocalFlow/Resources/Fonts/HankenGrotesk-Medium.ttf
- Create: app/Sources/LocalFlow/Resources/Fonts/SpaceMono-Regular.ttf
- Create: app/Tests/LocalFlowTests/GrotdownThemeTests.swift
- Modify: app/Package.swift
- Modify: app/Sources/LocalFlow/LocalFlowApp.swift
- Modify: app/Sources/LocalFlow/OnboardingView.swift

**Interfaces:**
- Consumes: AppState.shared and the existing permissions flow.
- Produces: GrotdownTheme, GrotdownSignalMarkMetrics, scene IDs library/settings, and processed vector resources.

- [ ] **Step 1: Write the failing token and geometry test**

~~~swift
import Testing
@testable import LocalFlow

@Suite struct GrotdownThemeTests {
    @Test func signalMarkUsesTheSpecifiedFiveBarGeometry() {
        #expect(GrotdownSignalMarkMetrics.widths == [6, 6, 6, 6, 6])
        #expect(GrotdownSignalMarkMetrics.heights == [40, 26, 22, 12, 10])
        #expect(GrotdownSignalMarkMetrics.cornerRadius == 3)
        #expect(GrotdownSignalMarkMetrics.pitch == 11)
    }

    @Test func motionTokensMatchTheDesignContract() {
        #expect(GrotdownTheme.Motion.fast == 0.12)
        #expect(GrotdownTheme.Motion.base == 0.20)
        #expect(GrotdownTheme.Motion.slow == 0.32)
    }
}
~~~

- [ ] **Step 2: Run the focused test to verify it fails**

Run:

~~~bash
cd app
swift test --filter GrotdownThemeTests
~~~

Expected: FAIL because the theme and signal-mark types do not exist.

- [ ] **Step 3: Implement the theme and vector-mark primitives**

Implement this testable geometry and the complete PRD token palette, type scale, radii, shadows, and motion values:

~~~swift
enum GrotdownSignalMarkMetrics {
    static let widths: [CGFloat] = [6, 6, 6, 6, 6]
    static let heights: [CGFloat] = [40, 26, 22, 12, 10]
    static let cornerRadius: CGFloat = 3
    static let pitch: CGFloat = 11
}

enum GrotdownTheme {
    enum Motion {
        static let fast: Double = 0.12
        static let base: Double = 0.20
        static let slow: Double = 0.32
    }
}
~~~

Draw the five centered rounded bars with the gold-to-orange gradient in GrotdownSignalMark. Check in matching vector PDFs: a color surface mark and a 16pt alpha-only menu template. Set the loaded menu image isTemplate property to true. Bundle and register the listed font faces at launch; GrotdownTheme must fall back to the matching system semantic font if registration fails, so text remains legible without an asset-loading crash.

- [ ] **Step 4: Add resources and explicit scene boundaries**

Move the App declaration to App/LocalFlowApp.swift. Add SwiftPM resource processing for Resources. Wire a menu-bar-first app with an on-demand library Window and dedicated Settings scene:

~~~swift
Window("Grotdown", id: "library") { LibraryRootView() }
Settings { GrotdownSettingsView() }
~~~

The legacy root app file must be removed when the new app file compiles. Do not set regular activation policy at launch.

- [ ] **Step 5: Rebrand startup copy and verify**

Change user-facing onboarding title/copy to Grotdown and use the exact privacy line: “Your voice and your text stay on this Mac. Grotdown has no server.”

Run:

~~~bash
cd app
swift test --filter GrotdownThemeTests
swift build --product LocalFlow
~~~

Expected: test passes and resources are bundled.

- [ ] **Step 6: Commit only if expressly authorized**

~~~bash
git add app/Package.swift app/Sources/LocalFlow/App app/Sources/LocalFlow/Support app/Sources/LocalFlow/Resources app/Sources/LocalFlow/LocalFlowApp.swift app/Sources/LocalFlow/OnboardingView.swift app/Tests/LocalFlowTests/GrotdownThemeTests.swift
git commit -m "Add Grotdown visual foundation"
~~~

### Task 2: Add preferences plus durable local History and Snippets

**Files:**
- Create: app/Sources/LocalFlowCleanup/OutputFormat.swift
- Create: app/Sources/LocalFlow/Models/DictationRecord.swift
- Create: app/Sources/LocalFlow/Stores/GrotdownPreferences.swift
- Create: app/Sources/LocalFlow/Stores/HistoryStore.swift
- Create: app/Sources/LocalFlow/Stores/SnippetStore.swift
- Create: app/Tests/LocalFlowTests/GrotdownPreferencesTests.swift
- Create: app/Tests/LocalFlowTests/HistoryStoreTests.swift
- Create: app/Tests/LocalFlowTests/SnippetStoreTests.swift

**Interfaces:**
- Consumes: Foundation, Application Support, and the existing last transcript/final values.
- Produces: output/capture settings plus versioned local stores for Tasks 4, 6, 7, and 8.

- [ ] **Step 1: Write failing preference and persistence tests**

~~~swift
@Test func preferencesRoundTripOutputAndCaptureMode() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let preferences = GrotdownPreferences(defaults: defaults)
    preferences.outputFormat = .markdown
    preferences.captureMode = .toggle
    preferences.autoInsert = false

    let restored = GrotdownPreferences(defaults: defaults)
    #expect(restored.outputFormat == .markdown)
    #expect(restored.captureMode == .toggle)
    #expect(restored.autoInsert == false)
}

@Test func historyRoundTripsAndUpdatesOutcome() throws {
    let url = try temporaryFileURL(named: "history.json")
    let store = HistoryStore(fileURL: url)
    let record = DictationRecord.fixture(finalText: "# Incident update", format: .markdown)
    store.append(record)
    store.updateOutcome(for: record.id, to: .copiedNoFocusedTarget)

    let restored = HistoryStore(fileURL: url)
    #expect(restored.records == [record.replacingOutcome(.copiedNoFocusedTarget)])
}
~~~

Also test newest-first ordering, delete-one, clear-all, empty/nonexistent files, version-1 JSON envelopes, corrupted JSON without overwriting the source, creation from a record, and Snippet persistence.

- [ ] **Step 2: Run focused tests to verify they fail**

~~~bash
cd app
swift test --filter GrotdownPreferencesTests
swift test --filter HistoryStoreTests
swift test --filter SnippetStoreTests
~~~

Expected: FAIL because the models and stores do not exist.

- [ ] **Step 3: Implement immutable models and preferences**

~~~swift
enum OutputFormat: String, Codable, CaseIterable, Sendable { case plain, markdown }
enum CaptureMode: String, Codable, CaseIterable, Sendable { case holdToTalk, toggle }
enum InsertionOutcome: String, Codable, Sendable {
    case pending, typedAttempted, copiedNoFocusedTarget, copiedByUser, notInserted
}

struct TargetApplication: Codable, Equatable, Sendable {
    let name: String
    let bundleIdentifier: String?
}

struct DictationRecord: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    let duration: TimeInterval
    let rawText: String
    let finalText: String
    let format: OutputFormat
    let targetApplication: TargetApplication?
    let insertionOutcome: InsertionOutcome
}
~~~

Put OutputFormat and CaptureMode in LocalFlowCleanup so MarkdownFormatter and OutputResolution can use them without the cleanup target importing the app target. In DictationRecord.swift, import LocalFlowCleanup before using OutputFormat. Make Snippet similarly immutable with id, createdAt, title, text, and format. Add replacingOutcome and asSnippet(title:) helpers. GrotdownPreferences uses an injected UserDefaults and defaults to Plain, hold-to-talk, auto-insert on, cleanup on, HUD on, direct typing on, and preserveCodeAndBackticks off.

- [ ] **Step 4: Implement versioned, atomic stores**

Use a JSON envelope beneath Application Support/Grotdown:

~~~swift
private struct VersionedDocument<Value: Codable>: Codable {
    let schemaVersion: Int
    var values: [Value]
}
~~~

HistoryStore and SnippetStore publish their values on the main actor and expose append, replace, delete, clear. Writes must be atomic. Decode failure must set a visible loadError and leave the unreadable source untouched.

- [ ] **Step 5: Run tests and commit if authorized**

~~~bash
cd app
swift test --filter GrotdownPreferencesTests
swift test --filter HistoryStoreTests
swift test --filter SnippetStoreTests
swift test
git add app/Sources/LocalFlowCleanup/OutputFormat.swift app/Sources/LocalFlow/Models/DictationRecord.swift app/Sources/LocalFlow/Stores app/Tests/LocalFlowTests/GrotdownPreferencesTests.swift app/Tests/LocalFlowTests/HistoryStoreTests.swift app/Tests/LocalFlowTests/SnippetStoreTests.swift
git commit -m "Add Grotdown local library stores"
~~~

Expected: all tests pass. Skip the commit unless expressly authorized.

### Task 3: Build safe Markdown formatting and explicit code-block parsing

**Files:**
- Create: app/Sources/LocalFlowCleanup/MLXTextGenerator.swift
- Create: app/Sources/LocalFlowCleanup/SpokenFormattingCommands.swift
- Create: app/Sources/LocalFlowCleanup/MarkdownFormattingSafety.swift
- Create: app/Sources/LocalFlowCleanup/MarkdownFormatter.swift
- Create: app/Sources/LocalFlowCleanup/OutputResolution.swift
- Create: app/Tests/LocalFlowTests/SpokenFormattingCommandsTests.swift
- Create: app/Tests/LocalFlowTests/MarkdownFormattingSafetyTests.swift
- Create: app/Tests/LocalFlowTests/OutputResolutionTests.swift
- Modify: app/Sources/LocalFlowCleanup/MLXCleanupProvider.swift

**Interfaces:**
- Consumes: accepted cleaned Plain text, MLX Swift, and OutputFormat.
- Produces: deterministic command parsing, local GFM formatting, a strict guard, and an explicit fallback result.

- [ ] **Step 1: Write failing parser and fallback tests**

~~~swift
@Test func matchedCodeCommandsBecomeOneFencedBlock() {
    let parsed = SpokenFormattingCommands.parse(
        "start code block yaml jsonData timeout 120 end code block"
    )
    #expect(parsed.blocks == [.init(language: "yaml", body: "jsonData timeout 120")])
    #expect(parsed.textForFormatter == "[[GROTDOWN_CODE_BLOCK_0]]")
}

@Test func unmatchedStartCommandRemainsLiteralSpeech() {
    let source = "start code block yaml jsonData timeout 120"
    #expect(SpokenFormattingCommands.parse(source).textForFormatter == source)
}

@Test func unsafeFormatterOutputFallsBackToPlain() async {
    let provider = StubMarkdownProvider(output: "# Invented heading\nNew claim")
    let result = await MarkdownFormatter(provider: provider).format(
        "The customer said alerts fire twice.",
        options: .init(preserveCodeAndBackticks: false)
    )
    #expect(result == .fallbackToPlain("The customer said alerts fire twice."))
}
~~~

Also test case/whitespace normalization, optional supported languages, marker loss, duplicate markers, Markdown links/HTML rejection, word preservation, valid task lists, valid restored code fences, and OutputResolution Plain/GFM/fallback behavior.

- [ ] **Step 2: Run tests to verify failure**

~~~bash
cd app
swift test --filter SpokenFormattingCommandsTests
swift test --filter MarkdownFormattingSafetyTests
swift test --filter OutputResolutionTests
~~~

Expected: FAIL because parser, formatter, safety guard, and resolution types do not exist.

- [ ] **Step 3: Extract serialized MLX generation without changing cleanup behavior**

Move ContainerLoader/generation mechanics from MLXCleanupProvider into:

~~~swift
actor MLXTextGenerator {
    static let shared = MLXTextGenerator()
    func generate(prompt: String, maxTokens: Int, temperature: Float) async throws -> String
}
~~~

Change MLXCleanupProvider to call the actor with the existing 128-token, temperature-zero cleanup prompt and existing CleanupSafety result path. Run CleanupSafetyTests before continuing.

- [ ] **Step 4: Implement parser, guard, formatter, and resolution**

SpokenFormattingCommands recognizes only matched pairs of start code block and end code block. It accepts only yaml, json, bash, swift, javascript, typescript, python, or no language. Matched blocks become private markers such as [[GROTDOWN_CODE_BLOCK_0]]; unmatched/unknown commands remain literal text. Restoration uses the original body, adds a fence, and fails if a marker is missing or duplicated.

Expose exactly:

~~~swift
public protocol MarkdownFormattingProviding: Sendable {
    func format(prompt: String) async -> String?
}

public enum MarkdownFormattingResult: Equatable {
    case formatted(String)
    case fallbackToPlain(String)
}

public struct FormattingOptions: Equatable, Sendable {
    public let preserveCodeAndBackticks: Bool
    public init(preserveCodeAndBackticks: Bool) {
        self.preserveCodeAndBackticks = preserveCodeAndBackticks
    }
}

public struct MarkdownFormatter {
    public init(provider: any MarkdownFormattingProviding = MLXMarkdownProvider())
    public func format(_ plainText: String, options: FormattingOptions) async -> MarkdownFormattingResult
}

public struct ResolvedOutput: Equatable {
    public let requestedFormat: OutputFormat
    public let effectiveFormat: OutputFormat
    public let text: String
    public let usedPlainFallback: Bool
}
~~~

MLXMarkdownProvider uses MLXTextGenerator at temperature zero. Its prompt allows only GFM structure, forbids wrappers/HTML/links, requires every non-command spoken word in order, and requires exact marker preservation. FormattingOptions controls whether existing code-like tokens and backticks must remain literal. MarkdownFormattingSafety permits headings, paragraphs, ordered/unordered lists, task lists, and command-restored fences only. Any missing input word, new word, malformed structure, marker mismatch, wrapper, or empty output returns Plain.

- [ ] **Step 5: Verify formatter safety and commit if authorized**

~~~bash
cd app
swift test --filter CleanupSafetyTests
swift test --filter SpokenFormattingCommandsTests
swift test --filter MarkdownFormattingSafetyTests
swift test --filter OutputResolutionTests
swift test
git add app/Sources/LocalFlowCleanup/MLXTextGenerator.swift app/Sources/LocalFlowCleanup/SpokenFormattingCommands.swift app/Sources/LocalFlowCleanup/MarkdownFormattingSafety.swift app/Sources/LocalFlowCleanup/MarkdownFormatter.swift app/Sources/LocalFlowCleanup/OutputResolution.swift app/Sources/LocalFlowCleanup/MLXCleanupProvider.swift app/Tests/LocalFlowTests/SpokenFormattingCommandsTests.swift app/Tests/LocalFlowTests/MarkdownFormattingSafetyTests.swift app/Tests/LocalFlowTests/OutputResolutionTests.swift
git commit -m "Add guarded Grotdown Markdown formatting"
~~~

Expected: existing cleanup tests remain green; unsafe GFM is never emitted. Skip commit unless expressly authorized.

### Task 4: Integrate output choice, delivery outcomes, and persistence into capture completion

**Files:**
- Create: app/Sources/LocalFlow/Models/PendingDictation.swift
- Create: app/Sources/LocalFlow/Services/FocusedTargetInspector.swift
- Create: app/Sources/LocalFlow/Services/OutputDeliveryCoordinator.swift
- Create: app/Tests/LocalFlowTests/OutputDeliveryCoordinatorTests.swift
- Create: app/Tests/LocalFlowTests/FocusedTargetInspectorTests.swift
- Modify: app/Sources/LocalFlow/AppState.swift
- Modify: app/Sources/LocalFlow/TextInjector.swift
- Modify: app/Sources/LocalFlowCleanup/SettingsDiagnosticsSnapshot.swift

**Interfaces:**
- Consumes: Task 2 stores/preferences and Task 3 formatter/resolution.
- Produces: PendingDictation, TextDeliveryResult, and safe auto-insert/manual-ready behavior for the panel.

- [ ] **Step 1: Write failing delivery tests with injected fakes**

~~~swift
@Test func nonAutoInsertKeepsAPendingMarkdownResult() async {
    let coordinator = OutputDeliveryCoordinator(
        formatter: StubFormatter(formatted: "- [ ] Confirm the panel loads"),
        targetInspector: StubTargetInspector(target: .textField(app: .fixture)),
        textDeliverer: RecordingDeliverer()
    )
    let result = await coordinator.complete(
        raw: "confirm the panel loads",
        cleaned: "Confirm the panel loads.",
        format: .markdown,
        autoInsert: false,
        duration: 0.8
    )
    #expect(result.pending?.resolved.text == "- [ ] Confirm the panel loads")
    #expect(result.delivery == .notInserted)
}
~~~

Also test: Plain never invokes formatting; unsafe Markdown stores effective Plain; auto insert types only with an editable target; no target copies; one record is created; pending insertion updates rather than duplicates that record.

- [ ] **Step 2: Run the focused tests to verify they fail**

~~~bash
cd app
swift test --filter OutputDeliveryCoordinatorTests
swift test --filter FocusedTargetInspectorTests
~~~

Expected: FAIL because the coordinator and inspector do not exist.

- [ ] **Step 3: Define pending, target, and delivery contracts**

~~~swift
struct PendingDictation: Identifiable, Equatable {
    let id: UUID
    let rawText: String
    let plainText: String
    let resolved: ResolvedOutput
    let duration: TimeInterval
}

enum TextDeliveryResult: Equatable {
    case typedAttempted(TargetApplication?)
    case copiedNoFocusedTarget(TargetApplication?)
    case copiedByUser
    case notInserted
}
~~~

FocusedTargetInspector uses the system-wide focused accessibility element only to detect a likely editable role. It returns no target when macOS cannot expose one. It never calls a posted event a proven insertion success.

- [ ] **Step 4: Refactor delivery and AppState completion**

Wrap existing direct typing and full clipboard restore behind:

~~~swift
protocol TextDelivering {
    func deliver(_ text: String, method: TextInjector.Method, target: TargetApplication?) -> TextDeliveryResult
}
~~~

No target means copy and copiedNoFocusedTarget. A detected target means post the existing selected method and return typedAttempted. After the current ASR, dictionary, and Cleaner path, AppState snapshots both outputFormat and preserveCodeAndBackticks at hotkey-down, then passes FormattingOptions into MarkdownFormatter. Auto-insert delivers/persists immediately; manual mode publishes PendingDictation and a notInserted record. Add insertPending, copyPending, and setPendingFormat methods. Do not change streaming/TDT selection, pause behavior, or raw fallback.

- [ ] **Step 5: Verify integration and commit if authorized**

~~~bash
cd app
swift test --filter OutputDeliveryCoordinatorTests
swift test --filter FocusedTargetInspectorTests
swift test --filter SettingsDiagnosticsSnapshotTests
swift test
git add app/Sources/LocalFlow/Models/PendingDictation.swift app/Sources/LocalFlow/Services/FocusedTargetInspector.swift app/Sources/LocalFlow/Services/OutputDeliveryCoordinator.swift app/Sources/LocalFlow/AppState.swift app/Sources/LocalFlow/TextInjector.swift app/Sources/LocalFlowCleanup/SettingsDiagnosticsSnapshot.swift app/Tests/LocalFlowTests/OutputDeliveryCoordinatorTests.swift app/Tests/LocalFlowTests/FocusedTargetInspectorTests.swift
git commit -m "Integrate Grotdown output delivery"
~~~

Expected: all existing streaming/cleanup tests pass. Skip commit unless expressly authorized.

### Task 5: Replace the fixed modifier monitor with a persisted, rebindable hotkey

**Files:**
- Create: app/Sources/LocalFlow/Models/HotkeyConfiguration.swift
- Create: app/Sources/LocalFlow/Services/HotkeyRegistrar.swift
- Create: app/Tests/LocalFlowTests/HotkeyConfigurationTests.swift
- Modify: app/Sources/LocalFlow/HotkeyMonitor.swift
- Modify: app/Sources/LocalFlow/AppState.swift
- Modify: app/Sources/LocalFlow/Stores/GrotdownPreferences.swift

**Interfaces:**
- Consumes: CaptureMode, preferences, and existing AppState start/end/cancel actions.
- Produces: Option-Space default plus hold/toggle behavior without Input Monitoring.

- [ ] **Step 1: Write failing configuration and reducer tests**

~~~swift
@Test func defaultConfigurationIsOptionSpace() {
    #expect(HotkeyConfiguration.default.displayName == "⌥ Space")
    #expect(HotkeyConfiguration.default.keyCode == 49)
    #expect(HotkeyConfiguration.default.modifiers == [.option])
}

@Test func toggleModeStartsThenStopsOnSuccessivePresses() {
    var reducer = HotkeyInteractionReducer(mode: .toggle)
    #expect(reducer.handle(.pressed) == .beginCapture)
    #expect(reducer.handle(.pressed) == .endCapture)
}
~~~

Also test hold press/release behavior, persistence, invalid empty modifiers, and registration failure that preserves the prior active registration.

- [ ] **Step 2: Run the test to verify failure**

~~~bash
cd app
swift test --filter HotkeyConfigurationTests
~~~

Expected: FAIL because the configuration and reducer do not exist.

- [ ] **Step 3: Implement Carbon-backed registration**

Define Codable HotkeyConfiguration with Carbon virtual key codes and modifier bits. Default is key code 49 with Option. HotkeyInteractionReducer returns only beginCapture, endCapture, cancelCapture, or ignore.

HotkeyRegistrar registers kEventHotKeyPressed and kEventHotKeyReleased with RegisterEventHotKey. It owns one EventHotKeyRef, installs no global key-content monitor, removes the old ref only after successful new registration, and forwards only its matching EventHotKeyID to the reducer.

- [ ] **Step 4: Adapt the monitor and verify**

Replace the fixed left-Option monitor construction with configuration/mode-driven registration. On failure, show a concise error and retain the last working binding. Verify:

~~~bash
cd app
swift test --filter HotkeyConfigurationTests
swift test
swift build --product LocalFlow
~~~

Manual acceptance: Option-Space starts/ends hold-to-talk; toggle starts/stops on successive presses; a custom binding survives relaunch; only Microphone and Accessibility are requested.

- [ ] **Step 5: Commit only if expressly authorized**

~~~bash
git add app/Sources/LocalFlow/Models/HotkeyConfiguration.swift app/Sources/LocalFlow/Services/HotkeyRegistrar.swift app/Sources/LocalFlow/HotkeyMonitor.swift app/Sources/LocalFlow/AppState.swift app/Sources/LocalFlow/Stores/GrotdownPreferences.swift app/Tests/LocalFlowTests/HotkeyConfigurationTests.swift
git commit -m "Add rebindable Grotdown hotkey"
~~~

### Task 6: Ship the 340pt capture panel and branded non-activating HUD

**Files:**
- Create: app/Sources/LocalFlow/Models/CapturePanelSnapshot.swift
- Create: app/Sources/LocalFlow/Services/StatusItemPopoverCoordinator.swift
- Create: app/Sources/LocalFlow/Views/CapturePanelView.swift
- Create: app/Sources/LocalFlow/Views/CapturePanelStatusView.swift
- Create: app/Sources/LocalFlow/Views/GrotdownHUDView.swift
- Create: app/Tests/LocalFlowTests/CapturePanelSnapshotTests.swift
- Modify: app/Sources/LocalFlow/App/LocalFlowApp.swift
- Modify: app/Sources/LocalFlow/AppState.swift
- Modify: app/Sources/LocalFlow/MenuView.swift
- Modify: app/Sources/LocalFlow/WaveformHUD.swift

**Interfaces:**
- Consumes: PendingDictation, store previews, preferences, status labels, and HUD phases.
- Produces: anchored panel state and visual HUD updates without new focus ownership.

- [ ] **Step 1: Write failing capture panel presentation tests**

~~~swift
@Test func readyManualInsertSnapshotShowsFormatActions() {
    let snapshot = CapturePanelSnapshot.make(
        status: .ready,
        pending: .fixture(format: .markdown, text: "# Incident update"),
        autoInsert: false,
        recentRecords: []
    )
    #expect(snapshot.showsFormatPicker)
    #expect(snapshot.primaryAction == .insert)
    #expect(snapshot.secondaryAction == .copy)
    #expect(snapshot.preview == "# Incident update")
}
~~~

Also test idle configured-hotkey guidance, inserted/copy feedback, empty recent list, Plain/Markdown labels, and 30-character-bounded list titles.

- [ ] **Step 2: Run the test to verify failure**

~~~bash
cd app
swift test --filter CapturePanelSnapshotTests
~~~

Expected: FAIL because CapturePanelSnapshot does not exist.

- [ ] **Step 3: Implement the narrow AppKit popover bridge**

StatusItemPopoverCoordinator owns exactly one NSStatusItem, one semitransient NSPopover, and one NSHostingController<CapturePanelView>. AppDelegate owns the coordinator and starts/stops it with the app lifecycle. The status button toggles visibility. The coordinator forwards show/dismiss only; it must not own duplicate copies of preferences, history, or pending output. Size the hosted view to 340pt. Its updateStatusIcon method uses the template mark while idle and a non-template orange, animated five-bar image while recording; all other state is rendered by SwiftUI.

- [ ] **Step 4: Implement the panel and HUD views**

CapturePanelView renders Grotdown header, on-device status, configured hotkey, bounded recent rows, manual-ready preview, Plain/Markdown picker, Insert, Copy, Open History, Settings, pause/resume, and Quit. It calls only explicit AppState methods.

Keep HUDController panel behavior unchanged: borderless, non-activating, status-bar-level, mouse-ignoring, all-spaces. Replace its visual body with GrotdownHUDView: gradient recording waveform, optional caption tail, Mono timer, processing states, and short success/copy feedback. With accessibilityReduceMotion true, render a static record dot and cross-fades instead of pulses/scales.

- [ ] **Step 5: Remove menu-only presentation after action parity and verify**

Only remove MenuView and the temporary MenuBarExtra scene after the panel supports every existing action. Run:

~~~bash
cd app
swift test --filter CapturePanelSnapshotTests
swift test --filter HUDCaptionTailTests
swift test
swift build --product LocalFlow
~~~

Manual acceptance: the panel anchors at 340pt; opening it does not activate the receiver; previews remain bounded; TextEdit retains focus through HUD capture and completion.

- [ ] **Step 6: Commit only if expressly authorized**

~~~bash
git add app/Sources/LocalFlow/Models/CapturePanelSnapshot.swift app/Sources/LocalFlow/Services/StatusItemPopoverCoordinator.swift app/Sources/LocalFlow/Views app/Sources/LocalFlow/App/LocalFlowApp.swift app/Sources/LocalFlow/AppState.swift app/Sources/LocalFlow/MenuView.swift app/Sources/LocalFlow/WaveformHUD.swift app/Tests/LocalFlowTests/CapturePanelSnapshotTests.swift
git commit -m "Add Grotdown capture panel and HUD"
~~~

### Task 7: Implement the on-demand History and Snippets library

**Files:**
- Create: app/Sources/LocalFlow/Models/LibraryPresentation.swift
- Create: app/Sources/LocalFlow/Views/LibraryRootView.swift
- Create: app/Sources/LocalFlow/Views/HistoryViews.swift
- Create: app/Sources/LocalFlow/Views/SnippetViews.swift
- Create: app/Tests/LocalFlowTests/LibraryPresentationTests.swift
- Modify: app/Sources/LocalFlow/App/LocalFlowApp.swift
- Modify: app/Sources/LocalFlow/AppState.swift

**Interfaces:**
- Consumes: HistoryStore, SnippetStore, TextDelivering, and scene ID library.
- Produces: searchable local records, reusable snippets, and detail actions.

- [ ] **Step 1: Write failing library presentation tests**

~~~swift
@Test func searchMatchesRawAndFinalTextCaseInsensitively() {
    let records = [
        .fixture(rawText: "zendesk timeout", finalText: "# Zendesk timeout"),
        .fixture(rawText: "incident lag", finalText: "Incident notes")
    ]
    let presentation = LibraryPresentation(records: records, searchText: "TIMEOUT")
    #expect(presentation.visibleRecords.map(\.id) == [records[0].id])
}

@Test func rowTitlesStaySingleLineAndBounded() {
    let record = DictationRecord.fixture(finalText: String(repeating: "x", count: 80))
    #expect(LibraryPresentation.rowTitle(for: record).count <= 30)
}
~~~

Also test empty History, selected detail metadata, save-as-snippet title trimming, snippet deletion, and insert/copy without mutating the original record.

- [ ] **Step 2: Run the test to verify failure**

~~~bash
cd app
swift test --filter LibraryPresentationTests
~~~

Expected: FAIL because LibraryPresentation does not exist.

- [ ] **Step 3: Implement presentation and views**

LibraryPresentation contains only filtering, selection defaults, bounded row titles, and date/duration formatting. LibraryRootView uses NavigationSplitView with native sidebar rows, scene-owned selection, and SceneStorage for last selected section. Size the library scene to 960pt by 580pt with a sensible larger minimum. History detail shows raw/final text, effective format, timestamp, duration, target app, Copy, Insert, Save as Snippet, and Delete. Snippet detail shows title, text, format, Copy, Insert, and Delete. All transcript text is selectable.

- [ ] **Step 4: Wire the singleton window and verify persistence**

Use openWindow(id: "library") in the panel. Activate the app only when explicitly opening the library. Run:

~~~bash
cd app
swift test --filter LibraryPresentationTests
swift test --filter HistoryStoreTests
swift test --filter SnippetStoreTests
swift test
swift build --product LocalFlow
~~~

Manual acceptance: create Plain and Markdown records, relaunch, search both, save a snippet, copy/insert it, delete it, and confirm remaining records persist locally.

- [ ] **Step 5: Commit only if expressly authorized**

~~~bash
git add app/Sources/LocalFlow/Models/LibraryPresentation.swift app/Sources/LocalFlow/Views/LibraryRootView.swift app/Sources/LocalFlow/Views/HistoryViews.swift app/Sources/LocalFlow/Views/SnippetViews.swift app/Sources/LocalFlow/App/LocalFlowApp.swift app/Sources/LocalFlow/AppState.swift app/Tests/LocalFlowTests/LibraryPresentationTests.swift
git commit -m "Add Grotdown history and snippets library"
~~~

### Task 8: Deliver Hotkey, Output, and Microphone settings

**Files:**
- Create: app/Sources/LocalFlow/Services/MicrophoneDeviceService.swift
- Create: app/Sources/LocalFlow/Views/GrotdownSettingsView.swift
- Create: app/Tests/LocalFlowTests/MicrophoneDeviceServiceTests.swift
- Create: app/Tests/LocalFlowTests/GrotdownSettingsSnapshotTests.swift
- Modify: app/Sources/LocalFlow/AudioCapture.swift
- Modify: app/Sources/LocalFlow/AppState.swift
- Modify: app/Sources/LocalFlow/SettingsView.swift

**Interfaces:**
- Consumes: preferences, hotkey configuration, Microphone permissions, and AudioCapture.
- Produces: General, Model, Hotkey, Output, Microphone tabs; input choice; accessible live meter.

- [ ] **Step 1: Write failing device and settings tests**

~~~swift
@Test func unavailableSelectedDeviceUsesDefaultWithoutChangingPreference() {
    let service = MicrophoneDeviceService(
        enumerator: StubDeviceEnumerator(devices: [.init(id: 1, name: "Built-in Mic")])
    )
    #expect(service.resolvedDeviceID(preferred: 99) == 1)
}

@Test func outputSettingsDescribeGFMAndCodeCommands() {
    let snapshot = GrotdownSettingsSnapshot.fixture(outputFormat: .markdown)
    #expect(snapshot.outputFormatLabel == "Markdown (GFM)")
    #expect(snapshot.codeCommandHelp.contains("start code block"))
}
~~~

Also test no-device status, level clamp from 0 through 1, exact five tab names, MLX-only label, Option-Space display, hold/toggle display, and setting persistence.

- [ ] **Step 2: Run the tests to verify failure**

~~~bash
cd app
swift test --filter MicrophoneDeviceServiceTests
swift test --filter GrotdownSettingsSnapshotTests
~~~

Expected: FAIL because device/settings types do not exist.

- [ ] **Step 3: Implement device discovery and capture configuration**

MicrophoneDeviceService enumerates CoreAudio input device IDs/display names, resolves a preferred ID, and publishes normalized meter values. Change AudioCapture.start to accept optional device ID and levelHandler. Configure the AVAudioEngine input audio unit before its existing tap. Calculate RMS from the already-converted 16kHz Float32 chunk, then forward the existing sample/streaming data unchanged.

- [ ] **Step 4: Implement the five settings tabs and AppState binding**

General contains privacy, overlay, auto-insert, direct typing/clipboard. Model names Parakeet and fixed MLX only. Hotkey captures binding, capture mode, conflict/error. Output contains Plain/GFM default, cleanup, preserve-code preference, and exact code-command examples. Microphone contains picker, meter, and no-device copy. Retain personal dictionary and diagnostics as grouped sections.

AppState reads selected device before capture, forwards level updates, clears meter on end/cancel/error/pause, and falls back to the current default device for one capture when the stored device is absent.

- [ ] **Step 5: Verify and commit if authorized**

~~~bash
cd app
swift test --filter MicrophoneDeviceServiceTests
swift test --filter GrotdownSettingsSnapshotTests
swift test
swift build --product LocalFlow
git add app/Sources/LocalFlow/Services/MicrophoneDeviceService.swift app/Sources/LocalFlow/Views/GrotdownSettingsView.swift app/Sources/LocalFlow/AudioCapture.swift app/Sources/LocalFlow/AppState.swift app/Sources/LocalFlow/SettingsView.swift app/Tests/LocalFlowTests/MicrophoneDeviceServiceTests.swift app/Tests/LocalFlowTests/GrotdownSettingsSnapshotTests.swift
git commit -m "Add Grotdown settings and microphone controls"
~~~

Expected: tests/build pass; manual gate verifies settings persist and VoiceOver names every tab/control/meter. Skip commit unless expressly authorized.

### Task 9: Update documentation, preserve evidence, and complete release QA

**Files:**
- Create: docs/grotdown-formatting-commands.md
- Modify: README.md
- Modify: docs/phase-3-handoff.md
- Modify: docs/reports/mlx-cleanup-benchmark/README.md
- Modify: docs/reports/mlx-cleanup-benchmark/runs/2026-07-08-task-14-mlx-default-provider/report.md
- Modify: app/Tests/LocalFlowTests/SettingsDiagnosticsSnapshotTests.swift
- Modify: app/Tests/LocalFlowTests/MenuRuntimeSnapshotTests.swift

**Interfaces:**
- Consumes: all previous product slices and existing benchmark/test commands.
- Produces: accurate Grotdown product docs plus repeatable acceptance evidence.

- [ ] **Step 1: Update failing active-copy assertions**

Change runtime-snapshot expectations so no active user-facing text says Local Flow, names Left Option as the default, or exposes Ollama as a cleanup fallback. Assert Grotdown, Option-Space, Plain/Markdown, and MLX-only labels.

- [ ] **Step 2: Run the tests to verify old copy fails**

~~~bash
cd app
swift test --filter MenuRuntimeSnapshotTests
swift test --filter SettingsDiagnosticsSnapshotTests
~~~

Expected: FAIL until active copy uses the Grotdown contract.

- [ ] **Step 3: Update documentation without rewriting benchmark history**

README documents support-engineering use, on-device privacy, Option-Space, Plain/GFM, explicit code blocks, History, and Snippets. The commands document says exactly:

~~~text
start code block yaml
end code block
~~~

Label the Task 14 report as historical pre-MLX-only acceptance evidence in its introduction while preserving its measured values. Update the benchmark README and phase handoff to describe current MLX-only/raw-terminal runtime.

- [ ] **Step 4: Run full automated verification**

~~~bash
cd app
swift test
./bundle.sh
cd ..
python3 -m unittest discover -s docs/reports/mlx-cleanup-benchmark -p 'test_*.py'
git diff --check
~~~

Expected: Swift tests, signed bundle, 17 report tests, and whitespace check pass.

- [ ] **Step 5: Run the end-to-end acceptance pass**

Record results for these exact cases:

1. Dictate Plain into TextEdit with auto-insert on; confirm raw/final History values.
2. Dictate Markdown with matched YAML code commands and auto-insert off; confirm valid GFM preview, Copy, and Insert.
3. Dictate malformed code commands; confirm literal speech or safe Plain fallback with no lost words.
4. Capture with no editable target; confirm Copy fallback and honest feedback.
5. Verify 340pt panel anchoring, mouse-ignoring/non-activating HUD, and History/Snippet persistence after relaunch.
6. Enable Reduce Motion; confirm no waveform pulse or scale effect.
7. Compare all visible surfaces with the supplied handoff for dark tokens, hierarchy, spacing, copy, state transitions, and legibility.

- [ ] **Step 6: Commit only if expressly authorized**

~~~bash
git add README.md docs/grotdown-formatting-commands.md docs/phase-3-handoff.md docs/reports/mlx-cleanup-benchmark/README.md docs/reports/mlx-cleanup-benchmark/runs/2026-07-08-task-14-mlx-default-provider/report.md app/Tests/LocalFlowTests/SettingsDiagnosticsSnapshotTests.swift app/Tests/LocalFlowTests/MenuRuntimeSnapshotTests.swift
git commit -m "Document Grotdown interface and output contract"
~~~

## Spec Coverage Review

| PRD requirement | Implementing task |
| --- | --- |
| Grotdown identity, dark tokens, five-bar mark, template asset | Task 1 |
| Durable preferences, History, Snippets, insertion outcomes | Task 2 |
| Safe GFM inference, code commands, Plain fallback | Task 3 |
| Format snapshot, manual-ready state, honest insertion/copy feedback | Task 4 |
| Rebindable Option-Space plus hold/toggle | Task 5 |
| 340pt panel, non-activating HUD, reduced motion | Task 6 |
| On-demand searchable History/Snippet window | Task 7 |
| General/Model/Hotkey/Output/Microphone settings and meter | Task 8 |
| Accurate MLX-only docs, preserved evidence, build/live QA | Task 9 |
