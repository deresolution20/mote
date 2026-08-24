# Security & privacy posture

Grotdown is designed to run entirely on-device. This document is a factual
summary of what it does and does not do — useful for personal review or for a
security team evaluating it on a managed machine.

## Data handling

| Concern | Behavior |
| --- | --- |
| **Microphone audio** | Captured to an in-memory buffer only. Never written to disk by the app. Discarded after each utterance. |
| **Transcripts** | The most recent transcript is visible in the menu. History and Snippets are versioned JSON files under the user's Application Support directory and are not transmitted by Grotdown. |
| **Network** | The active dictation path does not send audio or transcripts to a remote service. No analytics, telemetry, crash-reporting service, accounts, or application-controlled transcript upload are implemented. |
| **Persistent storage** | Preferences, personal-dictionary terms, History, and Snippets stay local. The History/Snippets directory is owner-only (`0700`); its files are owner-only (`0600`) and excluded from device backup. They are not encrypted at rest. |
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
  pastes, then restores the *complete* previous clipboard (all item types) only
  when Grotdown still owns the pasteboard change. Newer user or application
  copies are never overwritten.

Automatic insertion is off for new installations. Existing saved preferences
are preserved. When enabled, Grotdown re-checks the intended focused app and
editable Accessibility element before inserting; a changed target leaves text
pending for a manual copy or insert.

## Setup-time network (outside the dictation path)

First-run setup may reach the network to download models. It requires explicit
user approval in the onboarding or Model settings screen; review this against
any egress policy:

- **ASR models** are downloaded by FluidAudio's local Parakeet support.
- **Cleanup model** is `mlx-community/Qwen2.5-1.5B-Instruct-4bit`, loaded by
  the local MLX/Hugging Face support libraries.

The app does not independently verify a publisher-pinned digest for cached
model artifacts. Turning approval off prevents future Grotdown-initiated model
loads/downloads; it does not delete artifacts already cached by those libraries.

## Build & distribution notes

- Built locally with the Swift toolchain; signed with a **self-signed**
  code-signing identity ("LocalFlow Dev"). It is **not notarized** and does not
  use the hardened runtime — it is intended for local/personal builds, not
  for redistribution. A managed environment may require notarization or an
  organizational signing identity before allowing it.
- No App Sandbox (system-wide text insertion is incompatible with sandboxing).
- `bundle.sh` fails closed if `mlx.metallib` is missing; it will not create a
  bundle that silently loses MLX cleanup.

Apple Developer ID signing, hardened runtime, notarization, and organizational
allow-listing remain separate release-process requirements.

## Reporting

This is a personal project. Open an issue for security concerns.
