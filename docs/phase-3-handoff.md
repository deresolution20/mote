# Local Flow — Phase 3 handoff

Snapshot for whoever (human or agent) picks this up next. The MVP (Phases 0–2)
is done and accepted; Phase 3 is partly built.

## Current state (2026-07-04)

**Working, verified on-device, fully offline:**
- Push-to-talk on **Left ⌥** (NSEvent flagsChanged, Accessibility-only — no
  Input Monitoring needed, which matters on MDM-managed Macs).
- Mic capture (AVAudioEngine, 16 kHz mono, in-memory only).
- ASR: **FluidAudio Parakeet v3** on the Neural Engine — chosen by benchmark
  over WhisperKit and Apple SpeechTranscriber (`bench/RESULTS.md`).
- Cleanup: **gemma3:4b via Ollama** (localhost), few-shot meaning-preserving
  prompt + protected-marker guard; raw transcript kept and pasteable.
- Insertion: **direct Unicode typing by default** (no clipboard), clipboard+⌘V
  as a fallback toggle.
- **Waveform HUD** (Phase 3): floating pill, recording→transcribing→cleaning→done.
- **Personal dictionary** (Phase 3): phonetic correction of custom vocab
  (Soundex + tight Levenshtein), common-word exemption.
- Menu toggles: AI cleanup, waveform overlay, insert-by-typing, model keep-alive.
- Signed with a stable self-signed **LocalFlow Dev** identity (Accessibility
  grant survives rebuilds). `app/bundle.sh` builds the signed `.app`.

## Architecture (one line each)

| File | Role |
| --- | --- |
| `AppState.swift` | Orchestrates the pipeline + state machine; owns all settings |
| `HotkeyMonitor.swift` | Left ⌥ push-to-talk via global NSEvent monitors |
| `AudioCapture.swift` | AVAudioEngine → 16 kHz mono Float32 in memory |
| `Transcriber.swift` | Parakeet v3 (FluidAudio) |
| `Cleaner.swift` | Ollama cleanup, prompt, plausibility guard, keep-alive |
| `PersonalDictionary.swift` | Phonetic custom-vocab correction |
| `TextInjector.swift` | Direct-type or clipboard insertion |
| `WaveformHUD.swift` | Floating status overlay |
| `Permissions.swift` | Mic + Accessibility checks / prompts |
| `MenuView.swift` / `OnboardingView.swift` | Menu-bar UI / setup window |

## Remaining Phase 3 work

1. **Streaming partial transcripts in the HUD** — show words live as spoken.
   Requires switching Parakeet to streaming/chunked transcription and pushing
   partials to the HUD model. Biggest visual payoff.
2. **Per-app context modes / style presets** — detect the frontmost app
   (`NSWorkspace.frontmostApplication`) and switch the cleanup prompt
   (formal / casual / email / code-comment). Keep the meaning-preserving guard.
3. **Injection compatibility pass** — verify direct-typing across secure fields
   and terminals; auto-fall-back to clipboard where typing is rejected.

Phase 4 (stretch, not planned): per-user style personalization.

## Copy-paste `/goal` for the next session

> Continue **Local Flow** (`github.com/deresolution20/local-flow`), a fully-local
> offline macOS dictation app. MVP (Phases 0–2) and two Phase-3 features (waveform
> HUD, personal dictionary) are done. Read `docs/phase-3-handoff.md` and
> `DECISIONS.md` first. Build the remaining Phase-3 features **one at a time,
> stopping for my review at each**: (1) streaming partial transcripts in the HUD;
> (2) per-app context modes / style presets; (3) an injection-compatibility pass.
> Guardrails (unchanged): fully local/offline in the dictation path; Ollama is
> cleanup-only, never ASR; always keep the raw transcript recoverable; preserve
> meaning (never change the user's words); keep the two-permission model (Mic +
> Accessibility); default to clipboard-free insertion; sign with the existing
> "LocalFlow Dev" identity so the Accessibility grant survives rebuilds; never
> commit my work email or `GOAL.md`; don't change repo visibility without asking.
