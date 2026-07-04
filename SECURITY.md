# Security & privacy posture

Local Flow is designed to run entirely on-device. This document is a factual
summary of what it does and does not do — useful for personal review or for a
security team evaluating it on a managed machine.

## Data handling

| Concern | Behavior |
| --- | --- |
| **Microphone audio** | Captured to an in-memory buffer only. Never written to disk by the app. Discarded after each utterance. |
| **Transcripts** | Held in memory (last one shown in the menu). Not logged, not written to disk, not transmitted anywhere. |
| **Network** | The dictation path makes **one** call: `POST http://localhost:11434` (local Ollama) for text cleanup. A hard-coded base URL prevents pointing it elsewhere. No analytics, no telemetry, no crash reporting, no accounts. |
| **Persistent storage** | Only user preferences in `UserDefaults`: feature toggles, model keep-alive minutes, and your personal-dictionary terms. No transcript history. |
| **Secrets** | None. No API keys, tokens, or credentials in the codebase or at runtime. |

## Permissions requested

| Permission | Why | Scope |
| --- | --- | --- |
| **Microphone** | Capture speech while the hotkey is held | Standard AVFoundation prompt |
| **Accessibility** | Detect the Left ⌥ hotkey (modifier-flag events) and insert text at the cursor | **Not** Input Monitoring — modifier events need only Accessibility |

The app does **not** request Input Monitoring, Screen Recording, Full Disk
Access, or network server entitlements.

## Text insertion & the clipboard

Two modes (menu-selectable):

- **Type directly (default)** — text is inserted as synthesized Unicode key
  events. **The clipboard is never touched.** Recommended on managed machines,
  where clipboard-history managers or DLP agents could otherwise capture
  dictated content.
- **Clipboard + ⌘V (fallback)** — briefly places text on the system clipboard,
  pastes, then restores the *complete* previous clipboard (all item types).
  Only use this if a specific app rejects synthetic typing.

## Setup-time network (outside the dictation path)

First-run setup reaches the network to download models — review these against
any egress policy:

- **ASR models** (Parakeet / WhisperKit) are downloaded from Hugging Face by the
  respective libraries on first use.
- **Cleanup model** is pulled by you via `ollama pull gemma3:4b`.

After setup, no model downloads occur and the runtime is fully offline.

## Build & distribution notes

- Built locally with the Swift toolchain; signed with a **self-signed**
  code-signing identity ("LocalFlow Dev"). It is **not notarized** and does not
  use the hardened runtime — it is intended for local/personal builds, not
  for redistribution. A managed environment may require notarization or an
  organizational signing identity before allowing it.
- No App Sandbox (system-wide text insertion is incompatible with sandboxing).

## Reporting

This is a personal project. Open an issue for security concerns.
