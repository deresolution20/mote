# Local Flow Phase 3 Handoff

Snapshot for the next session. Current date: 2026-07-06.

## Current State

MVP Phases 0-2 are complete. Phase 3 now includes the MLX cleanup proof and
hardening work through Task 12.

The app still defaults to Ollama for production cleanup unless the cleanup
provider is explicitly selected through UserDefaults or:

```bash
LOCALFLOW_CLEANUP_PROVIDER=mlx
```

When MLX is selected, the provider chain remains:

```text
MLX -> Ollama -> raw transcript
```

Task 12 changed the policy so MLX safety/content rejection stops immediately at
raw fallback instead of paying the Ollama timeout penalty. Operational failures
still continue to the next provider:

- `.accepted`: return cleaned text.
- `.rejected`: stop the chain and return raw transcript.
- `.unavailable`, `.timeout`, `.error`: continue to the next provider.

## What Changed In This Phase

- Cleanup code moved out of the monolithic app target into `LocalFlowCleanup`.
- Added `CleanupProvider` abstraction and provider factory.
- Added `OllamaCleanupProvider` and native Swift `MLXCleanupProvider`.
- Added deterministic cleanup gates:
  - `CleanupSafety`
  - `CleanupPlausibility`
  - protected marker checks
  - added-token checks
  - Markdown/link/wrapper/multiline guards
- Added `CleanupAcceptanceRunner` and diagnostic attempt recording.
- Added the `local-flow-cleanup-acceptance` benchmark CLI.
- Added benchmark and report tooling under `docs/reports/mlx-cleanup-benchmark`.
- Added MLX metallib preparation and benchmark support under `bench`.
- Added Swift tests for provider selection, safety, acceptance fallback policy,
  and benchmark support helpers.

## Task 12 Result

Run folder:

```text
docs/reports/mlx-cleanup-benchmark/runs/2026-07-06-task-12-tail-latency/
```

Key result:

- Sample `20`: MLX accepted.
- Sample `17`: rejected by MLX and returned raw fallback.
- Sample `17` attempted providers: `mlx` only.
- Ollama attempts after safety rejection: `0`.
- Path split: `23/0/1` for MLX/Ollama/raw.
- p95 production-chain latency: `0.219s`.
- Rejected attempt count: `1`.
- Timeout attempt count: `0`.

This fixed the Task 11 tail cases without weakening the sample 17 safety
behavior.

## Verification Already Run

From this checkpoint:

```bash
cd app && swift test
python3 -m unittest discover -s docs/reports/mlx-cleanup-benchmark -p 'test_*.py'
git diff --check
cd app && ./bundle.sh
```

Observed results:

- Swift tests: `26` passed.
- Python report tests: `17` passed.
- `git diff --check`: clean.
- Bundle build: completed and signed with `LocalFlow Dev`.
- MLX metallib copied into `app/.build/LocalFlow.app/Contents/Resources/`.

The Task 12 report generated:

- `production-acceptance.json`
- `report.md`
- `report.pdf`
- `report.docx`
- `charts/production-chain-latency.png`
- `qa-render/pdf-page-*.png`

PDF render QA looked clean. DOCX was generated, but direct DOCX render QA was
blocked because `soffice` is not installed in this environment.

## Important Caveats

- Manual output review is still required before making MLX the default provider.
- The automated report still returns `hold_for_raw_fallback_review` because one
  raw fallback remains by design: sample `17`.
- The app default remains Ollama. Do not switch the default until manual review
  is complete.
- The repository had a large dirty/untracked phase state before Task 12. This
  handoff is meant to make the checkpoint understandable after committing that
  full state.

## Recommended Next Steps

1. Review the 23 MLX-accepted outputs in:

   ```text
   docs/reports/mlx-cleanup-benchmark/runs/2026-07-06-task-12-tail-latency/report.md
   ```

2. Decide whether each accepted output preserves meaning closely enough.

3. If manual review passes, choose one:

   - Make MLX the default provider.
   - Keep MLX opt-in for one more validation window.
   - Add one more hardening task for any reviewed output quality issue.

4. If making MLX default, preserve rollback:

   - Keep Ollama provider available.
   - Keep raw fallback terminal.
   - Keep `LOCALFLOW_CLEANUP_PROVIDER` override.
   - Keep diagnostic attempts in reports.

## Copy-Paste Goal For Tomorrow

```text
Continue Local Flow Phase 3 MLX cleanup hardening. Read docs/phase-3-handoff.md
first, then review the 23 MLX-accepted outputs from
docs/reports/mlx-cleanup-benchmark/runs/2026-07-06-task-12-tail-latency/report.md.
Decide whether MLX is ready to become the default cleanup provider or whether one
more quality-hardening task is needed. Keep the dictation path local, preserve
raw transcript fallback, keep Ollama as rollback until the default-provider
decision is explicit, and verify with swift test, Python report tests,
git diff --check, bundle build, and a production acceptance run.
```
