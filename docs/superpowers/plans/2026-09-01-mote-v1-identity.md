# Mote v1 identity and release plan

Goal: ship a notarized Mote 1.0.0 build with a coherent internal identity and safe migration from the pre-v1 Grotdown/LocalFlow development identity. Out of scope: renaming the GitHub repository, rewriting historical evidence, or replacing the Developer ID certificate.
Architecture: Rename the active Swift package graph and bundle to Mote, then isolate former identity strings in one migration component. Copy preferences and local JSON stores forward without overwriting new data, generate the MLX Metal library, and pass the existing fail-closed signing/notarization pipeline.
Tech stack: Swift 6.3/SwiftUI, Swift Testing, zsh packaging, MLX Swift Metal kernels, Apple codesign/notarytool/stapler/spctl.
Spec: `docs/superpowers/specs/2026-09-01-mote-v1-identity.md`.
Global constraints: Bundle identifier is exactly `dev.brice.mote`. Public version is exactly `1.0.0`. Existing Mote values always win over legacy values. Credentials remain in Keychain and never enter the repository or chat. Do not commit without explicit user approval.

## File structure

- `app/Package.swift`: Mote package, module, executable, auxiliary executable, and test target definitions.
- `app/Sources/Mote/`: primary application module and Mote-named UI/support/persistence types.
- `app/Sources/MoteCleanup/`: cleanup library module.
- `app/Sources/MoteCleanupAcceptance/`, `app/Sources/MoteStreamingBenchmark/`: auxiliary executable sources.
- `app/Sources/Mote/Migration/MoteV1Migration.swift`: the only active production source allowed to know legacy bundle IDs, keys, and storage names.
- `app/Tests/MoteTests/`: renamed test target, including migration behavior.
- `app/test-product-identity.sh`: executable guard against stale active product/module identity.
- `app/bundle.sh`, `app/release.sh`, `app/Scripts/signing.sh`, `app/Scripts/notarization.sh`: Mote bundle/executable/version/identifier and release pipeline, including post-staple repackaging.
- `bench/Sources/MLXSpikeSupport/MLXMetallibPreparation.swift`: existing deterministic metallib generator used unchanged unless a reproduced failure requires a fix.
- `README.md`, `SECURITY.md`, `DECISIONS.md`, `docs/mote-formatting-commands.md`: current Mote documentation.
- `docs/phase-3-handoff.md`, `docs/reports/mlx-cleanup-benchmark/README.md`: explicit former-name boundary around historical evidence.

### Task 1: Identity guard and Swift package refactor

**Files:** Create: `app/test-product-identity.sh` / Modify: `app/Package.swift`, active files under `app/Sources`, `app/Tests`, `app/bundle.sh`, `app/release.sh`, `app/Scripts/signing.sh` / Rename: active `LocalFlow*` and `Grotdown*` source/test paths to `Mote*`
**Interfaces:** Consumes: current Swift package graph / Produces: modules `Mote` and `MoteCleanup`, executables `Mote`, `mote-cleanup-acceptance`, and `mote-streaming-benchmark`

- [x] **Step 1: Write the failing identity guard** — create an executable shell test that requires `name: "Mote"`, `name: "MoteCleanup"`, `name: "MoteTests"`, `dev.brice.mote`, `CFBundleExecutable` = `Mote`, version `1.0.0`, and no `LocalFlow`, `Grotdown`, or `grotdown` in active Swift files except `Migration/MoteV1Migration.swift`.
- [x] **Step 2: Run it** — `zsh app/test-product-identity.sh`; expected: FAIL because the package and bundle still expose LocalFlow and legacy identifiers.
- [x] **Step 3: Minimal implementation** — rename the package targets/directories/imports, app entry point, current Grotdown-named types/files/tests, current error domains and temp-suite labels; update the bundle executable, identifier, and version.
- [x] **Step 4: Run tests** — `cd app && swift test`, `zsh app/test-product-identity.sh`, and `zsh app/test-bundle-security.sh`; expected: PASS.
- [ ] **Step 5: Commit** — deferred pending explicit user approval; proposed message: `refactor: adopt Mote v1 identity`.

### Task 2: Preference and local-store migration

**Files:** Create: `app/Sources/Mote/Migration/MoteV1Migration.swift` / Modify: `app/Sources/Mote/Stores/MotePreferences.swift`, `HistoryStore.swift`, `SnippetStore.swift` / Test: `app/Tests/MoteTests/MotePreferencesTests.swift`, `HistoryStoreTests.swift`, `SnippetStoreTests.swift`
**Interfaces:** Consumes: legacy `dev.brice.localflow`, `grotdown.*`, and `Application Support/Grotdown` / Produces: `MoteV1Migration.migratePreferences(current:legacy:)` and `copyLegacyFileIfNeeded(from:to:fileManager:)`

- [x] **Step 1: Write the failing tests** — add preference coverage equivalent to:

  ```swift
  legacy.set(true, forKey: "grotdown.autoInsert")
  let preferences = MotePreferences(defaults: current, legacyDefaults: legacy)
  #expect(preferences.autoInsert)
  #expect(current.bool(forKey: "mote.autoInsert"))
  ```

  Add a precedence case with `current.set(false, forKey: "mote.autoInsert")`, and a marker case that removes the current value after the first migration and expects legacy data not to return. Add history/snippet cases that write a valid legacy store, construct the new store with both URLs, and expect the legacy records in the new file; add existing-destination cases that expect current Mote data to win.
- [x] **Step 2: Run them** — `cd app && swift test --filter 'MotePreferencesTests|HistoryStoreTests|SnippetStoreTests'`; expected: FAIL because the migration interface does not exist.
- [x] **Step 3: Minimal implementation** — copy each known legacy preference only when its Mote key is absent, set a one-time marker, copy each legacy JSON file only when its destination is absent, leave legacy files intact, and run the existing file protection after copying.
- [x] **Step 4: Run tests** — rerun the focused tests, then `cd app && swift test`; expected: PASS.
- [ ] **Step 5: Commit** — deferred pending explicit user approval; proposed message: `feat: migrate pre-v1 Mote user data`.

### Task 3: Public docs and artifact identity

**Files:** Modify: `README.md`, `SECURITY.md`, `DECISIONS.md`, `docs/reports/mlx-cleanup-benchmark/README.md`, `docs/phase-3-handoff.md` / Rename: `docs/grotdown-formatting-commands.md` to `docs/mote-formatting-commands.md`
**Interfaces:** Consumes: Mote package/release commands from Tasks 1-2 / Produces: active documentation for `Mote.app`, `Mote-notary`, and Mote module/build commands

- [x] **Step 1: Write the failing audit** — extend `app/test-product-identity.sh` to check current docs and require the Mote formatting-guide path while permitting former names only in explicitly historical documents.
- [x] **Step 2: Run it** — `zsh app/test-product-identity.sh`; expected: FAIL on stale current docs/path.
- [x] **Step 3: Minimal implementation** — update current product wording and commands, rename the formatting guide, document the bundle-ID permission reset and data migration, and label historical documents without rewriting their recorded evidence.
- [x] **Step 4: Run tests** — `zsh app/test-product-identity.sh` and `git diff --check`; expected: PASS.
- [ ] **Step 5: Commit** — deferred pending explicit user approval; proposed message: `docs: rename public product to Mote`.

### Task 4: MLX Metal library generation

**Files:** Generate: `bench/.build/arm64-apple-macosx/debug/mlx.metallib` or `bench/.build/debug/mlx.metallib` / Modify only on reproduced failure: `bench/Sources/MLXSpikeSupport/MLXMetallibPreparation.swift`, its tests, or `app/Scripts/metal_library.sh`
**Interfaces:** Consumes: installed Xcode Metal Toolchain and MLX Swift checkout kernels / Produces: non-empty `mlx.metallib` discoverable by `app/bundle.sh`

- [x] **Step 1: Preserve the failing preflight** — `app/test-bundle-security.sh` already asserts the locator fails on an empty tree and selects a real candidate; no new production behavior is added before reproduction.
- [x] **Step 2: Reproduce/generate** — `cd bench && swift run mlx-metallib-prepare`; expected: source discovery and compilation produce a non-empty artifact. If it fails, capture the exact failing phase before changing code.
- [x] **Step 3: Minimal implementation** — no source change was required; the unchanged helper compiled all 39 kernel sources successfully after running with normal SwiftPM/Metal cache access.
- [x] **Step 4: Run tests** — `cd bench && swift test`, then from the repository root run `test -s bench/.build/arm64-apple-macosx/debug/mlx.metallib || test -s bench/.build/debug/mlx.metallib`, `file bench/.build/arm64-apple-macosx/debug/mlx.metallib`, and `zsh app/test-bundle-security.sh`; expected: PASS.
- [ ] **Step 5: Commit** — generated `.build` output is not committed; any source fix is deferred pending explicit approval with proposed message `fix: make MLX metallib generation repeatable`.

### Task 5: Real Developer ID build

**Files:** Generate: `app/.build/Mote.app`, `app/.build/Mote-notarization.zip`
**Interfaces:** Consumes: `mlx.metallib`, bundle identifier `dev.brice.mote`, installed `Developer ID Application: Brice Neal (KPM2M597LZ)` / Produces: hardened, timestamped, strictly verified signed app and zip

- [x] **Step 1: Verify prerequisites** — `security find-identity -v -p codesigning` found `Developer ID Application: Brice Neal (KPM2M597LZ)`, and the generated metallib was present and non-empty.
- [x] **Step 2: Run the release build** — `cd app && SIGNING_IDENTITY='Developer ID Application: Brice Neal (KPM2M597LZ)' ./release.sh` produced the signed Mote app and zip.
- [x] **Step 3: Inspect identity** — Info.plist reports Mote 1.0.0, executable `Mote`, and `dev.brice.mote`; `codesign -dvvv` reports the Developer ID chain, hardened-runtime flag, secure timestamp, team `KPM2M597LZ`, and stapled ticket; strict verification passes.
- [x] **Step 4: Run pre-notary verification** — strict signature verification passed before submission; final Gatekeeper acceptance was verified after notarization in Task 6.
- [ ] **Step 5: Commit** — build artifacts are not committed.

### Task 6: Keychain profile, notarization, and final verification

**Files:** Local Keychain profile: `Mote-notary` (outside repository) / Create: `app/Scripts/notarization.sh` / Modify: `app/release.sh`, `app/test-bundle-security.sh` / Generate: stapled `app/.build/Mote.app` and refreshed zip
**Interfaces:** Consumes: Apple ID entered locally, Team ID `KPM2M597LZ`, app-specific password entered locally, signed Mote zip / Produces: accepted notarization, stapled ticket, successful Gatekeeper assessment

- [x] **Step 1: Create the profile locally** — `Mote-notary` was stored in Keychain from the user's terminal without credentials entering chat or repository files.
- [x] **Step 2: Validate credentials** — `xcrun notarytool history --keychain-profile Mote-notary` authenticated successfully.
- [x] **Step 3: Submit and wait** — submission `39b92201-1cd3-4cab-9ed2-2b94db2ce5d9` was Accepted; the ticket was stapled and validated, Gatekeeper accepted the app, and the final ZIP was rebuilt around the stapled bundle.
- [x] **Step 4: Final verification** — 118 app tests and 21 bench tests passed; identity/security scripts and `git diff --check` passed; Apple's log reports `Ready for distribution` with zero issues; the app extracted from the final ZIP passes strict codesign verification, stapler validation, and Gatekeeper assessment.
- [ ] **Step 5: Commit** — deferred pending explicit user approval; present verified diff and proposed commits before committing.
