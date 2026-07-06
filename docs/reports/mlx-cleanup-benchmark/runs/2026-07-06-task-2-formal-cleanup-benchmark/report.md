# Local Flow MLX Cleanup Benchmark

Run label: `task-2-formal-cleanup-benchmark`

## Executive Summary

The benchmark supports continuing Phase 3 as MLX Performance and Reliability Hardening. MLX delivered a large cleanup-latency win, but it is not ready to become the default provider until sanitizer and meaning-preservation guards are implemented.

## Performance Metrics

- Ollama `gemma3:4b`: median `0.914s`, p90 `1.485s`, first call `12.070s`.
- MLX `mlx-community/Qwen2.5-1.5B-Instruct-4bit`: load `0.489s`, warmup `0.180s`, median `0.240s`, p90 `0.264s`.
- Median speedup: `3.8x`.
- p90 speedup: `5.6x`.
- MLX load + warmup: `0.669s`.

## Model Comparison

| Dimension | Ollama | MLX |
| --- | --- | --- |
| Model | `gemma3:4b` | `mlx-community/Qwen2.5-1.5B-Instruct-4bit` |
| Footprint | `3.3 GB` | `0.88 GB` |
| Runtime posture | Localhost daemon | Native MLX target |
| App-runtime target | Existing fallback | Swift-native MLX, not Python |

## Acceptance Status

Acceptance decision: `fail` for making MLX the production default.

Reason: latency passed the Phase 3 target, but MLX output still needs sanitizer and guard work:

- Strip Markdown/code formatting.
- Reject added words or added content.
- Preserve protected markers and personal dictionary terms.
- Fall back to raw transcript when output is unsafe.

## Known Output Findings

- Markdown/code formatting appeared around `GROUP BY`.
- `standup` became `the Standup`.
- Some filler words were retained.

## Generated Artifacts

- `report.pdf`: portfolio-grade visual report.
- `report.docx`: editable Word-compatible report.
- `report.md`: agent-readable summary.
- `metadata.json` and `cleanup-results.json`: structured run data.
- `charts/*.png`: reusable chart assets.

## Source Inputs

- `raw-ollama-cleanup.md`
- `raw-mlx-cleanup.md`
- `bench/samples/manifest.json`
