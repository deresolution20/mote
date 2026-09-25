# Streaming HUD Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a benchmark-gated true streaming ASR prototype that drives a compact live HUD caption while preserving the accepted Parakeet TDT + MLX production contract.

**Architecture:** Keep the existing production final path intact by default. Add a FluidAudio `StreamingAsrManager` wrapper for partial transcript callbacks, use a shared tail formatter for the HUD, and gate any promotion of streaming final transcripts behind benchmark evidence.

**Tech Stack:** SwiftPM, SwiftUI/AppKit, FluidAudio `StreamingAsrManager`, Parakeet EOU `parakeetEou160ms`, Swift Testing, MLX-only cleanup through existing `LocalFlowCleanup`.

## Global Constraints

- Platform remains macOS 26.0+ and Apple Silicon.
- Cleanup remains MLX-only: no Ollama fallback, no provider selector, no user-facing cleanup-provider setting.
- Raw transcript fallback remains terminal for cleanup unavailable, timeout, error, or rejection.
- The HUD must remain non-activating, ignore mouse events, and never steal focus from the paste target.
- Current Parakeet TDT remains the accepted production final transcript source until a benchmark report explicitly promotes streaming.
- Streaming HUD partials show raw streaming output; `PersonalDictionary` applies to final raw transcript only.
- Start streaming prototype with `parakeetEou160ms`; use `parakeetEou320ms` only as a fallback comparison if the first variant fails to load, compile, or produce useful partials.

---

## File Structure

- Create `app/Sources/LocalFlowCleanup/HUDCaptionTail.swift`
  - Pure, testable tail extraction for B1 live captions.
- Create `app/Tests/LocalFlowTests/HUDCaptionTailTests.swift`
  - Swift Testing coverage for empty input, whitespace normalization, short text, long text, and punctuation.
- Modify `app/Sources/LocalFlow/AudioCapture.swift`
  - Add optional live 16 kHz sample chunk callback while preserving `start()` and `stop()` behavior.
- Create `app/Sources/LocalFlow/StreamingTranscriber.swift`
  - Actor wrapper around FluidAudio `StreamingAsrManager`, pinned initially to `parakeetEou160ms`.
- Modify `app/Sources/LocalFlow/WaveformHUD.swift`
  - Add optional caption tail to `HUDModel`, resize the panel, and render B1/L2 caption states.
- Modify `app/Sources/LocalFlow/AppState.swift`
  - Coordinate streaming lifecycle, HUD tail updates, fallback to TDT, and optional development-only streaming final path.
- Modify `app/Package.swift`
  - Add `local-flow-streaming-benchmark` executable target.
- Create `app/Sources/LocalFlowStreamingBenchmark/main.swift`
  - Benchmark streaming final output and partial timing against the existing 24-sample manifest.

---

### Task 1: Tail Extraction Helper

**Files:**
- Create: `app/Sources/LocalFlowCleanup/HUDCaptionTail.swift`
- Create: `app/Tests/LocalFlowTests/HUDCaptionTailTests.swift`

**Interfaces:**
- Produces: `public enum HUDCaptionTail { public static func tail(from partial: String, maxWords: Int = 5) -> String }`
- Consumes: no prior task output.

- [ ] **Step 1: Write the failing tests**

Add `app/Tests/LocalFlowTests/HUDCaptionTailTests.swift`:

```swift
import Testing
@testable import LocalFlowCleanup

@Suite struct HUDCaptionTailTests {
    @Test func returnsEmptyForWhitespaceOnlyInput() {
        #expect(HUDCaptionTail.tail(from: "   \n\t  ") == "")
    }

    @Test func normalizesWhitespaceForShortInput() {
        #expect(HUDCaptionTail.tail(from: "so   basically\nit works") == "so basically it works")
    }

    @Test func keepsShortInputWithoutPrefix() {
        #expect(HUDCaptionTail.tail(from: "the dashboard is broken again") == "the dashboard is broken again")
    }

    @Test func returnsLastWordsWithPrefixWhenTruncated() {
        let partial = "so basically the dashboard is broken again"
        #expect(HUDCaptionTail.tail(from: partial, maxWords: 4) == "...dashboard is broken again")
    }

    @Test func preservesPunctuationOnTailWords() {
        let partial = "okay so the customer said the alerts are firing twice."
        #expect(HUDCaptionTail.tail(from: partial, maxWords: 5) == "...the alerts are firing twice.")
    }

    @Test func treatsNegativeLimitAsNoCaption() {
        #expect(HUDCaptionTail.tail(from: "hello world", maxWords: -1) == "")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```bash
cd app
swift test --filter HUDCaptionTailTests
```

Expected: FAIL because `HUDCaptionTail` is not defined.

- [ ] **Step 3: Implement the helper**

Add `app/Sources/LocalFlowCleanup/HUDCaptionTail.swift`:

```swift
import Foundation

public enum HUDCaptionTail {
    public static func tail(from partial: String, maxWords: Int = 5) -> String {
        guard maxWords > 0 else { return "" }
        let words = partial
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard !words.isEmpty else { return "" }
        guard words.count > maxWords else { return words.joined(separator: " ") }
        return "..." + words.suffix(maxWords).joined(separator: " ")
    }
}
```

- [ ] **Step 4: Run the focused tests**

Run:

```bash
cd app
swift test --filter HUDCaptionTailTests
```

Expected: PASS.

- [ ] **Step 5: Run all Swift tests**

Run:

```bash
cd app
swift test
```

Expected: all existing tests plus `HUDCaptionTailTests` pass.

- [ ] **Step 6: Commit**

```bash
git add app/Sources/LocalFlowCleanup/HUDCaptionTail.swift app/Tests/LocalFlowTests/HUDCaptionTailTests.swift
git commit -m "Add HUD caption tail formatter"
```

---

### Task 2: Live Audio Chunk Emission

**Files:**
- Modify: `app/Sources/LocalFlow/AudioCapture.swift`

**Interfaces:**
- Consumes: no prior task output.
- Produces: `func start(liveSamplesHandler: (([Float]) -> Void)? = nil) throws`, preserving existing `try capture.start()` call sites.

- [ ] **Step 1: Make the signature backward-compatible**

In `AudioCapture.swift`, change:

```swift
func start() throws {
```

to:

```swift
func start(liveSamplesHandler: (([Float]) -> Void)? = nil) throws {
```

- [ ] **Step 2: Emit converted 16 kHz chunks from the tap**

Inside the existing tap closure, immediately after `let chunk = ...`, keep the existing sample append and call the handler after releasing the lock:

```swift
let chunk = Array(UnsafeBufferPointer(start: channel[0], count: Int(out.frameLength)))
self.lock.lock()
self.samples.append(contentsOf: chunk)
self.lock.unlock()
liveSamplesHandler?(chunk)
```

The full tap closure still converts microphone input into the existing `targetFormat`, so the streaming path receives the same 16 kHz mono Float32 sample chunks that `stop()` returns.

- [ ] **Step 3: Build the app target**

Run:

```bash
cd app
swift build
```

Expected: build succeeds with existing `capture.start()` call sites.

- [ ] **Step 4: Commit**

```bash
git add app/Sources/LocalFlow/AudioCapture.swift
git commit -m "Emit live audio chunks during capture"
```

---

### Task 3: Streaming Transcriber Wrapper

**Files:**
- Create: `app/Sources/LocalFlow/StreamingTranscriber.swift`

**Interfaces:**
- Consumes: live `[Float]` chunks from Task 2.
- Produces:
  - `actor StreamingTranscriber`
  - `func load() async throws`
  - `func reset() async`
  - `func setPartialHandler(_ handler: (@MainActor @Sendable (String) -> Void)?)`
  - `func append(samples: [Float]) async`
  - `func finish() async throws -> String`
  - `var isAvailable: Bool { get }`

- [ ] **Step 1: Create the wrapper actor**

Add `app/Sources/LocalFlow/StreamingTranscriber.swift`:

```swift
@preconcurrency import AVFoundation
import FluidAudio
import Foundation

actor StreamingTranscriber {
    typealias PartialHandler = @MainActor @Sendable (String) -> Void

    private var manager: (any StreamingAsrManager)?
    private var partialHandler: PartialHandler?
    private var available = false
    private var failedCurrentSession = false

    var isAvailable: Bool {
        available
    }

    func load() async throws {
        guard manager == nil else {
            available = true
            return
        }
        let manager = StreamingModelVariant.parakeetEou160ms.createManager()
        await manager.setPartialTranscriptCallback { [weak self] text in
            Task {
                await self?.emitPartial(text)
            }
        }
        try await manager.loadModels()
        self.manager = manager
        available = true
    }

    func setPartialHandler(_ handler: PartialHandler?) {
        partialHandler = handler
    }

    func reset() async {
        failedCurrentSession = false
        guard let manager else { return }
        do {
            try await manager.reset()
        } catch {
            failedCurrentSession = true
        }
    }

    func append(samples: [Float]) async {
        guard !failedCurrentSession, let manager, !samples.isEmpty else { return }
        do {
            let buffer = try Self.makeBuffer(samples: samples)
            try await manager.appendAudio(buffer)
            try await manager.processBufferedAudio()
        } catch {
            failedCurrentSession = true
        }
    }

    func finish() async throws -> String {
        guard !failedCurrentSession, let manager else { return "" }
        let text = try await manager.finish()
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func emitPartial(_ text: String) async {
        await partialHandler?(text)
    }

    private static func makeBuffer(samples: [Float]) throws -> AVAudioPCMBuffer {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )!
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        ) else {
            throw NSError(domain: "LocalFlow", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "could not allocate streaming audio buffer"
            ])
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let channel = buffer.floatChannelData {
            samples.withUnsafeBufferPointer { source in
                channel[0].update(from: source.baseAddress!, count: samples.count)
            }
        }
        return buffer
    }
}
```

- [ ] **Step 2: Build to validate FluidAudio API use**

Run:

```bash
cd app
swift build
```

Expected: build succeeds. If `StreamingModelVariant.parakeetEou160ms` or `createManager()` changed upstream, update this file to the currently available FluidAudio API and record the exact variant name in the benchmark output.

- [ ] **Step 3: Commit**

```bash
git add app/Sources/LocalFlow/StreamingTranscriber.swift
git commit -m "Add streaming transcriber wrapper"
```

---

### Task 4: HUD Caption Rendering And AppState Integration

**Files:**
- Modify: `app/Sources/LocalFlow/WaveformHUD.swift`
- Modify: `app/Sources/LocalFlow/AppState.swift`

**Interfaces:**
- Consumes: `HUDCaptionTail.tail(from:maxWords:)` from Task 1 and `StreamingTranscriber` from Task 3.
- Produces:
  - `HUDController.show(_:captionTail:)`
  - `HUDController.updateCaptionTail(_:)`
  - HUD model property `captionTail`
  - Streaming lifecycle from hotkey down to hotkey release.

- [ ] **Step 1: Extend the HUD model**

In `WaveformHUD.swift`, change `HUDModel` to:

```swift
@MainActor
final class HUDModel: ObservableObject {
    @Published var phase: HUDPhase = .recording
    @Published var captionTail: String = ""
}
```

- [ ] **Step 2: Add caption-aware controller methods**

In `HUDController`, change `size`:

```swift
private static let size = CGSize(width: 300, height: 56)
```

Replace `func show(_ phase: HUDPhase)` with:

```swift
func show(_ phase: HUDPhase, captionTail: String = "") {
    guard enabled else { return }
    hideGeneration += 1
    model.phase = phase
    model.captionTail = captionTail
    let panel = panel ?? makePanel()
    reposition(panel)
    panel.alphaValue = 1
    panel.orderFrontRegardless()
}
```

Add:

```swift
func updateCaptionTail(_ captionTail: String) {
    guard enabled, panel != nil else { return }
    model.captionTail = captionTail
}
```

In `finishAndHide()`, clear the caption before showing done:

```swift
model.phase = .done
model.captionTail = ""
```

In `hide()`, also clear the caption:

```swift
model.captionTail = ""
panel?.orderOut(nil)
```

- [ ] **Step 3: Render B1/L2 in `WaveformHUDView`**

Replace the `body` switch content with this structure:

```swift
var body: some View {
    HStack(spacing: 8) {
        switch model.phase {
        case .recording:
            WaveBars(animating: true, tint: .accentColor)
            captionText
        case .transcribing:
            WaveBars(animating: true, tint: .secondary)
            captionTextOrFallback("Transcribing")
        case .cleaning:
            Image(systemName: "sparkles").foregroundStyle(Color.accentColor)
            captionTextOrFallback("Cleaning up")
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text("Done").font(.caption).foregroundStyle(.secondary)
        }
    }
    .padding(.horizontal, 18)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.regularMaterial, in: Capsule())
    .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
    .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
    .padding(6)
    .animation(.easeInOut(duration: 0.2), value: model.phase)
    .animation(.easeInOut(duration: 0.15), value: model.captionTail)
}

@ViewBuilder
private var captionText: some View {
    if !model.captionTail.isEmpty {
        Text(model.captionTail)
            .font(.caption)
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(.primary)
            .frame(maxWidth: 210, alignment: .leading)
    }
}

@ViewBuilder
private func captionTextOrFallback(_ fallback: String) -> some View {
    if model.captionTail.isEmpty {
        Text(fallback).font(.caption).foregroundStyle(.secondary)
    } else {
        captionText
    }
}
```

- [ ] **Step 4: Add streaming properties to `AppState`**

In `AppState`, near `private let transcriber = Transcriber()`, add:

```swift
private let streamingTranscriber = StreamingTranscriber()
private var streamingLoaded = false
private var currentHUDTail = ""
private var useStreamingFinalTranscript: Bool {
    ProcessInfo.processInfo.environment["LOCALFLOW_STREAMING_FINAL"] == "1"
}
```

- [ ] **Step 5: Load streaming models without blocking the accepted TDT path**

In `startPipeline()`, after `try await transcriber.load()` succeeds, add:

```swift
do {
    try await streamingTranscriber.load()
    streamingLoaded = true
} catch {
    streamingLoaded = false
}
```

Keep failure silent in the UI for this prototype so model-load failure degrades to today's phase-only HUD and TDT final path.

- [ ] **Step 6: Feed live chunks and update HUD tails on hotkey down**

In `hotkeyPressed()`, before `capture.start`, configure the streaming callback:

```swift
currentHUDTail = ""
let streamingTranscriber = self.streamingTranscriber
if streamingLoaded {
    Task {
        await streamingTranscriber.reset()
        await streamingTranscriber.setPartialHandler { [weak self] partial in
            guard let self else { return }
            let tail = HUDCaptionTail.tail(from: partial)
            guard tail != self.currentHUDTail else { return }
            self.currentHUDTail = tail
            HUDController.shared.updateCaptionTail(tail)
        }
    }
}
```

Change the capture start call from:

```swift
try capture.start()
```

to:

```swift
try capture.start(liveSamplesHandler: streamingLoaded ? { chunk in
    Task {
        await streamingTranscriber.append(samples: chunk)
    }
} : nil)
```

Change the recording HUD call to:

```swift
HUDController.shared.show(.recording, captionTail: currentHUDTail)
```

- [ ] **Step 7: Preserve the L2 raw tail through release phases**

In `hotkeyReleased()`, keep the existing state transitions but pass the current tail:

```swift
HUDController.shared.show(.transcribing, captionTail: currentHUDTail)
```

and:

```swift
HUDController.shared.show(.cleaning, captionTail: currentHUDTail)
```

- [ ] **Step 8: Finish streaming and keep TDT as the default final source**

In the transcription task inside `hotkeyReleased()`, before calling the existing TDT transcriber, start a streaming finish task:

```swift
let streamingFinishTask: Task<String, Never>? = streamingLoaded ? Task {
    (try? await streamingTranscriber.finish()) ?? ""
} : nil
```

Then replace:

```swift
let heard = try await transcriber.transcribe(samples)
```

with:

```swift
let tdtHeard = try await transcriber.transcribe(samples)
let streamingHeard = await streamingFinishTask?.value ?? ""
let heard = useStreamingFinalTranscript && !streamingHeard.isEmpty ? streamingHeard : tdtHeard
```

This keeps TDT as the default final source while allowing development runs with:

```bash
LOCALFLOW_STREAMING_FINAL=1 swift run LocalFlow
```

- [ ] **Step 9: Build and run tests**

Run:

```bash
cd app
swift test
swift build
```

Expected: tests pass and app builds.

- [ ] **Step 10: Commit**

```bash
git add app/Sources/LocalFlow/WaveformHUD.swift app/Sources/LocalFlow/AppState.swift
git commit -m "Wire streaming partials into HUD"
```

---

### Task 5: Streaming Benchmark CLI

**Files:**
- Modify: `app/Package.swift`
- Create: `app/Sources/LocalFlowStreamingBenchmark/main.swift`

**Interfaces:**
- Consumes: FluidAudio `StreamingModelVariant.parakeetEou160ms`, `bench/samples/manifest.json`, and sample WAV files.
- Produces: executable `local-flow-streaming-benchmark` with JSON output containing `variant`, `timeToFirstPartialSeconds`, `finalizationLatencySeconds`, `streamingText`, `reference`, `wer`, and `contentWER`.

- [ ] **Step 1: Add the executable target**

In `app/Package.swift`, add this target before the test target:

```swift
.executableTarget(
    name: "local-flow-streaming-benchmark",
    dependencies: [
        .product(name: "FluidAudio", package: "FluidAudio"),
        "LocalFlowCleanup",
    ],
    path: "Sources/LocalFlowStreamingBenchmark"
),
```

- [ ] **Step 2: Create benchmark command skeleton**

Create `app/Sources/LocalFlowStreamingBenchmark/main.swift`:

```swift
@preconcurrency import AVFoundation
import FluidAudio
import Foundation
import LocalFlowCleanup

@main
struct StreamingBenchmarkCommand {
    static func main() async {
        do {
            let options = try Options.parse(CommandLine.arguments)
            let manifest = try loadManifest(from: options.manifestPath)
            let samples = options.limit.map { Array(manifest.samples.prefix($0)) } ?? manifest.samples
            let manager = StreamingModelVariant.parakeetEou160ms.createManager()
            let loadStarted = Date()
            try await manager.loadModels()
            let loadSeconds = Date().timeIntervalSince(loadStarted)

            var results: [SampleResult] = []
            for sample in samples {
                try await manager.reset()
                let url = options.manifestPath.deletingLastPathComponent().appendingPathComponent(sample.file)
                let result = try await runSample(sample: sample, url: url, manager: manager)
                results.append(result)
            }

            let output = BenchmarkOutput(
                task: "streaming-hud-asr-benchmark",
                createdAt: ISO8601DateFormatter().string(from: Date()),
                status: "completed",
                variant: StreamingModelVariant.parakeetEou160ms.rawValue,
                manifestPath: options.manifestPath.path,
                loadSeconds: loadSeconds,
                sampleCount: results.count,
                summary: BenchmarkSummary(samples: results),
                samples: results
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(output)
            if let outputPath = options.outputPath {
                try FileManager.default.createDirectory(
                    at: outputPath.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: outputPath, options: .atomic)
            } else {
                FileHandle.standardOutput.write(data)
                FileHandle.standardOutput.write(Data("\n".utf8))
            }
        } catch {
            FileHandle.standardError.write(Data("streaming benchmark failed: \(error)\n".utf8))
            Foundation.exit(1)
        }
    }
}
```

- [ ] **Step 3: Add sample runner and metrics**

Below the command, add:

```swift
private func runSample(
    sample: ManifestSample,
    url: URL,
    manager: any StreamingAsrManager
) async throws -> SampleResult {
    let file = try AVAudioFile(forReading: url)
    let chunkFrames: AVAudioFrameCount = 4096
    let partialStats = PartialStats()
    let sampleStarted = Date()

    await manager.setPartialTranscriptCallback { partial in
        guard !partial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        partialStats.record(at: Date().timeIntervalSince(sampleStarted))
    }

    while file.framePosition < file.length {
        let remaining = AVAudioFrameCount(file.length - file.framePosition)
        let frames = min(chunkFrames, remaining)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames) else {
            throw CommandError.invalidAudioBuffer
        }
        try file.read(into: buffer, frameCount: frames)
        try await manager.appendAudio(buffer)
        try await manager.processBufferedAudio()
    }

    let finishStarted = Date()
    let streamingText = try await manager.finish().trimmingCharacters(in: .whitespacesAndNewlines)
    let finalizationSeconds = Date().timeIntervalSince(finishStarted)
    let totalSeconds = Date().timeIntervalSince(sampleStarted)
    let werValue = wer(reference: sample.reference, hypothesis: streamingText, fillerInsensitive: false)
    let contentWERValue = wer(reference: sample.reference, hypothesis: streamingText, fillerInsensitive: true)

    return SampleResult(
        id: sample.id,
        file: sample.file,
        reference: sample.reference,
        streamingText: streamingText,
        timeToFirstPartialSeconds: partialStats.firstPartialAt,
        partialCount: partialStats.count,
        finalizationLatencySeconds: finalizationSeconds,
        totalLatencySeconds: totalSeconds,
        wer: werValue,
        contentWER: contentWERValue
    )
}
```

Add this thread-safe callback stats holder below `runSample`:

```swift
private final class PartialStats: @unchecked Sendable {
    private let lock = NSLock()
    private var _firstPartialAt: TimeInterval?
    private var _count = 0

    var firstPartialAt: TimeInterval? {
        lock.lock()
        defer { lock.unlock() }
        return _firstPartialAt
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return _count
    }

    func record(at timestamp: TimeInterval) {
        lock.lock()
        if _firstPartialAt == nil {
            _firstPartialAt = timestamp
        }
        _count += 1
        lock.unlock()
    }
}
```

- [ ] **Step 4: Add option parsing and JSON structs**

Add the same manifest default pattern used by `LocalFlowCleanupAcceptance/main.swift`, with these structs:

```swift
private struct Options {
    let manifestPath: URL
    let outputPath: URL?
    let limit: Int?

    static func parse(_ arguments: [String]) throws -> Options {
        var manifestPath: URL?
        var outputPath: URL?
        var limit: Int?
        var index = 1
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--manifest":
                manifestPath = URL(fileURLWithPath: try value(after: argument, in: arguments, at: &index))
            case "--output":
                outputPath = URL(fileURLWithPath: try value(after: argument, in: arguments, at: &index))
            case "--limit":
                let raw = try value(after: argument, in: arguments, at: &index)
                guard let parsed = Int(raw), parsed > 0 else {
                    throw CommandError.invalidArgument("--limit must be a positive integer")
                }
                limit = parsed
            default:
                throw CommandError.invalidArgument("unknown argument \(argument)")
            }
            index += 1
        }
        return Options(
            manifestPath: manifestPath ?? defaultManifestPath(),
            outputPath: outputPath,
            limit: limit
        )
    }

    private static func value(after argument: String, in arguments: [String], at index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw CommandError.invalidArgument("missing value for \(argument)")
        }
        index = valueIndex
        return arguments[valueIndex]
    }
}

private enum CommandError: Error, CustomStringConvertible {
    case invalidArgument(String)
    case invalidAudioBuffer
    case missingManifest([String])

    var description: String {
        switch self {
        case .invalidArgument(let message): return message
        case .invalidAudioBuffer: return "could not allocate audio buffer"
        case .missingManifest(let candidates):
            return "could not find manifest at any candidate path: \(candidates.joined(separator: ", "))"
        }
    }
}

private struct Manifest: Decodable {
    let samples: [ManifestSample]
}

private struct ManifestSample: Decodable {
    let file: String
    let id: String
    let reference: String
}

private struct BenchmarkOutput: Encodable {
    let task: String
    let createdAt: String
    let status: String
    let variant: String
    let manifestPath: String
    let loadSeconds: TimeInterval
    let sampleCount: Int
    let summary: BenchmarkSummary
    let samples: [SampleResult]
}

private struct SampleResult: Encodable {
    let id: String
    let file: String
    let reference: String
    let streamingText: String
    let timeToFirstPartialSeconds: TimeInterval?
    let partialCount: Int
    let finalizationLatencySeconds: TimeInterval
    let totalLatencySeconds: TimeInterval
    let wer: Double
    let contentWER: Double
}
```

- [ ] **Step 5: Add manifest loading and WER helpers**

Add:

```swift
private func defaultManifestPath() -> URL {
    let candidates = [
        URL(fileURLWithPath: "bench/samples/manifest.json"),
        URL(fileURLWithPath: "../bench/samples/manifest.json"),
    ]
    for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
        return candidate
    }
    return candidates[0]
}

private func loadManifest(from url: URL) throws -> Manifest {
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw CommandError.missingManifest([
            "bench/samples/manifest.json",
            "../bench/samples/manifest.json",
        ])
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(Manifest.self, from: data)
}

private struct BenchmarkSummary: Encodable {
    let medianTimeToFirstPartialSeconds: TimeInterval?
    let medianFinalizationLatencySeconds: TimeInterval?
    let meanWER: Double
    let meanContentWER: Double

    init(samples: [SampleResult]) {
        medianTimeToFirstPartialSeconds = median(samples.compactMap(\.timeToFirstPartialSeconds))
        medianFinalizationLatencySeconds = median(samples.map(\.finalizationLatencySeconds))
        meanWER = samples.isEmpty ? 0 : samples.map(\.wer).reduce(0, +) / Double(samples.count)
        meanContentWER = samples.isEmpty ? 0 : samples.map(\.contentWER).reduce(0, +) / Double(samples.count)
    }
}

private func median(_ values: [Double]) -> Double? {
    guard !values.isEmpty else { return nil }
    let sorted = values.sorted()
    let middle = sorted.count / 2
    if sorted.count % 2 == 0 {
        return (sorted[middle - 1] + sorted[middle]) / 2
    }
    return sorted[middle]
}

private let fillerWords: Set<String> = ["um", "uh", "like"]

private func wer(reference: String, hypothesis: String, fillerInsensitive: Bool) -> Double {
    let referenceWords = normalizedWords(reference, fillerInsensitive: fillerInsensitive)
    let hypothesisWords = normalizedWords(hypothesis, fillerInsensitive: fillerInsensitive)
    guard !referenceWords.isEmpty else { return hypothesisWords.isEmpty ? 0 : 1 }
    return Double(editDistance(referenceWords, hypothesisWords)) / Double(referenceWords.count)
}

private func normalizedWords(_ text: String, fillerInsensitive: Bool) -> [String] {
    let words = text
        .lowercased()
        .split { !$0.isLetter && !$0.isNumber && $0 != "'" }
        .map(String.init)
    guard fillerInsensitive else { return words }
    return words.filter { !fillerWords.contains($0) }
}

private func editDistance(_ a: [String], _ b: [String]) -> Int {
    var previous = Array(0...b.count)
    var current = previous
    for i in 1...a.count {
        current[0] = i
        for j in 1...b.count {
            let substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
            current[j] = min(previous[j] + 1, current[j - 1] + 1, substitution)
        }
        swap(&previous, &current)
    }
    return previous[b.count]
}
```

- [ ] **Step 6: Build the benchmark**

Run:

```bash
cd app
swift build --product local-flow-streaming-benchmark
```

Expected: build succeeds.

- [ ] **Step 7: Smoke-run one sample**

Run:

```bash
cd app
swift run local-flow-streaming-benchmark --limit 1 --output /tmp/local-flow-streaming-smoke.json
```

Expected: JSON file exists and includes `variant`, `timeToFirstPartialSeconds`, `streamingText`, `wer`, and `contentWER`.

- [ ] **Step 8: Commit**

```bash
git add app/Package.swift app/Sources/LocalFlowStreamingBenchmark/main.swift
git commit -m "Add streaming ASR benchmark"
```

---

### Task 6: Final Verification And Visual Smoke

**Files:**
- No new files required.
- May modify `docs/phase-3-handoff.md` only if the user asks for a handoff refresh after implementation.

**Interfaces:**
- Consumes all prior tasks.
- Produces verified implementation evidence.

- [ ] **Step 1: Run Swift tests**

```bash
cd app
swift test
```

Expected: all tests pass.

- [ ] **Step 2: Build app**

```bash
cd app
./bundle.sh
```

Expected: signed `LocalFlow.app` builds and includes existing MLX resources.

- [ ] **Step 3: Run streaming benchmark on full sample set**

```bash
cd app
swift run local-flow-streaming-benchmark \
  --output ../docs/reports/mlx-cleanup-benchmark/runs/2026-07-09-streaming-hud-prototype/streaming-benchmark.json
```

Expected: JSON output contains 24 samples unless the manifest sample count has changed.

- [ ] **Step 4: Visual-check HUD behavior**

Use the in-app Browser visual workflow for mockup comparison if design changes are needed. For the actual app, run the signed bundle and manually verify:

- Recording shows waveform plus latest raw tail once partials arrive.
- Releasing the hotkey holds the last raw tail during transcribing/cleaning.
- Done state fades without stealing focus.
- If streaming models are unavailable, the HUD falls back to phase-only behavior and final insertion still works through TDT.

- [ ] **Step 5: Record final status**

Run:

```bash
git status --short --branch
```

Expected: only intentional implementation/report changes are present.

- [ ] **Step 6: Commit verification/report updates if any were created**

```bash
git add docs/reports/mlx-cleanup-benchmark/runs/2026-07-09-streaming-hud-prototype/streaming-benchmark.json
git commit -m "Record streaming HUD prototype benchmark"
```

Skip this commit if no report artifact is created.
