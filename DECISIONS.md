# Local Flow — decision log

## 2026-07-08 — MLX default accepted; sample 17 raw fallback approved

Task 14 is accepted as the production default-provider decision. Local Flow now
defaults to Swift-native MLX cleanup. The user-facing product is MLX-only: no
provider selector and no Ollama rollback setting. Ollama remains in the codebase
as a hidden engineering fallback for MLX unavailable/timeout/error states until
a separate removal plan exists. Raw transcript remains the terminal safety
fallback.

Brice manually approved sample 17's raw fallback. MLX correctly rejected
`"Yeah, the new hire starts next Monday."` because it dropped the protected
marker `i think`; pasting the raw transcript is the intended safe behavior for
that sample.

Current insertion default is direct Unicode typing, not clipboard paste. The
clipboard path remains available as a compatibility fallback and must restore
the previous clipboard contents.

## 2026-07-04 — published as a public MIT repo

Repo: https://github.com/deresolution20/local-flow (public, MIT, owner
deresolution20). Explicitly confirmed public with Brice per org policy.
Before publishing: scanned for secrets (clean); rewrote all commit history to
author `deresolution20 <deresolution20@users.noreply.github.com>` (work email
kept off the public record, Brice's choice); purged `GOAL.md` (internal agent
scaffolding) from the entire history and gitignored it. Added a showpiece
README + MIT LICENSE. `bench/samples/*.wav` remain gitignored.

## 2026-07-04 — Phase 3 started: waveform HUD shipped + polish

Post-MVP work, all verified live by Brice:

- **Waveform HUD** (accepted): floating bottom-center pill, non-activating
  panel (never steals paste focus), decorative animated bars while recording →
  transcribing → cleaning → done → fade. Auto light/dark. Menu toggle. Chosen
  over mic-reactive to keep it simple; revisit if amplitude reactivity wanted.
- **Stable code-signing identity** ("LocalFlow Dev" self-signed cert, created
  via CLI + `security add-trusted-cert` + `set-key-partition-list` so codesign
  runs non-interactively). `bundle.sh` auto-uses it. Ends the
  remove/re-add-Accessibility-every-rebuild treadmill (TCC now keys on the
  cert, not the ad-hoc CDHash).
- **User-settable Ollama keep-alive**, default 10 min (was hard-coded 60m):
  menu presets + free numeric field in setup window. 0 = unload immediately.

- **Personal dictionary** (shipped): custom-vocabulary correction pass on the
  raw transcript before cleanup. Phonetic match = Soundex key equality + tight
  Levenshtein (shared initial required) to avoid rewriting ordinary words.
  Fixes Brice's top miss ("Grafani's"→"Grafana"), also enforces canonical
  casing ("kubernetes"→"Kubernetes"). Terms managed in the setup window and
  protected through cleanup. Verified on the real benchmark misses + negative
  cases (coffee/meeting untouched). Multi-word terms and possessive edge
  ("Grafana's"→"Grafana") are known v1 limitations.

Remaining Phase-3 ideas (not started): per-app context modes, style presets,
streaming ASR partials in the HUD.

## 2026-07-03 — **MVP ACCEPTED (Phase 2 complete)**

Brice verified live: "um so like i think we should uh ship it friday" →
"I think we should ship it Friday." and "are you there" → "Are you there?"
pasted at the cursor, fully offline. Formal acceptance over his 24 recorded
utterances: 21 cleaned, 3 guarded raw fallbacks, **zero meaning changes**
(`bench/ACCEPTANCE.md`).

Final stack: Left ⌥ push-to-talk (NSEvent, Accessibility-only) →
AVAudioEngine 16 kHz → **Parakeet v3** (~0.07 s) → **gemma3:4b** cleanup
(~0.74 s median, v3 few-shot prompt + protected-phrase guard, raw always
recoverable) → clipboard+⌘V injection.

Honest gap vs plan: end-to-end ≈0.8 s after release vs the inferred 0.5 s
target — felt acceptable in live use. Phase-3 levers if it starts to grate:
streaming cleanup, ~1.5–2B model, MLX hop, skip-cleanup-on-short-utterances.

## 2026-07-03 — speak2 is reference-only (no license)

speak2 has **no license** in any tag (v1.0.0–v1.8.1), no README grant, and GitHub
detects none — the plan.md claim that it is MIT is refuted. Unlicensed code is
all-rights-reserved, so it cannot be a code foundation for something that may
become a consulting-business product.

**Decision (Brice):** clone/build/run speak2 locally for private Phase-0
evaluation only; Local Flow is **original code**. Treat speak2 exactly like the
GPL'd references (VoiceInk) — study architecture, never copy code. The clone
lives in `reference/` which is gitignored.

Libraries remain license-clean: WhisperKit (MIT, now inside
`argmaxinc/argmax-oss-swift`), FluidAudio (Apache-2.0), Apple system frameworks.

## 2026-07-03 — CLT-only toolchain, `swift build`

Full Xcode is not installed (CommandLineTools only, Swift 6.3.2). speak2 needs
`xcodebuild` only for MLX Metal shaders used by its *built-in* LLM — a feature
we don't use (Ollama does cleanup). **Decision (Brice):** stay CLT-only with
`swift build`; install Xcode later only if blocked. Local Flow itself takes no
MLX dependency, so this constraint doesn't touch our own code.

## 2026-07-03 — dependency pins

- WhisperKit: pin `https://github.com/argmaxinc/argmax-oss-swift` (product
  `WhisperKit`). The old `argmaxinc/WhisperKit` repo is gone (git-redirects for
  now, but don't rely on it).
- Parakeet: `https://github.com/FluidInference/FluidAudio` (Apache-2.0).
- Cleanup model: `gemma3:4b` via Ollama (proven for this exact task by speak2).
  `gemma4:26b` is quality-ceiling comparison only — too slow for the live loop.
- Never use the `:cloud`-tagged models in `ollama list` — they are cloud-routed
  and violate the offline guardrail.

## 2026-07-03 — gemma3:4b cleanup: few-shot prompt is load-bearing

Verified against local Ollama (warm model):

- With a plain instruction-only prompt, gemma3:4b **drops hedges as filler** —
  "um so like i think we should uh ship it friday" → "Ship it Friday."
  (loses "I think we should": a meaning change, exactly plan.md §9 risk 2).
- Adding two few-shot examples + an explicit "hedges like i think, maybe,
  probably are meaning and must stay" rule fixed it on a held-out utterance
  ("we should **probably** loop in the security team on Monday." — hedge kept).
- Warm generation latency: ~140–530 ms per short utterance (t=0.1). Cold model
  load adds ~2.1 s — the app must keep the model resident (Ollama `keep_alive`).

The canonical prompt lives in `bench/Sources/bench/OllamaCleanup.swift` and is
the starting point for Phase-2 tuning over the full 20-utterance set.

## 2026-07-03 — CLT quirk: XCTest absent, Swift Testing needs manual paths

CommandLineTools has no XCTest at all. Swift Testing (`import Testing`) works,
but CLT ships `Testing.framework` outside SwiftPM's default search paths —
`bench/test.sh` wires in the framework + `lib_TestingInterop.dylib` rpaths.
Use `./test.sh`, not bare `swift test`.

## 2026-07-03 — smoke test: all 4 engines work end-to-end (CLT-only)

Ran the harness over `say`-synthesized audio (2 clips — directional only, real
decision comes from Brice's recordings):

- **WhisperKit large-v3-turbo** and **Parakeet v3** both transcribed verbatim
  (0% WER, fillers kept). Warm per-clip: turbo ~0.47 s, Parakeet ~0.07 s.
- **Apple SpeechTranscriber strips fillers by design** — SDK-verified that its
  only `TranscriptionOption` is `etiquetteReplacements`; there is **no verbatim
  mode**. Consequences: (a) benchmark adds a filler-insensitive "content WER"
  so Apple isn't unfairly penalized; (b) if Apple wins, the cleanup LLM receives
  a non-verbatim transcript — raw-transcript recoverability then means "as
  heard by Apple", not "as spoken".
- **WhisperKit base.en** misheard "Um so" → "I'm so" even on clean synthetic
  audio — speed reference only.
- First-run load/warmup is dominated by download + Core ML/ANE compilation
  (turbo warmup ~100 s, Parakeet load ~128 s first time).
- **Steady-state (second process, models cached):**

  | Engine | Load | Warmup | Per-clip |
  | --- | --- | --- | --- |
  | WhisperKit large-v3-turbo | 65.3 s | 99.0 s | ~0.47 s |
  | WhisperKit base.en | 2.6 s | 0.7 s | ~0.08 s |
  | Apple SpeechTranscriber | 0.05 s | 0.14 s | ~0.07 s |
  | Parakeet v3 | 0.14 s | 0.10 s | ~0.07 s |

  WhisperKit turbo's ANE compilation is NOT reused across processes on this
  machine — ~2.7 min to first dictation per app launch is a serious strike
  against it unless a fix exists (open question: WhisperKit prewarm/model-cache
  settings). Parakeet and Apple ST are in a different latency class entirely.
  If Parakeet matches turbo's WER on Brice's real voice, it wins outright
  (verbatim transcript + ~0.07 s per utterance + instant load).

## 2026-07-03 — **FINAL ASR choice: FluidAudio Parakeet v3** (real-voice confirmed)

Benchmark over **Brice's own 24 recorded utterances** (`bench/RESULTS.md`):

| Engine | Load | Warmup | Median latency | p90 | Mean WER | Content WER |
| --- | --- | --- | --- | --- | --- | --- |
| **Parakeet v3** | **0.14 s** | **0.10 s** | **0.072 s** | **0.075 s** | **13.6%** | 14.0% |
| Apple SpeechTranscriber | 0.07 s | 0.17 s | 0.080 s | 0.097 s | 18.6% | 18.0% |
| WhisperKit large-v3-turbo | 8.9 s | 1.6 s | 0.482 s | 0.504 s | 23.2% | 14.9% |
| WhisperKit base.en | 4.6 s | 0.6 s | 0.084 s | 0.093 s | 29.9% | 23.2% |

**Parakeet v3 wins accuracy AND latency on real voice**, consistent with the
synthetic run. It stays behind the `ASREngine` protocol; WhisperKit turbo is
the multilingual/alternate engine, Apple ST the zero-dependency fallback.

Corrections & notes:
- WhisperKit turbo's ~92 s warmup was **ANE cache population, not a permanent
  per-launch cost** — it settled to ~8.9 s load + 1.6 s warmup. Still ~100×
  slower to ready than Parakeet, and ~7× slower per utterance (0.48 s vs 0.07 s).
- Absolute WERs are inflated by scripted-reference drift (takes where Brice's
  actual words deviated from the suggestion he confirmed) and stutter collapse
  ("the uh the" → "the uh") — these hit all engines against the same refs, so
  the ranking stands.
- Parakeet mis-transcribed "Grafana" ("Grafani's") and "new hire" ("new hour")
  — exactly the Phase-3 personal-dictionary use case.

## 2026-07-03 — (superseded) provisional pick from synthetic data

Full 20-utterance **synthetic** benchmark (5 rotating `say` voices reading the
filler-heavy set — see `bench/SYNTH_RESULTS.md`):

| Engine | Warmup | Median latency | Mean WER | Mean content WER |
| --- | --- | --- | --- | --- |
| **Parakeet v3** | **0.08 s** | **0.071 s** | **11.7%** | **10.5%** |
| WhisperKit large-v3-turbo | 92 s (!) | 0.494 s | 13.8% | 12.0% |
| Apple SpeechTranscriber | 0.09 s | 0.078 s | 19.2% | 16.0% |
| WhisperKit base.en | 5.9 s | 0.082 s | 23.1% | 19.7% |

**Parakeet v3 wins on BOTH accuracy and latency**, with instant warmup.
WhisperKit turbo is second on accuracy but pays ~92 s ANE re-compilation every
process launch plus ~0.5 s per utterance. Apple ST is the zero-dependency
fallback (instant, but non-verbatim and mid accuracy).

Caveats: TTS voices ≠ Brice's voice; engines may collapse scripted stutters
("the the") differently, inflating absolute WER for all. **Final call requires
`bench run` over Brice's real recordings** — it only overturns this if Parakeet's
real-voice accuracy falls below WhisperKit turbo's.

## 2026-07-03 — cleanup hop measured: gemma3:4b ≈ 0.65 s, 1/20 meaning change

`bench cleanup` over the 20 reference transcripts (see `bench/SYNTH_CLEANUP.md`):

- **gemma3:4b: median 0.648 s, p90 0.670 s** (warm). 19/20 outputs
  meaning-preserving; sample 03 was a full rewrite ("can you send me the link
  to that doc" → "I think you can find that document here"). Phase 2 must get
  this to 0/20 — prompt hardening (e.g. "if unsure, return input verbatim"),
  smaller/other models, or an output-similarity guard.
- **gemma4:26b: median 6.8 s** — disqualified for the live loop, as plan.md
  predicted. Quirk: it returns EMPTY responses with the few-shot system prompt
  (works with a short one) — don't use it even for the quality-ceiling
  comparison without reworking the prompt format.
- **Provisional end-to-end budget:** ASR 0.07 s + cleanup 0.65 s ≈ **0.72 s**
  vs the 0.5 s target — the LLM hop is the bottleneck (plan.md §8 called it).
  Phase-2 levers: shorter prompt/fewer shots, streaming, ~1.5–2B model, MLX,
  skip cleanup on very short utterances.

## 2026-07-03 — field gotchas from Phase 1/2 live testing (Brice's machine)

- **Jamf-managed Macs profile-control the Input Monitoring pane** → switched the
  hotkey to NSEvent flagsChanged monitors, which need Accessibility only.
  Two permissions instead of three.
- **Fn as hotkey collides with macOS globe-key features** → default hotkey is
  now Left ⌥ (keyCode 58), with chord-cancel and a lost-release fallback.
- **Apple Voice Control was silently enabled** on the machine and typed
  everything continuously — looked exactly like "our app is always on".
  Diagnostic tell: System Settings → Keyboard → Dictation shows "Dictation is
  not available while Voice Control is enabled". Phase-3 onboarding should
  detect/warn about Voice Control + Apple Dictation.
- **Ad-hoc signing invalidates the Accessibility grant on every rebuild**
  (TCC keys on CDHash) → users must remove/re-add the app each build. Fix
  queued: stable self-signed signing identity.

## Open — speak2 end-to-end observations

speak2 built (CLT-only), launched, and was pre-configured for external Ollama;
full dictation demo waived by Brice at the Phase-0 review since every pipeline
stage was proven independently with original code.
