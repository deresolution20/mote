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

## Open — ASR engine choice (Phase 0 exit criterion)

To be decided from the benchmark over Brice's own filler-heavy dictation
samples: WhisperKit `large-v3-turbo` vs Apple `SpeechTranscriber` vs FluidAudio
Parakeet v3. Accuracy on this test set first, then latency.

## Open — speak2 end-to-end observations

(to fill in after the reference build runs)
