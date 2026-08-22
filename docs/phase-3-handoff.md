# Grotdown Fresh Session Handoff

Snapshot for a fresh Codex session. Current date: 2026-07-09.

## Repo State

The active branch is `main`. Confirm the exact local/remote state before
starting new work:

Start by confirming:

```bash
git status --short --branch
git log -3 --oneline --decorate
```

## Current Product State

MVP Phases 0-2 are complete. The product is now named **Grotdown**: a
menu-bar-first, on-device dictation app with guarded Plain/GFM output, a
rebindable Option-Space default hotkey, local History, and Snippets. Phase 3
MLX cleanup proof and hardening work is implemented through Task 14, and the
Task 14 default-provider decision is accepted after manual review.

The app now presents MLX as the cleanup path. There is no user-facing provider
selector or Ollama rollback setting.

The menu-bar runtime console is shipped and smoke-tested. The dropdown now
shows status, Pause/Resume Dictation, Settings, last raw/cleaned dictation copy
actions, and Quit. Durable preferences remain in macOS Settings.

The internal provider chain is:

```text
MLX -> raw transcript
```

Task 12 changed the fallback policy:

- `.accepted`: return cleaned text.
- `.rejected`: stop the chain and return raw transcript.
- `.unavailable`, `.timeout`, `.error`: return raw transcript because there is
  no secondary cleanup provider.

Provider diagnostics are still recorded in `attempts`.

## Important Code Areas

- `app/Sources/LocalFlowCleanup/CleanupProvider.swift`
  Provider IDs, selection, factory, and provider chain.
- `app/Sources/LocalFlowCleanup/MLXCleanupProvider.swift`
  Native MLX cleanup provider.
- `app/Sources/LocalFlowCleanup/CleanupSafety.swift`
  Sanitizer, wrapper/link/Markdown guards, added-token guard, filler allowance.
- `app/Sources/LocalFlowCleanup/CleanupPlausibility.swift`
  Length, speaker-overlap, protected-marker, and dictionary-term checks.
- `app/Sources/LocalFlowCleanup/CleanupAcceptanceRunner.swift`
  Provider-chain execution and fallback policy.
- `app/Sources/LocalFlowCleanupAcceptance/main.swift`
  Production acceptance benchmark CLI.
- `app/Sources/LocalFlow/MenuView.swift`
  Menu-bar runtime console and copy actions.
- `app/Sources/LocalFlowCleanup/MenuRuntimeSnapshot.swift`
  Testable formatting for menu status, runtime control labels, and last
  dictation previews.
- `docs/reports/mlx-cleanup-benchmark/`
  Report generation, tests, and benchmark artifacts.
- `bench/Sources/MLXSpikeSupport/`
  MLX metallib and benchmark support.

## Latest Evidence

Read this first:

```text
docs/reports/mlx-cleanup-benchmark/runs/2026-07-08-task-14-mlx-default-provider/report.md
```

Task 14 benchmark summary:

- Sample count: `24`.
- MLX accepted: `23`.
- Raw fallback: `1`.
- Median production-chain latency: `0.195s`.
- p95 production-chain latency: `0.218s`.
- Max latency: `0.238s`.
- Selected provider: `mlx`.
- Sample `08`: accepted by MLX with leading `so like` polished out.
- Sample `20`: accepted by MLX with `uh` polished out.
- Sample `17`: rejected by MLX as `protectedMarkerLoss` for `i think`; Brice
  approved the resulting raw fallback as correct safety behavior.
- Sample `17` attempted providers: `mlx` only.

The Task 14 run folder contains:

```text
docs/reports/mlx-cleanup-benchmark/runs/2026-07-08-task-14-mlx-default-provider/
```

Artifacts:

- `production-acceptance.json`
- `report.md`
- `report.pdf`
- `report.docx`
- `charts/production-chain-latency.png`
- `qa-render/pdf-page-*.png`

PDF render QA looked clean. DOCX was generated, but direct DOCX visual render QA
was blocked because `soffice` is not installed in this environment.

## Verification From The Checkpoint

These passed for the Task 14 default-provider switch:

```bash
cd app && swift test
python3 -m unittest discover -s docs/reports/mlx-cleanup-benchmark -p 'test_*.py'
git diff --check
cd app && ./bundle.sh
```

Observed results:

- Swift tests: `28` passed.
- Python report tests: `17` passed.
- `git diff --check`: clean.
- Bundle build: completed and signed with `LocalFlow Dev`.
- MLX metallib copied into `app/.build/LocalFlow.app/Contents/Resources/`.
- Production acceptance run selected `mlx`.

These passed for the menu runtime console smoke:

```bash
cd app && swift test
cd app && ./bundle.sh
```

Observed results:

- Swift tests: `33` passed.
- Bundle build: completed and signed with `LocalFlow Dev`.
- MLX metallib copied into `app/.build/LocalFlow.app/Contents/Resources/`.
- Fresh app menu showed `Pause Dictation`.
- Pause changed the dropdown to `Paused — choose Resume Dictation` with
  `Resume Dictation`.
- Resume returned the panel to its configured-hotkey ready state.
- Manual dictation smoke passed: "um so like i think we should uh ship it
  friday" landed as "I think we should ship it Friday."
- Last dictation menu showed raw and cleaned copy actions.

The `LocalFlow Dev` signing identity is valid. A sandboxed Keychain check once
reported `0 valid identities` and `CSSMERR_TP_NOT_TRUSTED`, but unsandboxed
checks confirmed `LocalFlow Dev` is present, codesign verification succeeds,
and the app signature authority is `LocalFlow Dev`.

## Current Decision Point

MLX is now the accepted and only cleanup provider. Task 14 no longer has an
open sample-17 review gate. Future user-facing work should keep the product
MLX-only unless a new design explicitly reintroduces provider selection.
Engineering validation should preserve the raw-fallback contract:

- Keep cleanup MLX-only unless a new design explicitly reintroduces provider
  selection.
- Keep raw fallback terminal.
- Keep diagnostic attempts in reports.

The next product discussion should be streaming partial transcripts in the HUD.
The menu-bar toolbar/dropdown discussion is closed.

## Useful Commands

Run tests:

```bash
cd app
swift test
```

Run report tests from repo root:

```bash
python3 -m unittest discover -s docs/reports/mlx-cleanup-benchmark -p 'test_*.py'
```

Build signed app bundle:

```bash
cd app
./bundle.sh
```

Run production acceptance benchmark with the default provider:

```bash
cd app
swift run local-flow-cleanup-acceptance \
  --output ../docs/reports/mlx-cleanup-benchmark/runs/<run-label>/production-acceptance.json
```

Generate report artifacts:

```bash
python3 docs/reports/mlx-cleanup-benchmark/production_acceptance_report.py \
  --input docs/reports/mlx-cleanup-benchmark/runs/<run-label>/production-acceptance.json \
  --run-label "<Human Label>"
```

## Copy-Paste Goal For Fresh Session

```text
Continue Grotdown after the accepted Task 14 MLX default-provider decision.
Start by reading
docs/phase-3-handoff.md and the Task 14 report at
docs/reports/mlx-cleanup-benchmark/runs/2026-07-08-task-14-mlx-default-provider/report.md.
The menu-bar runtime console is shipped and smoke-tested. Next product
discussion is streaming partial transcripts in the HUD. Keep the user-facing
product MLX-only, with no provider selector. Preserve raw transcript fallback.
```
