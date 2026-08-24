# Grotdown Security Hardening Design

**Date:** 2026-08-24
**Branch:** `codex/grotdown-security-hardening`
**Status:** Approved design — implementation complete

## Goal

Reduce the material privacy and integrity risks in Grotdown’s current local-support-tool workflow without deleting existing user content, weakening the core dictation flow, or claiming that external release controls have been completed.

## Scope

This pass changes five code-controlled boundaries:

1. New installations require review before insertion instead of automatically typing into another application.
2. Opted-in automatic insertion rechecks the focused editable target immediately before delivery and preserves the result for manual action if the target changed.
3. Clipboard fallback never restores an old clipboard snapshot over a clipboard that changed after Grotdown took ownership.
4. History and snippets receive owner-only filesystem permissions and are excluded from backups; existing files are hardened in place and never silently deleted.
5. Release bundling fails when its required MLX Metal runtime library is absent, and privacy/security documentation describes the actual implementation.

The pass also adds an explicit model-download consent gate. The application may not start either ASR or MLX model loading until the user has approved model acquisition in the onboarding/settings workflow. A cached model still requires that one-time consent because the application cannot reliably distinguish a cache hit from a download before calling the third-party loader.

## Out of Scope

- Developer ID certificates, hardened-runtime signing, notarization, MDM distribution, and App Store submission. These require Apple-account or organization authority.
- Cryptographic encryption of existing history/snippet JSON. Owner-only permissions, backup exclusion, retention controls, and deletion controls are deliverable now; Keychain-backed encryption is a separate migration project because it changes recovery, backup, and cross-signature behavior.
- Hash or revision verification of model artifacts. The current FluidAudio and MLX Hub APIs expose download behavior but do not provide the required app-level pinned-digest interface. This remains a release requirement documented in `SECURITY.md`.
- App Sandbox conversion. The current Accessibility-based focused-target inspection is incompatible with the normal sandbox path and needs an App Store-specific design.

## Decisions

### Safe delivery default

`GrotdownPreferences.autoInsert` defaults to `false` only when the key is absent. Existing users’ stored setting is preserved, so this security update does not silently change or delete prior user choices.

With automatic insertion disabled, `OutputDeliveryCoordinator.complete` returns a `PendingDictation`; the capture panel presents Insert and Copy. With automatic insertion enabled, the coordinator obtains the focused target twice. The first target is the intended target recorded in history; the second is a just-in-time confirmation. If either target is absent, existing copy fallback is used. If both are present but do not match, delivery returns `.notInserted`, the result stays pending, and no input event is posted.

The comparison includes the application and the focused editable Accessibility element. This materially narrows the transcription-to-delivery race but cannot make cross-process keyboard injection mathematically atomic; the manual default is the primary protection.

### Clipboard ownership

`TextInjector` captures the pasteboard change count immediately after it writes its own dictated text. Its delayed restore runs only if the pasteboard still has that exact change count. A user or another application can therefore replace the clipboard during the paste window without Grotdown overwriting it. Direct typing stays the default and clipboard mode remains visibly described as a compatibility fallback.

### Local-store hardening

`LocalStoreProtection` is a small Foundation-only helper used by both stores. Before reading or writing, it creates the Grotdown Application Support directory and sets mode `0700`. After every successful atomic write, it sets the JSON file mode to `0600` and marks the directory and file excluded from backup. On load, it applies the same protection to an existing file. Security failures surface through the stores’ existing `loadError` rather than causing data loss.

Existing History and Snippet clear actions remain the deletion control. The UI will explain that retained records are local, owner-only, and excluded from backups; it will not claim encryption at rest.

### Model-download consent

`GrotdownPreferences` adds `modelDownloadsApproved`, defaulting to `false`. App startup checks this before `Cleaner.warmUp`, `Transcriber.load`, and streaming warmup. If consent is missing, status becomes `needsModelDownloadApproval` and the app shows a setup view that explains that ASR and local Qwen artifacts are downloaded from their providers before all inference runs locally. The user can approve with a named action. Once approved, the setting is persisted locally and the existing pipeline begins.

This is consent and disclosure, not model-integrity verification. The security documentation will state that model artifact revision/hash validation remains a release gate.

### Bundle gate

`bundle.sh` must find and copy `mlx.metallib`; absence exits nonzero before it produces a distributable bundle. The script verifies that the copied resource exists after assembly. It continues to use the current local signing path for development, but marks Developer ID, hardened runtime, notarization, and Gatekeeper assessment as mandatory distribution requirements.

## Components and Interfaces

| Component | Change | Contract |
| --- | --- | --- |
| `GrotdownPreferences` | Add default-safe model download consent and make auto insertion default manual. | Missing persisted keys resolve to `false`; existing keys preserve their value. |
| `AppState` / onboarding | Represent model-download consent requirement, provide approval action, and block all model loading beforehand. | No call to `Cleaner.warmUp`, `Transcriber.load`, or streaming model warmup occurs until consent is true. |
| `OutputDeliveryCoordinator` | Confirm a target twice in auto mode; preserve a mismatch as pending. | Mismatch produces `.notInserted` and a non-nil pending result; no deliverer call. |
| `TextInjector` | Guard delayed clipboard restore by ownership change count. | A changed clipboard is never restored over. |
| `LocalStoreProtection` | Secure directory/files and exclude them from backups. | Directory mode `0700`; JSON mode `0600`; no content mutation beyond normal writes. |
| `HistoryStore` / `SnippetStore` | Invoke store protection for load/persist. | Existing data remains readable; protection errors are reported. |
| `bundle.sh` | Require the MLX Metal runtime resource. | Build fails if `mlx.metallib` cannot be embedded. |
| docs/report | Replace stale Ollama/no-history claims and publish residual risk. | Documentation matches current behavior and names unresolved external controls. |

## Error Handling

- If a target changes, retain the pending result and show manual Insert/Copy rather than typing or copying automatically.
- If local-store hardening fails, do not overwrite the affected file; use the existing visible store error state.
- If model-download consent is missing, do not make a network-capable model-loader call. Guide the user to explicitly approve it.
- If the MLX resource is absent, fail the release bundle. Development `swift test` remains independent of release assembly.

## Testing

Add test-first coverage for:

- safe defaults and persisted model-download consent;
- automatic-delivery target mismatch leaves a pending result and makes no delivery call;
- auto-delivery target stability still delivers;
- clipboard restoration policy only restores when its ownership change count remains current;
- store protection sets owner-only permissions in a temporary directory;
- startup model-load gating is represented in pure/presentation state where feasible;
- shell-level bundle test that asserts a missing Metal library fails instead of emitting an app.

Run the full Swift suite, documentation tests, bundle success path, bundle missing-resource failure path, signing inspection, and `git diff --check` after implementation.

## Acceptance Criteria

1. A fresh preferences store has `autoInsert == false` and `modelDownloadsApproved == false`.
2. Existing stored auto-insert and model-download-consent settings round-trip unchanged.
3. An automatic delivery with mismatched target snapshots does not emit keyboard or pasteboard delivery and leaves a pending dictation.
4. A delayed clipboard restore cannot overwrite an independently changed clipboard.
5. History and snippets remain available and their storage files are owner-only, backup-excluded after load or write.
6. The application makes no model-loader call before explicit model-download approval.
7. `bundle.sh` exits nonzero when `mlx.metallib` cannot be embedded and produces a bundle containing it when available.
8. `SECURITY.md`, README, and the final HTML report distinguish completed hardening from unresolved release/Apple controls.
