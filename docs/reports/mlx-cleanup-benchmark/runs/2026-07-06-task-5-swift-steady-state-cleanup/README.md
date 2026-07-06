# Task 5 - Swift MLX Steady-State Cleanup Benchmark

Date: 2026-07-06

## Purpose

Measure the native Swift MLX cleanup path after setup cost has already been
paid. This run loads the model once, warms once, then runs the 24 cleanup
benchmark samples in one process.

## Commands

Refresh the MLX Metal shader library:

```sh
cd bench
swift run mlx-metallib-prepare
```

Run the steady-state benchmark:

```sh
cd bench
swift run mlx-cleanup-steady-benchmark --output ../docs/reports/mlx-cleanup-benchmark/runs/2026-07-06-task-5-swift-steady-state-cleanup/swift-steady-benchmark.json
```

Generate human-readable reports:

```sh
/private/tmp/localflow-report-venv/bin/python docs/reports/mlx-cleanup-benchmark/steady_state_report.py \
  --input docs/reports/mlx-cleanup-benchmark/runs/2026-07-06-task-5-swift-steady-state-cleanup/swift-steady-benchmark.json \
  --run-label "Task 5 Swift Steady State"
```

## Result

Final status:

```text
completed
```

Recorded timings:

- Load: `0.950s`
- Warmup: `0.069s`
- Benchmark loop: `3.413s`
- Mean repeated cleanup: `0.142s`
- Median repeated cleanup: `0.139s`
- p90 repeated cleanup: `0.164s`
- p95 repeated cleanup: `0.166s`
- Max repeated cleanup: `0.199s`
- Samples: `24`

The repeated-call summary excludes one-time model load and one warmup generation.

## Artifacts

- `swift-steady-benchmark.json`: structured Swift benchmark result.
- `report.md`: agent-readable report.
- `report.pdf`: visual report.
- `report.docx`: editable Word-compatible report.
- `charts/steady-state-latency.png`: per-sample latency chart.
- `qa-render/pdf-page-1.png`: rendered PDF QA page.
- `qa-render/pdf-contact-sheet.png`: rendered PDF QA contact sheet.

## Verification

```sh
cd bench
./test.sh
```

Result:

```text
21 tests in 4 suites passed
```

```sh
python3 -m unittest discover -s docs/reports/mlx-cleanup-benchmark -p 'test_*.py'
```

Result:

```text
13 tests passed
```

PDF render QA passed by visual inspection. DOCX visual rendering through
LibreOffice was not available because `soffice` is not installed; structural
DOCX validation with `python-docx` passed.

No production app files under `app/Sources/LocalFlow` changed.
