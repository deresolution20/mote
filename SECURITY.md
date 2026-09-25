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
| **Delivery compatibility memory** | Mote may remember one locally verified fallback using only the destination bundle identifier, app version, macOS version, Accessibility role, and delivery method. It does not store field contents, selected text, window titles, or control labels in this mapping. |
| **Secrets** | None. No API keys, tokens, or credentials in the codebase or at runtime. |

## Permissions requested

| Permission | Why | Scope |
| --- | --- | --- |
| **Microphone** | Capture speech while the hotkey is held | Standard AVFoundation prompt; the signed bundle carries only the `com.apple.security.device.audio-input` entitlement required for that prompt under the hardened runtime |
| **Accessibility** | Detect the Left ⌥ hotkey (modifier-flag events) and insert text at the cursor | **Not** Input Monitoring — modifier events need only Accessibility |

The app does **not** request Input Monitoring, Screen Recording, Full Disk
Access, or network server entitlements.

## Text delivery

Automatic insertion is off for new installations. When a user enables it,
Mote uses a capability-driven pipeline rather than a bundle-identifier list:

1. Capture the destination process, app version, window identity, focused
   Accessibility element, role/subrole, and selection-range capability when
   dictation begins. Observe application, window, and focused-element changes
   until delivery. If this focus lease cannot be observed, Mote fails closed.
2. Reject secure text fields. Mote does not automatically insert into a target
   carrying the macOS secure-text-field Accessibility subrole.
3. When the target exposes a settable selected-text attribute and readable
   selection range, attempt a direct Accessibility replacement and verify the
   expected caret movement.
4. Otherwise use the selected fallback mode. **Automatic** starts with a
   protected paste and may reuse a locally verified direct-event or paste
   method for the exact app/OS/role version tuple. **Privacy-first** uses Unicode
   events and never uses the clipboard automatically. **Compatibility** uses a
   protected paste.
5. Never try a second mechanism after a mutation might have occurred but could
   not be verified. The transcript remains pending and Mote warns that a manual
   retry could duplicate text.

Verification reads only the Accessibility selection range before and after an
attempt. Mote does not read the destination's text value or selected text.
Selection movement is evidence of insertion, not a byte-for-byte proof of the
target's contents; custom, remote, and policy-controlled editors can still
reject or transform input.

The protected paste fallback snapshots the complete prior pasteboard in memory,
replaces it with a `currentHostOnly` string, sends Command-V, and restores the
snapshot only while Mote still owns the pasteboard change count. A newer user or
application copy is never overwritten. The transient string is still visible
to local clipboard history, clipboard managers, DLP tools, and the destination
application. A user-initiated **Copy** is an ordinary persistent clipboard write
and is not automatically restored.

If focus changes, no editable target exists, the focus observer cannot be
installed, a secure field is detected, or delivery is unavailable, Mote keeps
the transcript in its recovery panel. There is no claim that macOS permits
programmatic insertion into every application or security context.

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
- Development and release signatures embed `app/Mote.entitlements`, whose only
  capability is microphone audio input. Without it, the hardened runtime causes
  macOS to deny the permission request before showing the user a prompt.
- `app/release.sh` creates a zip suitable for notarization. Passing
  `--notarize` submits it with `xcrun notarytool`, staples and validates the
  ticket, and runs `spctl`; it requires a user-created `NOTARY_PROFILE` in the
  local Keychain. Credentials are never stored in this repository.
- No App Sandbox (system-wide text insertion is incompatible with sandboxing).
- `bundle.sh` fails closed if `mlx.metallib` is missing; it will not create a
  bundle that silently loses MLX cleanup.

Notarization and organizational allow-listing remain separate release-process
requirements. The first clean-machine run should still cover permissions,
model-download consent, model-download failure, focus switching, secure fields,
clipboard ownership races, and representative native, Electron, Chromium,
terminal, remote-session, and managed-browser targets.

## Reporting

This is a personal project. Open an issue for security concerns.
