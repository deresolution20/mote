# Task Spec 1: Benchmark Reporting System

## Spec Tier

This is a task spec under
`spec/phase-3-mlx-performance-reliability-hardening.md`. It defines the first
implementable task for Phase 3.

## Objective

Create a repeatable benchmark reporting system for Local Flow cleanup benchmarks.
Formal benchmark runs must produce portfolio-grade PDF and DOCX reports, an
agent-readable Markdown report, chart assets, and raw benchmark outputs under a
stable folder contract.

This task does not implement MLX cleanup in the app. It turns the one-off MLX vs.
Ollama report into reusable reporting infrastructure.

## Background

The MLX spike produced a showpiece report:

- `docs/reports/local-flow-mlx-cleanup-benchmark.pdf`
- `docs/reports/local-flow-mlx-cleanup-benchmark.docx`
- `docs/reports/assets/latency_summary.png`
- `docs/reports/assets/per_sample_latency.png`
- `docs/reports/assets/model_footprint.png`
- `docs/reports/assets/pipeline_visual.png`

Those artifacts documented the first MLX proof:

- Ollama `gemma3:4b`: median `0.914s`, p90 `1.485s`, first call `12.070s`.
- MLX `mlx-community/Qwen2.5-1.5B-Instruct-4bit`: load `0.489s`, warmup
  `0.180s`, median `0.240s`, p90 `0.264s` after unloading the resident 30B
  model.

Phase 3 needs that reporting discipline available for every formal cleanup
benchmark, not only for this one spike.

## Scope

### In Scope

- Create a dedicated reporting folder under
  `docs/reports/mlx-cleanup-benchmark/`.
- Add report-generation tooling that consumes existing raw benchmark outputs.
- Generate PDF and DOCX reports.
- Generate an agent-readable Markdown report for fast future review.
- Generate chart assets for latency, per-sample results, model footprint, and
  architecture comparison when the input data supports them.
- Preserve raw benchmark inputs in each run folder for auditability.
- Add a README that explains how to run the report generator and how run folders
  are structured.
- Use the existing MLX vs. Ollama benchmark evidence as the first formal run.
- Support one explicit command for a formal report run.

### Out Of Scope

- App runtime MLX cleanup.
- Swift-native MLX integration.
- Cleanup provider selection in the app.
- Any change to `app/Sources/LocalFlow`.
- Any change to ASR behavior.
- Requiring oMLX, a local MLX server, or an external desktop app.
- Making report generation part of ordinary app launch or dictation.

## Folder Contract

The final reporting system must use this structure:

```text
docs/reports/mlx-cleanup-benchmark/
  README.md
  generate_report.py
  assets/
  runs/
    YYYY-MM-DD-<short-run-name>/
      report.pdf
      report.docx
      report.md
      raw-ollama-cleanup.md
      raw-mlx-cleanup.md
      charts/
        latency-summary.png
        per-sample-latency.png
        model-footprint.png
        pipeline-comparison.png
```

The run folder name must be stable, readable, and sortable by date. A run may add
machine-readable files such as JSON metadata, but the files listed above are the
minimum required output for the first formal run.

## Input Contract

The report generator must consume benchmark outputs that include:

- Benchmark date.
- Run label.
- Machine/runtime context when available.
- Model names.
- Model footprint estimates.
- Median cleanup latency.
- p90 cleanup latency.
- Cold load, first-call, or warmup observations where measured.
- Per-sample latency rows.
- Per-sample cleaned output rows when available.
- Quality notes and acceptance decision.

For Task 1, the generator may consume the current raw Markdown reports from the
MLX spike. Later tasks can add cleaner JSON output from the benchmark harness.

## Output Contract

Each formal run must produce:

- `report.pdf`: visually polished, portfolio-grade report.
- `report.docx`: editable Word-compatible report with the same core content.
- `report.md`: agent-readable report with the measured values, quality findings,
  acceptance decision, and source notes.
- `raw-ollama-cleanup.md`: copied or generated raw Ollama benchmark output.
- `raw-mlx-cleanup.md`: copied or generated raw MLX benchmark output.
- `charts/*.png`: reusable chart assets used by the reports.

The reports must include:

- Executive summary.
- Methodology.
- Latency summary chart.
- Per-sample latency chart.
- Model footprint chart.
- Architecture comparison visual.
- Quality findings.
- Acceptance decision.
- Source/reproducibility notes.

## Design Requirements

The report should read as a portfolio artifact, not a terminal log. It should be
clear to a technical hiring manager or engineering reviewer why the phase exists,
what was measured, what improved, and what still needs hardening.

The report must also be technically honest:

- Separate measured results from recommendations.
- Call out known MLX output artifacts.
- State that Python `mlx-lm` was proof tooling, not the app runtime target.
- State that Swift-native MLX remains the product implementation direction.
- Preserve raw results so the charts can be audited.

## Acceptance Criteria

Task 1 is complete when all of these are true:

- `docs/reports/mlx-cleanup-benchmark/README.md` exists and documents usage.
- `docs/reports/mlx-cleanup-benchmark/generate_report.py` exists.
- One formal run folder exists under
  `docs/reports/mlx-cleanup-benchmark/runs/`.
- The formal run folder contains `report.pdf`, `report.docx`, `report.md`, raw
  Ollama output, raw MLX output, and chart assets.
- The generated report includes the current MLX vs. Ollama benchmark evidence:
  - Ollama median `0.914s`, p90 `1.485s`, first call `12.070s`.
  - MLX median `0.240s`, p90 `0.264s`, load `0.489s`, warmup `0.180s`.
- PDF visual QA has been performed from rendered page images.
- DOCX is structurally verified, and visually rendered if LibreOffice is
  available in the local environment.
- The report states the acceptance decision for the run.
- No app source files are changed by this task.

## Verification Plan

The implementation task must verify:

1. Run the formal report command.
2. Confirm the expected run folder and files exist.
3. Open the DOCX structurally with a DOCX parser.
4. Render the PDF to page images and inspect all pages.
5. Attempt DOCX visual render; if `soffice` is unavailable, record that fallback
   in the implementation summary and rely on structural DOCX validation.
6. Confirm report text includes `0.240s`, `0.264s`, `0.914s`, `1.485s`,
   `Qwen2.5`, and `Ollama`.
7. Confirm `report.md` contains the acceptance decision and source notes.
8. Confirm `git diff --check` is clean.

## Risks

- Report tooling may need Python packages that are not part of the Swift app.
  That is acceptable for reporting, but the README must make the dependency
  explicit.
- DOCX visual QA depends on LibreOffice. If it is absent, structural validation
  must be run and the limitation must be reported.
- Chart generation should not depend on fragile GUI tooling.
- The report command must not overwrite previous run folders.
- Reporting must not become coupled to one hard-coded benchmark run.

## Handoff To Task 2

Task 2 should connect the cleanup benchmark harness to this reporting system.
After Task 1, Task 2 should not need to design report layout; it should only need
to produce raw benchmark data in the input format expected by
`docs/reports/mlx-cleanup-benchmark/generate_report.py`.
