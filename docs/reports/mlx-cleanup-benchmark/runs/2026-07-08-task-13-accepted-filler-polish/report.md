# Local Flow Post-Safety Production Acceptance Benchmark

Run label: `Task 13 Accepted Filler Polish`

## Executive Summary

This run measures the actual production cleanup chain after one warmup inside a single process: MLX first, Ollama fallback second, and raw transcript fallback last. The benchmark records latency, chosen path, attempted providers, and final text for every reference sample.

## Acceptance Snapshot

- Selected provider: `mlx`.
- Provider chain: `mlx (mlx-community/Qwen2.5-1.5B-Instruct-4bit) -> ollama (gemma3:4b)`.
- Sample count: `24`.
- Warmup: `4.071s` via `mlx`.
- Median production-chain latency: `0.197s`.
- p90: `0.216s`; p95: `0.235s`; max: `0.265s`.
- Path counts: `MLX 23`, `Ollama fallback 0`, `raw fallback 1`.
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
| 01 | 0.164s | mlx | mlx | I think we should ship it Friday. |
| 02 | 0.265s | mlx | mlx | Yeah, basically the dashboard is broken again. |
| 03 | 0.192s | mlx | mlx | Can you send me the link to that doc? |
| 04 | 0.209s | mlx | mlx | So I was thinking maybe we grab lunch after standup. |
| 05 | 0.174s | mlx | mlx | Let's move the meeting to three thirty instead. |
| 07 | 0.195s | mlx | mlx | I mean, it's probably a caching issue. |
| 08 | 0.208s | mlx | mlx | the query takes forever when i add the group by |
| 09 | 0.199s | mlx | mlx | Remind me to follow up with Sarah tomorrow morning. |
| 10 | 0.214s | mlx | mlx | Yeah, I'll push the fix after I grab a coffee. |
| 11 | 0.182s | mlx | mlx | So, the memory usage spikes every night around midnight. |
| 12 | 0.201s | mlx | mlx | Can we circle back on the pricing thing next week? |
| 13 | 0.189s | mlx | mlx | Honestly, I think the second option is way better. |
| 14 | 0.216s | mlx | mlx | My flight gets in at like seven so dinner at eight works. |
| 15 | 0.216s | mlx | mlx | so basically zendesk tickets should route to the the triage queue |
| 16 | 0.201s | mlx | mlx | I want to test this on the staging cluster first. |
| 17 | 0.170s | raw_fallback | mlx | yeah the uh the new hire starts monday i think |
| 18 | 0.183s | mlx | mlx | Let's just revert it and investigate tomorrow. |
| 19 | 0.199s | mlx | mlx | so grafana needs the api key rotated before the demo |
| 20 | 0.239s | mlx | mlx | Okay, long story short, we missed the deadline by two days. |
| 21 | 0.158s | mlx | mlx | I think we should ship it Friday. |
| 22 | 0.167s | mlx | mlx | Yeah, basically the dashboard is broken again. |
| 23 | 0.193s | mlx | mlx | Can you send me the link to that doc. |
| 25 | 0.173s | mlx | mlx | Let's move the meeting to three thirty instead. |
| 26 | 0.199s | mlx | mlx | okay so the customer said the alerts are firing twice. |

## Rejected Attempt Diagnostics

| id | provider | latency | outcome | reason | detail | raw candidate | sanitized candidate |
| --- | --- | ---: | --- | --- | --- | --- | --- |
| 17 | mlx | 0.170s | rejected | protectedMarkerLoss | i think | Yeah, the new hire starts next Monday. | Yeah, the new hire starts next Monday. |

## Generated Artifacts

- `production-acceptance.json`: structured live benchmark result.
- `report.md`: agent-readable benchmark summary.
- `report.pdf`: visual report.
- `report.docx`: editable Word-compatible report.
- `charts/production-chain-latency.png`: per-sample latency/path chart.
- `qa-render/`: rendered PDF QA images.
