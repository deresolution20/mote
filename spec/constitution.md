# Local Flow Constitution

## Language And Runtime

Local Flow is a Swift codebase with two SwiftPM packages:

- `app/`: the production macOS menu-bar executable target, `LocalFlow`.
- `bench/`: the benchmark and acceptance harness executable target, `bench`.

Package manifests currently use `swift-tools-version: 5.10`, while project docs
require Swift 6.3+ from Xcode Command Line Tools. The app targets macOS 26.0+
and is expected to run on Apple Silicon.

## Frameworks And Dependencies

The app is a native SwiftUI/AppKit menu-bar application. It uses AVFoundation
for microphone capture, NSEvent/CoreGraphics/AppKit accessibility APIs for
push-to-talk and text insertion, FluidAudio Parakeet v3 for speech-to-text, and
local cleanup providers only. Ollama at `http://localhost:11434` with
`gemma3:4b` is the local rollback/fallback cleanup provider. Swift-native MLX
with `mlx-community/Qwen2.5-1.5B-Instruct-4bit` is the accepted production
default cleanup provider after the Task 14 acceptance run and manual review.

The benchmark package may use alternate ASR engines for comparison. It currently
depends on WhisperKit through `argmax-oss-swift`, FluidAudio, and
`swift-argument-parser`.

## Running And Testing

Build the app:

```bash
cd app
swift build
```

Build the signed `.app` bundle:

```bash
cd app
./bundle.sh
```

Launch the bundled app:

```bash
open app/.build/LocalFlow.app
```

First run requires Microphone and Accessibility permissions. Default cleanup
requires the MLX model files plus `mlx.metallib` in the app bundle runtime
lookup path. Ollama rollback/fallback requires local Ollama and the
`gemma3:4b` model.

Run benchmark commands from `bench/`:

```bash
cd bench
swift run bench prepare
swift run bench record
swift run bench run
swift run bench cleanup
```

Run bench tests with the wrapper, not bare `swift test`:

```bash
cd bench
./test.sh
```

The wrapper is required because Command Line Tools does not provide XCTest, and
Swift Testing needs explicit framework and rpath wiring. The app package has
Swift Testing coverage and should pass:

```bash
cd app
swift test
```

App behavior changes must also pass `swift build` or `./bundle.sh`, plus a
manual smoke test of permissions, hotkey capture, transcription, cleanup, and
insertion when those areas are touched.

## Naming Conventions

Use Swift standard naming:

- Types, protocols, enums, and views use `UpperCamelCase`.
- Functions, methods, properties, enum cases, and local variables use
  `lowerCamelCase`.
- Prefer one focused primary type per file, with the filename matching that type
  where practical.
- Keep app files aligned to their current responsibilities: `AppState`
  orchestrates the pipeline, `HotkeyMonitor` owns push-to-talk, `AudioCapture`
  owns microphone capture, `Transcriber` owns ASR, `Cleaner` owns local cleanup,
  `PersonalDictionary` owns vocabulary correction, `TextInjector` owns text
  insertion, and `WaveformHUD` owns the overlay.
- Benchmark engine implementations use `<EngineName>Engine.swift`.
- Use `@MainActor` for UI state and UI controllers.
- Comments should document non-obvious invariants and operational constraints,
  not restate simple code.

## Non-Negotiable Rules

The dictation path is local-first and privacy-preserving. No cloud service,
account system, analytics, telemetry, crash reporting, remote cleanup endpoint,
or non-local ASR may be added to the runtime dictation path.

Cleanup providers are cleanup only. They must never be treated as ASR engines.
Ollama must remain hard-coded or otherwise constrained to localhost. MLX must
remain Swift-native/local in the app runtime. Cloud-routed cleanup models are
not allowed.

Audio and transcripts must not be written to disk by the app. The raw transcript
must remain recoverable for the last dictation, and cleanup must fall back to raw
text whenever the LLM output is slow, empty, implausible, or meaning-changing.

Cleanup must preserve meaning. Do not remove hedges, requests, attribution,
intent, personal-dictionary terms, or other protected markers. Prompt changes
and plausibility-guard changes require acceptance testing against the benchmark
utterance set.

MLX is the accepted default cleanup provider. Do not change the default cleanup
provider or remove Ollama rollback/fallback without a new task spec, formal
acceptance evidence, and an explicit rollback plan.

The app keeps the two-permission model: Microphone and Accessibility only. Do
not add Input Monitoring, Screen Recording, Full Disk Access, App Sandbox
requirements, accounts, or secrets unless the user explicitly approves a design
that justifies the change.

Text insertion must default to direct Unicode typing so the clipboard is not
touched. Clipboard insertion may remain as a compatibility fallback, but it must
restore the full previous clipboard contents.

The waveform HUD must remain non-activating, ignore mouse events, and never steal
focus from the target app.

The codebase must stay license-clean. `reference/` material and unlicensed
projects may be studied locally but not copied. Do not publish private/internal
files, change repository visibility, commit `GOAL.md`, or commit Brice's work
email without explicit approval.
