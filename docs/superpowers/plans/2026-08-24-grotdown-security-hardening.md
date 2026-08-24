# Grotdown Security Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task by task.

**Goal:** Eliminate the confirmed in-app privacy and safety issues without deleting existing user data or changing the product's local-only operating model.

**Architecture:** Add a persisted, explicit consent boundary before any model loader is called; make automatic text delivery retain a manual action when focus changes; and centralize private-store protection and clipboard ownership checks in small, testable helpers. Fail packaging when the Metal resource is absent rather than silently shipping degraded cleanup behavior.

**Tech Stack:** Swift 6 / SwiftUI / AppKit, Swift Package Manager, Bash, XCTest.

**Spec:** `docs/superpowers/specs/2026-08-24-grotdown-security-hardening-design.md`

## Global constraints

- Preserve existing history and snippets; do not delete, migrate destructively, or add encryption.
- New installations must default to manual insertion and must ask before downloading models. Existing persisted automatic-insertion preferences remain intact.
- No model load or warm-up may occur until the user has explicitly approved model downloads.
- Keep the app local-only: no telemetry, cloud transcription, or remote transcript upload.
- Do not claim Developer ID signing or notarization; those require Apple credentials and a separate release process.

---

### Task 1: Secure defaults and model-download consent

**Files:**
- Modify: `app/Sources/LocalFlow/App/AppPreferences.swift`
- Modify: `app/Sources/LocalFlow/App/AppState.swift`
- Modify: `app/Sources/LocalFlow/App/Status.swift`
- Test: `app/Tests/LocalFlowTests/AppPreferencesTests.swift`
- Test: `app/Tests/LocalFlowTests/AppStateTests.swift`

1. Write failing preference tests establishing that a missing `autoInsert` key defaults to `false`, a missing model-download key defaults to `false`, and explicitly saved legacy values still round-trip.
2. Run `cd app && swift test --filter AppPreferencesTests`; confirm the new tests fail for the intended reasons.
3. Add `modelDownloadsApproved` persistence and make only an absent `autoInsert` key resolve to `false`.
4. Add `Status.needsModelDownloadApproval`, display label and symbol support, and an `AppState.approveModelDownloadsAndStartPipeline()` action.
5. Gate `startPipeline`, cleanup warm-up, and streaming warm-up so no `Cleaner` or transcription model loader runs before consent. Move state to the new status and show onboarding instead.
6. Run `cd app && swift test --filter 'AppPreferencesTests|AppStateTests'`.

### Task 2: Protect automatic output delivery from target changes

**Files:**
- Modify: `app/Sources/LocalFlow/Services/OutputDeliveryCoordinator.swift`
- Test: `app/Tests/LocalFlowTests/OutputDeliveryCoordinatorTests.swift`

1. Add a failing coordinator test whose focus inspector reports one application at capture time and a different application immediately before delivery. Assert the text deliverer is not called and the result is retained as pending.
2. Run `cd app && swift test --filter OutputDeliveryCoordinatorTests`; confirm failure.
3. In automatic direct-insert mode, capture the intended target, re-check it immediately before injection, and return a pending manual result when it differs. Preserve the current clipboard fallback when there is no focused target.
4. Run `cd app && swift test --filter OutputDeliveryCoordinatorTests`.

### Task 3: Do not overwrite a newer clipboard value

**Files:**
- Modify: `app/Sources/LocalFlow/Services/TextInjector.swift`
- Test: `app/Tests/LocalFlowTests/TextInjectorTests.swift`

1. Add failing pure-policy tests for restoring the pasteboard only when its change count still equals the value set by Grotdown.
2. Run `cd app && swift test --filter TextInjectorTests`; confirm failure.
3. Add an internal clipboard restoration policy and capture the post-write pasteboard change count. Restore the previous pasteboard only when Grotdown still owns that change count.
4. Run `cd app && swift test --filter TextInjectorTests`.

### Task 4: Harden local history and snippets at rest

**Files:**
- Add: `app/Sources/LocalFlow/Stores/LocalStoreProtection.swift`
- Modify: `app/Sources/LocalFlow/Stores/HistoryStore.swift`
- Modify: `app/Sources/LocalFlow/Stores/SnippetStore.swift`
- Test: `app/Tests/LocalFlowTests/HistoryStoreTests.swift`
- Test: `app/Tests/LocalFlowTests/SnippetStoreTests.swift`

1. Add failing tests that persist each store into a temporary directory and assert `0700` directory permissions and `0600` file permissions.
2. Run the two store test suites and confirm failure.
3. Add one helper that creates/protects the parent directory, excludes it and its files from device backup, and applies owner-only POSIX permissions. Call it both while loading existing data and after atomic persistence.
4. Surface a non-destructive error if protection fails; never clear existing store values as recovery.
5. Run `cd app && swift test --filter 'HistoryStoreTests|SnippetStoreTests'`.

### Task 5: Make the consent and safe fallback visible in the GUI

**Files:**
- Modify: `app/Sources/LocalFlow/Views/OnboardingView.swift`
- Modify: `app/Sources/LocalFlow/Views/GrotdownSettingsView.swift`
- Modify: `app/Sources/LocalFlow/Views/CapturePanelView.swift`
- Modify: `app/Sources/LocalFlow/Views/MenuView.swift`
- Test: relevant existing snapshot/model tests in `app/Tests/LocalFlowTests/`

1. Update onboarding to explain that the first use downloads local transcription and cleanup models, and offer a clear approval-and-start action only after required permissions are granted.
2. Add a settings control that records or withdraws download consent without deleting already-downloaded model artifacts. Document that history/snippets are local, owner-only, backup-excluded, and not encrypted.
3. Map the new status in the menu/capture views. Ensure a pending dictation is always visible when automatic insertion declined to inject it, regardless of the insertion preference.
4. Add or update view-model/snapshot tests for the consent state and pending manual result.
5. Run the related view test filters, then `cd app && swift test`.

### Task 6: Make the packaging failure explicit

**Files:**
- Modify: `app/bundle.sh`
- Add: `app/test-bundle-security.sh`

1. Add a shell test that exercises the Metal-library selection logic against an empty temporary build tree and expects failure.
2. Run `cd app && ./test-bundle-security.sh`; confirm failure.
3. Change `bundle.sh` to exit non-zero with a clear error when no `mlx.metallib` candidate exists; after copying, verify the resource is present in the bundle.
4. Run `cd app && ./test-bundle-security.sh`, then `cd app && ./bundle.sh` when the local build contains the resource.

### Task 7: Update user-facing security documentation and write the HTML report

**Files:**
- Modify: `SECURITY.md`
- Modify: `README.md`
- Add: `/Users/brice/Documents/ChatGPT/Grotdown/grotdown-security-hardening-report-2026-08-24.html`

1. Replace stale Ollama/Gemma claims with the actual Qwen 2.5 1.5B MLX cleanup model and the consent-based local model-download boundary.
2. Document storage protection accurately, including the deliberate residual risk that history/snippets are not encrypted at rest.
3. Write a self-contained HTML report listing remediated findings, validation evidence, and residual distribution/supply-chain issues requiring Apple credentials or upstream support.
4. Run `git diff --check`, the complete Swift test suite, `cd app && ./test-bundle-security.sh`, and inspect the report locally before handoff.
