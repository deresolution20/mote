# Local Flow — decision log

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

## 2026-07-03 — PROVISIONAL ASR choice: Parakeet v3 (pending real-voice confirmation)

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

## Open — speak2 end-to-end observations

(to fill in after the reference build runs)
