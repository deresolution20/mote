# Local Flow

Fully-local, offline voice dictation for macOS — press a hotkey, speak, and
cleaned-up text appears at your cursor in whatever app is focused.

## Status

**Phase 0 — de-risking / ASR benchmarking.** Not yet a working app. See
`plan.md` for the full design and `DECISIONS.md` for the decision log.

## How it works (target pipeline)

```
global hotkey → AVAudioEngine mic capture (16 kHz)
             → on-device ASR (engine chosen by benchmark:
                WhisperKit large-v3-turbo · Apple SpeechTranscriber · FluidAudio Parakeet v3)
             → cleanup by a small local LLM via Ollama (gemma3:4b —
                removes filler, fixes punctuation/grammar, never changes meaning)
             → clipboard + synthesized ⌘V paste at the cursor
```

Guardrails:

- **No network calls in the dictation path** — everything runs on-device.
- **Ollama is cleanup-only**, never speech-to-text.
- The **raw transcript is always kept** as a fallback when cleanup is on.

## Repo layout

| Path | What it is |
| --- | --- |
| `plan.md` | Fact-checked research + design doc |
| `DECISIONS.md` | Decision log |
| `bench/` | ASR benchmark harness (SwiftPM CLI) |
| `reference/` | Gitignored local clones of reference apps — evaluation only, not our code |

## Requirements

- macOS 26+ on Apple Silicon
- Swift 6.3+ Command Line Tools (full Xcode not required)
- Ollama running locally (`localhost:11434`)

Private, local-only repository.
