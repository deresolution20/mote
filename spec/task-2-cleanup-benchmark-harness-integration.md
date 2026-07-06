# Task Spec 2: Cleanup Benchmark Harness Integration

## Spec Tier

This is a task spec under
`spec/phase-3-mlx-performance-reliability-hardening.md`. It follows
`spec/task-1-benchmark-reporting-system.md`.

## Objective

Make cleanup benchmark runs produce stable raw inputs for the benchmark reporting
system. Task 2 connects the `bench/` cleanup benchmark world to
`docs/reports/mlx-cleanup-benchmark/` without changing app runtime behavior.

The end state is a formal cleanup benchmark run that can produce or collect:

- Ollama cleanup results.
- MLX cleanup results from proof/benchmark tooling.
- Structured metadata.
- Raw Markdown outputs.
- Structured data that Task 1's report generator can consume.

## Background

The current `bench` SwiftPM package already has a `bench cleanup` command that
benchmarks Ollama cleanup models over `bench/samples/manifest.json` and writes a
Markdown report.

The MLX proof was run outside the repo with temporary Python tooling. That was
acceptable for model selection, but Phase 3 needs reproducible benchmark inputs
inside the project workflow.

Task 1 defines the reporting destination:

```text
docs/reports/mlx-cleanup-benchmark/runs/YYYY-MM-DD-<short-run-name>/
```

Task 2 defines how raw cleanup benchmark data gets into that run folder.

## Scope

### In Scope

- Extend or wrap cleanup benchmark commands so a formal run creates a run folder
  compatible with Task 1.
- Preserve the existing Ollama cleanup benchmark behavior.
- Add a reproducible MLX cleanup benchmark path for
  `mlx-community/Qwen2.5-1.5B-Instruct-4bit`.
- Capture run metadata needed by reports:
  - Date/time.
  - Run label.
  - OS and hardware context where available.
  - Runtime context for Ollama and MLX.
  - Model names.
  - Model footprint estimates.
  - Load, warmup, first-call, median, and p90 latency where measured.
  - Per-sample latencies.
  - Per-sample cleaned outputs.
  - Quality notes.
  - Acceptance decision.
- Copy or write raw Ollama and MLX benchmark outputs into the run folder.
- Avoid overwriting previous run folders.
- Document the formal command in the reporting README or benchmark docs.

### Out Of Scope

- Swift-native MLX app provider.
- Any change to `app/Sources/LocalFlow`.
- App provider selection.
- UI changes.
- ASR changes.
- Requiring oMLX, a local MLX server, or an external desktop app.
- Making Python `mlx-lm` part of the production app runtime.

## Command Contract

The implementation may satisfy this task by either:

1. Extending the existing Swift `bench cleanup` command, or
2. Adding a reporting/benchmark orchestration script under
   `docs/reports/mlx-cleanup-benchmark/`.

The user-facing requirement is one explicit formal-run command. The command must:

- Accept a run label.
- Create a new run folder under `docs/reports/mlx-cleanup-benchmark/runs/`.
- Refuse to overwrite an existing run folder unless an explicit force option is
  provided.
- Run or collect Ollama results.
- Run or collect MLX results.
- Write raw and structured outputs in the folder contract below.
- Return a non-zero exit code when required raw inputs are missing or malformed.

The command name is an implementation decision, but it must be documented where
Task 1 users can find it.

## Run Folder Data Contract

Each formal run folder must contain:

```text
metadata.json
raw-ollama-cleanup.md
raw-mlx-cleanup.md
cleanup-results.json
```

Task 1 then adds:

```text
report.pdf
report.docx
charts/
```

### `metadata.json`

Required fields:

- `run_label`
- `created_at`
- `samples_manifest`
- `sample_count`
- `machine_context`
- `ollama_runtime`
- `mlx_runtime`
- `notes`

### `cleanup-results.json`

Required fields:

- `run_label`
- `samples`
- `providers`
- `acceptance`

Each provider entry must include:

- `provider_id`
- `model`
- `model_footprint`
- `load_seconds` when measured
- `warmup_seconds` when measured
- `first_call_seconds` when measured
- `median_seconds`
- `p90_seconds`
- `per_sample`

Each per-sample entry must include:

- `id`
- `reference`
- `latency_seconds`
- `cleaned_output`
- `quality_flags`

The first implementation may use simple quality flags such as:

- `markdown_artifact`
- `added_content_risk`
- `protected_marker_risk`
- `meaning_review_required`

## Offline And Privacy Constraints

- Ollama benchmark calls must stay on `localhost` or `127.0.0.1`.
- MLX benchmark calls must run locally.
- The formal run command must not use cloud inference.
- Cloud-routed Ollama models must not be used.
- Benchmark data must remain on disk inside the project run folder.
- This task must not add telemetry, accounts, analytics, or remote uploads.
- Model downloads, if needed, are setup-time only and must be explicit.

## Acceptance Criteria

Task 2 is complete when all of these are true:

- One explicit formal-run command is documented.
- The command creates a unique run folder under
  `docs/reports/mlx-cleanup-benchmark/runs/`.
- The run folder contains `metadata.json`, `cleanup-results.json`,
  `raw-ollama-cleanup.md`, and `raw-mlx-cleanup.md`.
- `cleanup-results.json` includes both Ollama and MLX provider entries.
- The MLX provider entry records the approved model
  `mlx-community/Qwen2.5-1.5B-Instruct-4bit`.
- The run includes median and p90 latency values for both providers.
- The run includes per-sample latency and cleaned output rows.
- The Task 1 report generator can consume the run folder and create PDF/DOCX
  reports without manual data edits.
- Existing benchmark tests still pass.
- No files under `app/Sources/LocalFlow` are changed.

## Verification Plan

The implementation task must verify:

1. Run the formal benchmark command with a fresh run label.
2. Confirm the expected run folder exists.
3. Validate `metadata.json` and `cleanup-results.json` parse as JSON.
4. Confirm both provider entries are present.
5. Confirm raw Markdown outputs exist and are non-empty.
6. Run the Task 1 report generator against the new run folder.
7. Confirm generated PDF/DOCX reports contain the current run label.
8. Run `cd bench && ./test.sh`.
9. Confirm `git diff --check` is clean.
10. Confirm no `app/Sources/LocalFlow` files changed.

## Risks

- SwiftPM benchmark code and Python MLX proof tooling may not share a natural
  runtime. The task may need an orchestration script rather than forcing all
  logic into Swift.
- MLX benchmarks are sensitive to resident model memory pressure. The run
  metadata must capture enough context to explain variability.
- Report generation can become brittle if raw Markdown parsing is the only input
  path. `cleanup-results.json` is required to stabilize Task 1.
- Network restrictions can make first-time model downloads fail. The command
  should distinguish setup/download failures from benchmark failures.

## Handoff To Task 3

Task 3 should start the Swift-native MLX provider spike. After Task 2, Task 3 can
use the formal benchmark command and run-folder contract to measure any provider
prototype without redesigning benchmark data collection or report inputs.
