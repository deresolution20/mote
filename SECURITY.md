# Security & privacy posture

Mote is designed to run entirely on-device. This document is a factual
summary of what it does and does not do — useful for personal review or for a
security team evaluating it on a managed machine.

## Data handling

| Concern | Behavior |
| --- | --- |
| **Microphone audio** | Captured to an in-memory buffer only. Never written to disk by the app. Discarded after each utterance. |
| **Transcripts** | The most recent transcript is visible in the menu. History and Snippets are versioned JSON files under the user's Application Support directory and are not transmitted by Mote. |
| **Network** | The active dictation path does not send audio or transcripts to a remote service. No analytics, telemetry, crash-reporting service, accounts, or application-controlled transcript upload are implemented. |
| **Persistent storage** | Preferences, personal-dictionary terms, History, and Snippets stay local. History and Snippets use `Application Support/Mote`. The directory is owner-only (`0700`); its files are owner-only (`0600`) and excluded from device backup. They are not encrypted at rest. |
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
  when Mote still owns the pasteboard change. Newer user or application
  copies are never overwritten.

Automatic insertion is off for new installations. Existing saved preferences
are preserved. When enabled, Mote re-checks the intended focused app and
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
model artifacts. Turning approval off prevents future Mote-initiated model
loads/downloads; it does not delete artifacts already cached by those libraries.

## Build & distribution notes

- Mote 1.0 uses bundle identifier `dev.brice.mote`. macOS treats it as a new
  identity relative to pre-v1 development builds, so Microphone and
  Accessibility permission must be granted again. Known preferences are copied
  once from the former bundle domain, and legacy History/Snippet JSON files are
  copied only when no Mote file exists. Existing Mote data always wins and the
  legacy files remain intact.
- Local development builds use the Swift toolchain and may be signed with the
  self-signed `LocalFlow Dev` identity or ad-hoc signing. They are not
  notarized and are not distribution artifacts.
- `app/bundle.sh --release` requires a **Developer ID Application** identity,
  enables the hardened runtime, timestamps the signature, and runs strict
  `codesign` verification. It refuses to fall back to a development or ad-hoc
  identity.
- `app/release.sh` creates a zip suitable for notarization. Passing
  `--notarize` submits it with `xcrun notarytool`, staples and validates the
  ticket, and runs `spctl`; it requires a user-created `NOTARY_PROFILE` in the
  local Keychain. Credentials are never stored in this repository.
- No App Sandbox (system-wide text insertion is incompatible with sandboxing).
- `bundle.sh` fails closed if `mlx.metallib` is missing; it will not create a
  bundle that silently loses MLX cleanup.

Notarization and organizational allow-listing remain separate release-process
requirements. The first clean-machine run should still cover permissions,
model-download consent, model-download failure, focus switching, and clipboard
changes.

## Reporting

This is a personal project. Open an issue for security concerns.
