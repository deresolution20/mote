# Local Flow Post-Safety Production Acceptance Benchmark

> Historical report. Superseded by Task 14, which accepted MLX as the default
> provider after manual approval of sample 17's raw fallback.

Run label: `Task 11 Rejected Candidate Diagnostics`

## Executive Summary

This run measures the actual production cleanup chain after one warmup inside a single process: MLX first, Ollama fallback second, and raw transcript fallback last. The benchmark records latency, chosen path, attempted providers, and final text for every reference sample.

## Acceptance Snapshot

- Selected provider: `mlx`.
- Provider chain: `mlx (mlx-community/Qwen2.5-1.5B-Instruct-4bit) -> ollama (gemma3:4b)`.
- Sample count: `24`.
- Warmup: `1.314s` via `mlx`.
- Median production-chain latency: `0.275s`.
- p90: `0.343s`; p95: `5.377s`; max: `6.271s`.
- Path counts: `MLX 22`, `Ollama fallback 0`, `raw fallback 2`.
- Automated decision: `hold_for_raw_fallback_review`.
- Manual review: `required` before changing the default provider.

## Runtime Contract

- Native Swift MLX / MLX Swift LM.
- No oMLX app.
- No Python runtime helper in the measured cleanup path.
- Ollama is used only as the production fallback when MLX is selected.
- Raw transcript fallback remains the terminal safety behavior.

## Sample Results

| id | latency | path | attempted providers | final text |
| --- | ---: | --- | --- | --- |
| 01 | 0.244s | mlx | mlx | I think we should ship it Friday. |
| 02 | 0.249s | mlx | mlx | Yeah, basically the dashboard is broken again. |
| 03 | 0.287s | mlx | mlx | Can you send me the link to that doc? |
| 04 | 0.301s | mlx | mlx | So I was thinking maybe we grab lunch after standup. |
| 05 | 0.256s | mlx | mlx | Let's move the meeting to three thirty instead. |
| 07 | 0.268s | mlx | mlx | I mean, it's probably a caching issue. |
| 08 | 0.294s | mlx | mlx | so like the query takes forever when i add the group by |
| 09 | 0.295s | mlx | mlx | Remind me to follow up with Sarah tomorrow morning. |
| 10 | 0.322s | mlx | mlx | Yeah, I'll push the fix after I grab a coffee. |
| 11 | 0.260s | mlx | mlx | So, the memory usage spikes every night around midnight. |
| 12 | 0.289s | mlx | mlx | Can we circle back on the pricing thing next week? |
| 13 | 0.282s | mlx | mlx | Honestly, I think the second option is way better. |
| 14 | 0.326s | mlx | mlx | My flight gets in at like seven so dinner at eight works. |
| 15 | 0.351s | mlx | mlx | so basically zendesk tickets should route to the the triage queue |
| 16 | 0.289s | mlx | mlx | I want to test this on the staging cluster first. |
| 17 | 6.271s | raw_fallback | mlx, ollama | yeah the uh the new hire starts monday i think |
| 18 | 0.218s | mlx | mlx | Let's just revert it and investigate tomorrow. |
| 19 | 0.215s | mlx | mlx | so grafana needs the api key rotated before the demo |
| 20 | 6.264s | raw_fallback | mlx, ollama | okay um long story short we we missed the deadline by two days |
| 21 | 0.209s | mlx | mlx | I think we should ship it Friday. |
| 22 | 0.178s | mlx | mlx | Yeah, basically the dashboard is broken again. |
| 23 | 0.202s | mlx | mlx | Can you send me the link to that doc. |
| 25 | 0.182s | mlx | mlx | Let's move the meeting to three thirty instead. |
| 26 | 0.209s | mlx | mlx | okay so the customer said the alerts are firing twice. |

## Rejected Attempt Diagnostics

| id | provider | latency | outcome | reason | detail | raw candidate | sanitized candidate |
| --- | --- | ---: | --- | --- | --- | --- | --- |
| 17 | mlx | 0.259s | rejected | protectedMarkerLoss | i think | Yeah, the new hire starts next Monday. | Yeah, the new hire starts next Monday. |
| 17 | ollama | 6.012s | timeout | requestTimedOut | 6.0s |  |  |
| 20 | mlx | 0.259s | rejected | addedMeaningToken | uh | Okay, uh, long story short, we missed the deadline by two days. | Okay, uh, long story short, we missed the deadline by two days. |
| 20 | ollama | 6.004s | timeout | requestTimedOut | 6.0s |  |  |

## Generated Artifacts

- `production-acceptance.json`: structured live benchmark result.
- `report.md`: agent-readable benchmark summary.
- `report.pdf`: visual report.
- `report.docx`: editable Word-compatible report.
- `charts/production-chain-latency.png`: per-sample latency/path chart.
- `qa-render/`: rendered PDF QA images.
