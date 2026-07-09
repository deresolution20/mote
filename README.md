<div align="center">

# Local Flow

**Press a key, speak, and clean text appears at your cursor — 100% on-device, fully offline.**

A native macOS menu-bar dictation app that transcribes your voice locally and tidies it up
with a local LLM. No cloud, no account, no data ever leaves your Mac.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-black?logo=apple)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-required-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-6.3-F05138?logo=swift&logoColor=white)
![Offline](https://img.shields.io/badge/network-none%20in%20dictation%20path-brightgreen)

</div>

---

## What it is

Local Flow is an offline alternative to cloud dictation tools like Wispr Flow. Hold a hotkey,
talk, and release — your speech is transcribed on the Apple Neural Engine and cleaned up
(fillers removed, punctuation and capitalization fixed, **meaning preserved**) by a small
local language model, then inserted at your cursor in whatever app is focused.

Because every stage runs on your machine, it works on a plane, keeps sensitive dictation
private, and has no subscription.

> **Example** — you say:
> *"um so like i think we should uh ship it friday"*
> and this lands at your cursor:
> **"I think we should ship it Friday."**

## Features

- 🎙️ **Push-to-talk dictation** — hold **Left ⌥ (Option)**, speak, release.
- 🧠 **On-device transcription** — [FluidAudio Parakeet v3](https://github.com/FluidInference/FluidAudio) on the Neural Engine (chosen over Whisper by benchmark — see below).
- ✨ **Local LLM cleanup** — native Swift MLX cleanup strips filler words and fixes grammar without changing meaning.
- 🌊 **Live waveform overlay** — a floating pill shows recording → transcribing → cleaning → done.
- 🔒 **Truly offline** — no network calls in the dictation path, ever.
- 🔁 **Raw transcript recoverable** — the unedited transcript is always one click away.
- ⚙️ **Standard macOS Settings** — permissions, cleanup, insertion, overlay, and personal dictionary live in `⌘,`.
- 🪶 **Two permissions only** — Microphone and Accessibility. No Input Monitoring required.

## How it works

```
 Hold Left ⌥ (Option)
        │
        ▼
 AVAudioEngine mic capture ── 16 kHz mono
        │
        ▼
 Parakeet v3 (Core ML / ANE) ── raw transcript      ← on-device ASR
        │
        ▼
 Swift MLX cleanup ── cleaned text                   ← local LLM, on-device
        │   (raw fallback; meaning-preserving guard)
        ▼
 Direct Unicode typing ── inserted at your cursor
        (clipboard paste compatibility fallback available)
```

Every stage sits behind a protocol so engines are swappable. The cleanup path is local
Swift MLX; speech-to-text is handled by the dedicated on-device ASR engine.

## Requirements

| Requirement | Why | Get it |
| --- | --- | --- |
| **macOS 26 (Tahoe) or later** | Uses current AVFoundation / SwiftUI APIs | — |
| **Apple Silicon Mac** (M1–M5) | Neural Engine for real-time ASR | — |
| **Xcode Command Line Tools** (Swift 6.3+) | Builds the app (full Xcode not required) | `xcode-select --install` |

Swift package dependencies (fetched automatically on build):
- [FluidAudio](https://github.com/FluidInference/FluidAudio) — Parakeet TDT v3 ASR (Apache-2.0)
- [WhisperKit](https://github.com/argmaxinc/argmax-oss-swift) — alternate ASR engine (MIT)

## Install (build from source)

```bash
# 1. Prerequisites
xcode-select --install                       # Swift toolchain

# 2. Build and bundle the app
git clone https://github.com/deresolution20/local-flow.git
cd local-flow/app
./bundle.sh                                   # builds + signs LocalFlow.app

# 3. Launch
open .build/LocalFlow.app
```

On first launch a setup window walks you through granting **Microphone** and **Accessibility**.

> **Tip — stop re-granting Accessibility on every rebuild:** create a self-signed
> code-signing certificate named `LocalFlow Dev` in *Keychain Access → Certificate Assistant
> → Create a Certificate* (Self-Signed Root, Code Signing). `bundle.sh` picks it up
> automatically and the permission then survives rebuilds.

## Usage

1. Click into any text field (editor, browser, chat app).
2. **Hold Left ⌥**, speak a sentence, release.
3. Cleaned text appears at your cursor; the waveform pill confirms each stage.

From the menu-bar icon you can pause/resume dictation, open Settings, copy the last
raw or cleaned transcript, start the dictation engine when needed, and quit. Durable
preferences live in the standard macOS Settings window.

## Benchmarks

ASR engines were compared on a **real 24-utterance, filler-heavy dictation set** recorded in
the author's own voice, not on public numbers. Parakeet v3 won on both accuracy and latency.
Full data: [`bench/RESULTS.md`](bench/RESULTS.md).

| Engine | Median latency | Word error rate | Model ready |
| --- | --- | --- | --- |
| **Parakeet v3** ✅ | **0.072 s** | **13.6%** | instant |
| Apple SpeechTranscriber | 0.080 s | 18.6% | instant |
| WhisperKit large-v3-turbo | 0.482 s | 23.2% | slow (ANE compile) |

Cleanup uses native Swift MLX, with raw transcript as the terminal safety fallback.
The Task 14 production-chain acceptance run is accepted after manual review: MLX
handled 23/24 samples, one sample correctly fell back to raw to preserve meaning,
and median cleanup latency was 0.195 s. Evidence is
tracked under [`docs/reports/mlx-cleanup-benchmark/runs/`](docs/reports/mlx-cleanup-benchmark/runs/).

The benchmark harness is a standalone SwiftPM CLI in [`bench/`](bench/) — record your own
samples and reproduce the numbers.

## Project layout

| Path | What it is |
| --- | --- |
| `app/` | The macOS menu-bar app (SwiftUI) |
| `bench/` | ASR + cleanup benchmark harness (SwiftPM CLI) |
| `plan.md` | Research + design document |
| `DECISIONS.md` | Engineering decision log (why Parakeet, why two permissions, field gotchas) |

## Roadmap

- [x] **Phase 0** — de-risk; benchmark and pick the ASR engine from data
- [x] **Phase 1** — hotkey → capture → ASR → paste raw text
- [x] **Phase 2 (MVP)** — local LLM cleanup with raw⇄cleaned toggle
- [x] **Phase 3 (in progress)** — animated waveform HUD + MLX default cleanup hardening
- [x] Personal dictionary (custom vocabulary / proper nouns)
- [x] Menu-bar runtime console with pause/resume and last-dictation copy actions
- [ ] Streaming partial transcripts in the overlay
- [ ] Per-app context modes and style presets

## Privacy

The dictation path makes **no network calls**. Audio is processed in memory and never
written to disk by the app. Cleanup runs locally through Swift MLX.

## Credits

Built on the excellent work of [FluidAudio](https://github.com/FluidInference/FluidAudio)
(Parakeet), [Argmax WhisperKit](https://github.com/argmaxinc/argmax-oss-swift), and
[MLX Swift](https://github.com/ml-explore/mlx-swift).

## License

[MIT](LICENSE) © 2026 Brice Neal
