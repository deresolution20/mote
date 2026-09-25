# Local Flow — a fully-local, offline Wispr Flow clone for macOS

> **Working name:** `local-flow` (rename freely).
> **Status:** Historical PRD. MVP Phases 0-2 are complete, Phase 3 is in
> progress, and Swift-native MLX cleanup is now the accepted default after the
> 2026-07-08 Task 14 acceptance run and manual review. For current runtime state,
> see `README.md`, `DECISIONS.md`, and `docs/phase-3-handoff.md`.
> **Author of plan:** synthesized from a fact-checked deep-research pass (23 sources fetched, 104 claims extracted, 25 adversarially verified with 3-vote panels). Citations at the end. Where a claim was *refuted* in verification, it is flagged so you don't design around it.

---

## Current implementation note

This document preserves the original product requirements and research
rationale. Several implementation decisions have since changed based on local
benchmarks and live acceptance:

- ASR default is FluidAudio Parakeet v3, not WhisperKit turbo.
- Cleanup is Swift-native MLX
  `mlx-community/Qwen2.5-1.5B-Instruct-4bit` only. Ollama was removed from the
  active app path after Task 14 acceptance; historical Ollama notes below remain
  as original PRD context and benchmark evidence.
- Text insertion defaults to direct Unicode typing; clipboard paste remains a
  compatibility fallback.
- The app uses two permissions: Microphone and Accessibility.
- `speak2` is reference-only because its license status was refuted.

## 1. Objective

Build a **native macOS app (Swift/SwiftUI)** that reproduces the *core* Wispr Flow experience **entirely on-device, offline**:

> Press/hold a global hotkey → speak → the app captures mic audio → transcribes it locally → a **local LLM (via Ollama) cleans it up** (removes filler like "um/uh", fixes grammar, punctuation, capitalization, formatting — **without changing meaning**) → the polished text is auto-inserted at the current cursor position in whatever app is focused.

Low latency is the defining quality bar — it must feel real-time.

### Non-goals (explicitly out of scope for the MVP)
- No cloud anything. No network dependency at runtime.
- No account system, sync, or telemetry.
- No per-user *fine-tuned* style model (Wispr's real moat — see §11 Phase 4). Style **presets** are in scope; fine-tuning is not.
- Not aiming to beat top-tier cloud ASR accuracy (see §9, refuted claims).

---

## 2. Two findings that shape the entire design (read before coding)

**A. Wispr Flow is a CLOUD app — you cannot copy its architecture.** Both its ASR and its Llama-based "flow" cleanup run in the cloud (Baseten/AWS); it refuses to transcribe offline. So there's no on-device design to reverse-engineer — we assemble a local ASR + local LLM pipeline ourselves. Upside: **fully-private/offline dictation is something Wispr does *not* offer.** [S1][S2]

**B. Ollama CANNOT do speech-to-text — it is the *cleanup* brain only.** Definitively verified: Ollama has no Whisper/ASR support (issue #4168 closed within hours as a dupe of #1168, still open/unfulfilled; the `whisper` model on ollama.com is a mislabeled *text* LLM). Every real "ollama voice" project runs Whisper **externally** and pipes text in. [S3][S4]

So the mental model is:

| Wispr's cloud component | Our local equivalent |
| --- | --- |
| Cloud ASR (the "hearing") | **Dedicated on-device ASR engine** (WhisperKit / Apple Speech / Parakeet) |
| Cloud fine-tuned Llama (the "flow" cleanup) | **Ollama** running a small local model ← *this is the Ollama part* |

**Re-verify B before finalizing** — the field moves fast (llama.cpp gained *Gemma-only, non-Whisper* audio input in 2026; an Ollama realtime-voice FR opened 2026-04). As of this plan, Ollama for ASR is a firm **no**.

---

## 3. Target environment (confirmed on this machine)

- **OS:** macOS 26.5.2 (Tahoe), build 25F84, Apple Silicon.
- **Toolchain:** Swift 6.3.2, target `arm64-apple-macosx26.0`, full Xcode toolchain present.
- **Consequence:** Apple's on-device `SpeechAnalyzer` / `SpeechTranscriber` (macOS 26+) **is available** and usable as a zero-dependency ASR option.
- **Ollama:** installed at `/opt/homebrew/bin/ollama`. Only local model today is `gemma4:26b` (17 GB) — **too heavy for the real-time budget; do not default to it.** Pull a small instruct model (~2–4B) for cleanup (see §5).

---

## 4. Architecture

```
[Global hotkey / push-to-talk]        ← CGEvent tap (Input Monitoring)
        │
        ▼
[Mic capture]                         ← AVAudioEngine, 16 kHz mono Float32 (Microphone perm)
        │
        ▼
[VAD / endpointing]                   ← detect end-of-speech
        │
        ▼
[ASR engine]  (protocol-abstracted)   ← default WhisperKit large-v3-turbo (Core ML / ANE)
        │  raw transcript                 alternates: Apple SpeechTranscriber, FluidAudio Parakeet
        ▼
[Cleanup LLM]  (toggleable)           ← Ollama HTTP → small 2–4B instruct model
        │  polished text                  keep RAW as fallback
        ▼
[Text injection]                      ← save clipboard → set text → synth ⌘V → restore (Accessibility perm)
        │
        ▼
   cursor, in any focused app
```

Keep every stage behind a protocol/interface so engines are swappable (the reference app `speak2` already does this for ASR + LLM).

---

## 5. Tech-stack decisions (with rationale)

### ASR — default **WhisperKit `large-v3-turbo`**, abstracted behind an `ASREngine` protocol
- MIT-licensed Swift package; runs Whisper via **Core ML on the Neural Engine**; streaming partials; auto-downloads model (~626 MB). Best accuracy/latency/ecosystem balance and what `speak2`/`vocamac` use. [S5][S8]
- **Alternate 1 — Apple `SpeechTranscriber` (macOS 26):** zero dependency, no model download, on-device; matches *mid-tier* Whisper accuracy (not top-tier). Best lowest-friction first cut / fallback. [S6]
- **Alternate 2 — FluidAudio Parakeet TDT:** fastest class tested (~0.19 s/clip, ~6× faster than whisper.cpp on M4), but English-biased and benchmarked speed-only. Use if latency is the binding constraint. [S7]
- **Decision rule:** pick the engine in **Phase 0 from your own benchmark** (§8), not from the public numbers.

### Cleanup LLM — **Ollama**, small **2–4B instruct** model
- Start with a 3–4B instruct model for precision; drop to ~1.5B if latency hurts. `speak2` proves `gemma3:4b` over Ollama works for exactly this. [S10]
- **Do not use `gemma4:26b`** for the live loop (too slow for the budget) except as a quality-ceiling comparison. Pull a small model: `ollama pull <small-2-4B-instruct>`.
- **MLX is a faster local path** on Apple Silicon (speak2 offers Qwen 2.5 1.5B via MLX Swift). Ollama is the default per requirement; MLX is a documented Phase-2 optimization if the Ollama HTTP hop is too slow.
- **Prompting is the risk, not the plumbing** (see §9). Constrain hard, low temperature, meaning-preserving, keep raw transcript recoverable.

### Text injection — **clipboard + synthesized ⌘V** (save → set → paste → restore)
- What all three reference apps chose; most universally reliable. [S8][S9][S10]
- Keep **Accessibility API (AXUIElement)** / CGEvent keystrokes as a fallback for apps that block synthetic paste (secure fields, some terminals).

### Permissions
- **Microphone** (AVFoundation), **Accessibility** (synthetic paste/keystrokes), **Input Monitoring** (global hotkey). Copy the request/onboarding flow from `speak2`'s `Info.plist`/entitlements.

---

## 6. Reference implementations — **fork `speak2`**

| Project | License | Why it matters |
| --- | --- | --- |
| **[`speak2`](https://github.com/zachswift615/speak2)** | **MIT** | **Fork this.** Implements the *entire* target pipeline incl. Ollama cleanup: switchable WhisperKit/Parakeet ASR, AVAudioEngine 16 kHz capture, CGEvent-tap hotkey, clipboard+⌘V injection, optional LLM refine via MLX **or external Ollama**. `DictationController` orchestrates record→stream→transcribe→refine→paste. License-clean to build on. [S10] |
| [VoiceInk](https://github.com/Beingpax/VoiceInk) | GPL v3 | Most mature (~4,300★). **Read for Phase-3 features** (app/URL context awareness, personal dictionary). GPL — don't copy code into a proprietary build. [S8] |
| [vocamac](https://github.com/jatinkrmalik/vocamac) | AGPL-3.0 | Clean WhisperKit blueprint, bundles a Tiny model. Early alpha; reference only. [S9] |

**Licensing matters** if this ever becomes a product for the consulting business: `speak2` (MIT) is the only clean base; VoiceInk/vocamac are copyleft — study, don't lift.

---

## 7. Milestones (the executable spine)

Each phase has a concrete deliverable and **testable acceptance criteria**. The MVP "done" line is **end of Phase 2**.

### Phase 0 — De-risk & baseline
- **Do:** Fork `speak2`; build & run it in Xcode on this Mac; point its cleanup at local Ollama. Write a small **ASR benchmark** over *your own* short, filler-heavy dictation samples (not long-form): WhisperKit-turbo vs Apple `SpeechTranscriber` vs Parakeet — measure **latency and word-error-rate**.
- **Accept:** you can dictate one sentence end-to-end through forked `speak2`; a benchmark table exists; ASR engine chosen **with data**.

### Phase 1 — Walking skeleton (no LLM yet)
- **Do:** Minimal own app (or trimmed fork): push-to-talk global hotkey → AVAudioEngine 16 kHz capture → chosen ASR → clipboard+⌘V paste of the **raw** transcript. Menu-bar shell. In-app permission-request flow for all three perms.
- **Accept:** press hotkey → speak → raw text lands at the cursor in TextEdit, a browser, and a chat app; all 3 permissions grantable from the app; short-utterance latency feels ~instant (< ~1 s).

### Phase 2 — Ollama cleanup  ← **MVP done here**
- **Do:** transcript → local Ollama HTTP (small model) → cleaned text → paste. Tune the cleanup prompt (filler removal + punctuation/caps + light formatting), **meaning-preserving, low temperature**. Add a raw⇄cleaned **toggle**; keep raw as fallback.
- **Accept:** e.g. `"um so like i think we should uh ship it friday"` → `"I think we should ship it Friday."` across a **20-utterance test set with zero meaning changes**; toggle works; added latency measured and within budget (or model downsized to hit it).

### Phase 3 — Toward Wispr parity (polish)
- **Do:** streaming ASR partials + live overlay HUD; personal dictionary / custom vocab (e.g. "Grafana", "Zendesk"); per-app context modes; style presets (Formal / Casual / Email / Code-comment).
- **Accept:** live text appears while speaking; custom terms transcribe correctly; switching focused app changes mode; presets visibly change register.

### Phase 4 — Stretch (not MVP)
- Per-user **style personalization** (Wispr's differentiator; even Wispr calls precision "an open problem" [S2]). Document as future work; do not block MVP on it.

---

## 8. Performance targets & latency budget

- Wispr's stated budget: **~700 ms** end-to-end (≤200 ms ASR + ≤200 ms LLM + ≤200 ms network). [S1][S2]
- Removing the network hop implies a **~500 ms on-device target** — *this is inferred arithmetic, not a measured local figure.* Treat it as the design goal, and **measure the real loop** (VAD + streaming ASR + full-utterance LLM rewrite + paste) early. The **LLM rewrite is the likely bottleneck**.
- Mitigations if over budget: smaller cleanup model, streaming/partial output, skip cleanup on very short utterances, or switch Ollama→MLX for the cleanup hop.

---

## 9. Risks & mitigations

1. **On-device ASR won't match top-tier cloud accuracy.** Three attractive claims about WhisperKit hitting cloud-parity WER/latency, and Parakeet's ~110× RTF, were **REFUTED** in verification — do **not** design around parity. Set your own bar via the Phase-0 benchmark. [S5][S7]
2. **LLM cleanup is the biggest latency *and* quality risk.** A small model may **change meaning or hallucinate** while "cleaning up" — no source resolved a safe prompting recipe. Constrain the prompt, low temp, keep raw recoverable, test on a fixed utterance set every change.
3. **Text-injection reliability** varies (secure fields, terminals, paste-blockers). Keep the AX/keystroke fallback.
4. **Permissions friction** (Accessibility especially) — invest in a clear onboarding flow; borrow from `speak2`.
5. **Fast-moving field** — re-verify Ollama's audio/ASR status and WhisperKit's package location (folded into `argmaxinc/argmax-oss-swift`, 2026-05) before pinning deps.

---

## 10. Open questions to resolve in Phase 0
- Measured **end-to-end on-device latency** of the full loop on this Mac (no source measured it).
- **WER trade-off** Parakeet-on-ANE vs Whisper on *real dictation* audio (short, spontaneous, filler-heavy) — Parakeet is English-biased vs multilingual Whisper.
- Smallest cleanup model that's **precise enough**: does ~1.5B suffice or is 3–4B needed?
- **Injection method** per app class: clipboard+⌘V vs AX vs synthesized keystrokes — which is most reliable where?

---

## 11. Guardrails for the executor
- **Fully local/offline at runtime.** No network calls in the dictation path.
- **Ollama = cleanup only**, never ASR.
- Base new code on **`speak2` (MIT)**; treat VoiceInk/vocamac as read-only references (copyleft).
- **Benchmark before committing** to an ASR engine (Phase 0).
- **Keep the raw transcript** as a fallback whenever the LLM step is on.
- **Do not create a public git repo or change repo visibility without explicitly asking** (org policy). Default to a local repo / private if asked.

---

## 12. References (verified sources)
- **[S1]** Wispr Flow engineering — technical challenges: https://wisprflow.ai/post/technical-challenges
- **[S2]** Baseten customer case study (Wispr Flow, cloud Llama cleanup): https://www.baseten.co/resources/customers/wispr-flow/
- **[S3]** Ollama issue #4168 (whisper support, closed as dupe): https://github.com/ollama/ollama/issues/4168
- **[S4]** Ollama issue #1168 (WhisperForConditionalGeneration, still open): https://github.com/ollama/ollama/issues/1168
- **[S5]** WhisperKit (Argmax, MIT): https://github.com/argmaxinc/WhisperKit
- **[S6]** Apple + Argmax on-device SpeechTranscriber benchmark: https://www.argmaxinc.com/blog/apple-and-argmax
- **[S7]** Mac ASR speed benchmark (Parakeet/Whisper family): https://github.com/anvanvan/mac-whisper-speedtest
- **[S8]** VoiceInk (GPL v3): https://github.com/Beingpax/VoiceInk
- **[S9]** vocamac (AGPL-3.0): https://github.com/jatinkrmalik/vocamac
- **[S10]** speak2 (MIT — recommended fork): https://github.com/zachswift615/speak2

_Refuted-in-verification (do NOT rely on): WhisperKit ~2% WER matching cloud ASR; WhisperKit ~0.45 s latency competitive with fastest cloud; FluidAudio Parakeet ~110× RTF on M4 Pro._
