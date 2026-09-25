# Task Spec 5: Swift MLX Steady-State Cleanup Benchmark

## Spec Tier

This is a task spec under
`spec/phase-3-mlx-performance-reliability-hardening.md`. It follows
`spec/task-4-mlx-metallib-repeatability.md`.

## Objective

Measure native Swift MLX cleanup latency after one model load and one warmup,
with repeated cleanup calls running in one long-lived process.

The task must answer one concrete question:

```text
Once Qwen2.5 1.5B is resident through Swift-native MLX, what is the repeated
cleanup-call latency distribution over the 24-sample benchmark manifest?
```

## Scope

### In Scope

- Add a Swift benchmark entrypoint for repeated native MLX cleanup calls.
- Load `mlx-community/Qwen2.5-1.5B-Instruct-4bit` once through MLX Swift LM.
- Run one warmup generation before measurement.
- Run the benchmark manifest samples in the same process.
- Record per-sample cleanup latency after warmup.
- Record p50/median, p90, p95, max, mean, load, warmup, and total benchmark loop
  seconds.
- Write structured JSON under `docs/reports/mlx-cleanup-benchmark/runs/`.
- Generate Markdown, PDF, DOCX, chart, and PDF QA render artifacts from the JSON.
- Keep production app cleanup behavior unchanged.

### Out Of Scope

- Making MLX the default provider.
- Adding provider selection UI.
- Adding sanitizer or plausibility guard behavior.
- Declaring quality acceptance from this benchmark alone.
- Removing Ollama.
- Requiring oMLX, a local server, or a Python runtime helper in the measured
  cleanup path.

## Acceptance Criteria

- `bench` exposes `swift run mlx-cleanup-steady-benchmark`.
- The benchmark uses the Task 4 `mlx.metallib` preflight.
- The benchmark writes `swift-steady-benchmark.json`.
- The result JSON records `completed` status, model/package facts, load seconds,
  warmup seconds, benchmark loop seconds, summary stats, and per-sample rows.
- Summary stats exclude one-time load and warmup.
- The run folder contains `report.md`, `report.pdf`, `report.docx`, chart assets,
  and PDF render QA images.
- `cd bench && ./test.sh` passes.
- Python report tests pass.
- No production code in `app/Sources/LocalFlow` changes.

## Verification Plan

1. Run `cd bench && ./test.sh`.
2. Run `python3 -m unittest discover -s docs/reports/mlx-cleanup-benchmark -p 'test_*.py'`.
3. Run `cd bench && swift run mlx-metallib-prepare`.
4. Run:

   ```sh
   cd bench
   swift run mlx-cleanup-steady-benchmark --output ../docs/reports/mlx-cleanup-benchmark/runs/2026-07-06-task-5-swift-steady-state-cleanup/swift-steady-benchmark.json
   ```

5. Run:

   ```sh
   /private/tmp/localflow-report-venv/bin/python docs/reports/mlx-cleanup-benchmark/steady_state_report.py \
     --input docs/reports/mlx-cleanup-benchmark/runs/2026-07-06-task-5-swift-steady-state-cleanup/swift-steady-benchmark.json \
     --run-label "Task 5 Swift Steady State"
   ```

6. Confirm the JSON parses and reports `completed`.
7. Confirm the PDF render QA images show no obvious layout defects.
8. Confirm the DOCX opens structurally with `python-docx`.
9. Confirm `git diff -- app/Sources/LocalFlow` is empty.
10. Confirm `git diff --check` is clean.
