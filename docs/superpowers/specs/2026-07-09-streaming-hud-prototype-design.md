# Local Flow Streaming HUD Prototype Design

## Objective

Prototype streaming partial transcripts in the Local Flow HUD without changing
the accepted cleanup contract. The user-facing experience should stay compact:
while the user holds Left Option, the HUD shows the current waveform plus a
one-line tail of the latest recognized words; after release, it holds that raw
tail through transcription and MLX cleanup, then briefly shows done/inserted
before fading.

The prototype uses FluidAudio's true streaming ASR API first, but it is
benchmark-gated against the accepted Parakeet TDT production baseline before it
can become the final transcript source.

## Accepted Decisions

- Visual direction: live caption pill, not an expanded transcript panel.
- Recording behavior: B1 tail-only caption. Show only the latest useful words,
  with no multiline transcript history.
- Post-release behavior: L2 hold raw tail. Keep the last-heard raw tail visible
  while the app transcribes, cleans, and inserts.
- Implementation direction: prototype B, using FluidAudio's
  `StreamingAsrManager` partial transcript callback.
- Cleanup remains MLX-only. No Ollama fallback, no provider selector, and no
  user-facing cleanup-provider setting.
- Raw transcript fallback remains terminal when cleanup is unavailable,
  rejected, timed out, or errors.

## Non-Goals

- Do not add a full transcript viewer, editable transcript surface, or click/copy
  behavior to the HUD.
- Do not reintroduce Ollama, cleanup provider selection, or a rollback setting.
- Do not change text insertion behavior except as needed to preserve the
  existing final pipeline.
- Do not commit the streaming ASR path as the production final transcript source
  unless the benchmark gate passes.

## UX Behavior

When recording starts, the HUD appears immediately in the existing non-activating
panel. It still shows the animated waveform bars, but once a non-empty partial
transcript is available, a compact tail appears beside the bars. The tail should
be derived from the latest partial transcript, constrained to one line, and
truncated visually when needed. Empty or unstable partials leave the HUD in the
current waveform-only recording state.

On hotkey release, the HUD keeps the last raw tail rather than replacing it with
generic status text. The phase can still change internally from recording to
transcribing and cleaning, but the visible caption remains the last-heard raw
tail until insertion completes. The done state briefly replaces the tail with a
short inserted/done indication before the existing fade-out behavior.

The HUD must remain non-activating, ignore mouse events, and never steal focus
from the paste target.

## Architecture And Data Flow

Current production path:

1. `HotkeyMonitor` starts `AudioCapture`.
2. `AudioCapture` collects final samples.
3. `Transcriber` uses Parakeet TDT through FluidAudio's offline `AsrManager`.
4. `PersonalDictionary` corrects the raw transcript.
5. `Cleaner` runs MLX cleanup with raw fallback.
6. `TextInjector` inserts the selected final text.

Prototype B adds a streaming path during the same dictation session:

1. `AudioCapture` emits live buffers while it also retains final samples.
2. A new streaming transcriber wrapper owns a FluidAudio `StreamingAsrManager`.
3. The streaming wrapper sets `setPartialTranscriptCallback` and publishes
   partial transcript updates onto the main actor.
4. `AppState` converts each partial into a tail string and passes it to the HUD.
5. On release, the streaming wrapper calls `finish()` to produce a streaming
   final raw transcript candidate.
6. The app applies `PersonalDictionary`, MLX cleanup, and insertion exactly as
   it does today for whichever final raw transcript source is accepted.

The first implementation should keep a clear switch point between the accepted
TDT final source and the prototype streaming final source. During development,
streaming can be exercised as the final transcript candidate, but the accepted
production default remains TDT until the benchmark report explicitly promotes
streaming. If streaming fails during a live dictation, the current TDT path
handles that dictation.

## Component Changes

### `AudioCapture`

Add a way to observe live `AVAudioPCMBuffer` chunks during recording while
preserving today's final-samples behavior. The callback should be optional so
tests and non-streaming use paths can keep using `start()` and `stop()` as they
do now.

### Streaming Transcriber Wrapper

Add a small wrapper around FluidAudio's `StreamingAsrManager` rather than
spreading dependency-specific calls across `AppState`. The wrapper should expose
session-level operations:

- load models
- reset/start session
- append audio buffer
- process buffered audio
- receive partial transcript updates
- finish session and return final raw transcript candidate
- fail gracefully without crashing the recording lifecycle

The prototype should start with `parakeetEou160ms` because it is the lowest
latency true streaming Parakeet variant exposed by FluidAudio. The benchmark
output must record the selected variant. If `parakeetEou160ms` fails to load,
compile, or produce useful partials, the implementation plan may add
`parakeetEou320ms` as the first fallback comparison.

### `AppState`

`AppState` remains the coordinator. It should start the streaming session on
hotkey down, feed audio buffers while recording, and finish the stream on hotkey
up. It should update `lastTranscript`, `lastCleaned`, status, cleanup, and
insertion using the existing semantics.

If streaming setup or processing fails, `AppState` should fall back to the
current phase-only HUD and existing TDT transcription path for the final
dictation. A streaming failure should not make final dictation worse than the
accepted current product.

### `HUDModel` And `WaveformHUDView`

Extend the HUD model with an optional caption tail. The view should render:

- waveform-only when no useful caption exists
- waveform plus caption tail while recording
- held caption tail during transcribing and cleaning
- done/inserted state before fade

Tail extraction should be testable outside SwiftUI. It should prefer word
boundaries, avoid resizing the panel beyond a fixed maximum width, and return an
empty caption for empty or whitespace-only partials.

## Failure Handling

- Streaming model load failure: keep current TDT final path and phase-only HUD.
- Streaming partial callback never fires: keep waveform-only recording HUD.
- Streaming partials are empty or whitespace: do not show a caption.
- Streaming processing error mid-recording: stop using streaming for that
  dictation, keep recording samples, and finish with the current TDT path.
- Streaming final transcript is empty: fall back to current TDT final path for
  that dictation.
- MLX cleanup rejection/unavailable/error/timeout: keep existing raw transcript
  terminal fallback.
- Pause while recording: stop capture, cancel/reset streaming state, hide HUD,
  and preserve today's pause behavior.

## Benchmark Gate

The prototype must produce benchmark evidence before the streaming final source
can replace Parakeet TDT as the production final transcript source.

Benchmark the streaming variant against the existing 24-sample set and the
accepted TDT baseline. Capture:

- selected streaming variant
- model load/warmup behavior
- time to first useful partial
- partial update cadence
- finalization latency after release
- final transcript text
- WER/content-WER versus references
- comparison to current TDT output on the same samples
- cleanup path outcome when the streaming final transcript is passed through
  the existing personal dictionary and MLX cleanup chain

Acceptance for making streaming the final production source should be explicit
in the benchmark report. Until then, the current TDT final transcript path
remains the accepted production baseline.

## Testing And Visual Checks

- Unit-test tail extraction, including empty strings, short partials, long
  partials, punctuation, repeated whitespace, and truncation boundaries.
- Unit-test HUD snapshot/state formatting if a testable view-model boundary is
  added.
- Run `cd app && swift test`.
- Add or extend a benchmark CLI for streaming ASR comparison.
- Use the in-app Browser visual companion for mockups and comparison screens
  during design review.
- Build the signed app bundle and smoke-test the HUD on a real dictation after
  implementation.

## Implementation Planning Defaults

- Test `parakeetEou160ms` first.
- Keep TDT as the accepted production default until a benchmark report promotes
  streaming final output.
- Require streaming final output to be at least as good as TDT on content WER,
  introduce no new cleanup meaning-loss failures, and keep finalization latency
  within the feel of the current accepted app before promotion.
- Show raw streaming partials in the HUD. Apply `PersonalDictionary` to the
  final raw transcript only, before MLX cleanup, to avoid live-caption churn.
