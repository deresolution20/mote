# bench — Phase-0 ASR benchmark harness

Compares on-device ASR engines on **your own** short, filler-heavy dictation
samples, and times the Ollama cleanup hop. Everything runs locally.

## Engines

| id | engine |
| --- | --- |
| `whisperkit-turbo` | WhisperKit `large-v3-v20240930_turbo` (Core ML / ANE) |
| `whisperkit-base.en` | WhisperKit `base.en` (speed reference point) |
| `apple` | Apple `SpeechTranscriber` (macOS 26 system framework) |
| `parakeet` | FluidAudio Parakeet TDT v3 |

## Usage

```bash
cd bench

# 1. One-time: download/load every model (network OK here — setup time only)
swift run bench prepare

# 2. Record the test set (~20 utterances; grants mic permission on first use).
#    Enter starts/stops each take; confirm the verbatim transcript after each —
#    the words you ACTUALLY said, fillers included.
swift run bench record

# 3. Benchmark all engines → RESULTS.md
swift run bench run

# 4. Time the cleanup hop (gemma3:4b vs gemma4:26b) → CLEANUP.md
swift run bench cleanup
```

Samples land in `Tools/Bench/samples/` (WAVs are gitignored; `manifest.json` is not).

## Tests

XCTest doesn't exist under CommandLineTools; the unit tests use Swift Testing
and need framework paths wired in by hand:

```bash
./test.sh
```

## Notes on methodology

- Latency is batch transcription of a whole recorded file with the model
  pre-loaded and warmed (one untimed warmup transcription first). It's a proxy
  for end-of-speech latency; streaming behavior is a Phase-1 concern.
- WER is word-level Levenshtein against the verbatim reference, case- and
  punctuation-insensitive (both sides normalized identically).
- References must include fillers: the ASR's job is to hear accurately;
  removing fillers is the cleanup LLM's job and is scored separately.
