# Local Flow Post-Safety Production Acceptance Benchmark

Run label: `Task 14 MLX Default Provider`

> Historical pre–MLX-only acceptance evidence. This report preserves the
> measured Task 14 provider-chain data; Grotdown's current runtime is MLX with
> raw-transcript terminal fallback and does not include an Ollama fallback.

## Executive Summary

This run measures the actual production cleanup chain after one warmup inside a single process: MLX first, Ollama fallback second, and raw transcript fallback last. The benchmark records latency, chosen path, attempted providers, and final text for every reference sample.

## Acceptance Snapshot

- Selected provider: `mlx`.
- Provider chain: `mlx (mlx-community/Qwen2.5-1.5B-Instruct-4bit) -> ollama (gemma3:4b)`.
- Sample count: `24`.
- Warmup: `3.077s` via `mlx`.
- Median production-chain latency: `0.195s`.
- p90: `0.217s`; p95: `0.218s`; max: `0.238s`.
- Path counts: `MLX 23`, `Ollama fallback 0`, `raw fallback 1`.
- Automated decision: `accepted_after_manual_review`.
- Manual review: `approved`; Brice approved sample `17` raw fallback as correct safety behavior for the Task 14 default-provider decision.

## Runtime Contract

- Native Swift MLX / MLX Swift LM.
- No oMLX app.
- No Python runtime helper in the measured cleanup path.
- Ollama is used only as the production fallback when MLX is selected.
- Raw transcript fallback remains the terminal safety behavior.

## Sample Results

| id | latency | path | attempted providers | final text |
| --- | ---: | --- | --- | --- |
| 01 | 0.167s | mlx | mlx | I think we should ship it Friday. |
| 02 | 0.166s | mlx | mlx | Yeah, basically the dashboard is broken again. |
| 03 | 0.193s | mlx | mlx | Can you send me the link to that doc? |
| 04 | 0.210s | mlx | mlx | So I was thinking maybe we grab lunch after standup. |
| 05 | 0.174s | mlx | mlx | Let's move the meeting to three thirty instead. |
| 07 | 0.192s | mlx | mlx | I mean, it's probably a caching issue. |
| 08 | 0.207s | mlx | mlx | the query takes forever when i add the group by |
| 09 | 0.200s | mlx | mlx | Remind me to follow up with Sarah tomorrow morning. |
| 10 | 0.217s | mlx | mlx | Yeah, I'll push the fix after I grab a coffee. |
| 11 | 0.180s | mlx | mlx | So, the memory usage spikes every night around midnight. |
| 12 | 0.202s | mlx | mlx | Can we circle back on the pricing thing next week? |
| 13 | 0.191s | mlx | mlx | Honestly, I think the second option is way better. |
| 14 | 0.218s | mlx | mlx | My flight gets in at like seven so dinner at eight works. |
| 15 | 0.215s | mlx | mlx | so basically zendesk tickets should route to the the triage queue |
| 16 | 0.203s | mlx | mlx | I want to test this on the staging cluster first. |
| 17 | 0.170s | raw_fallback | mlx | yeah the uh the new hire starts monday i think |
| 18 | 0.187s | mlx | mlx | Let's just revert it and investigate tomorrow. |
| 19 | 0.200s | mlx | mlx | so grafana needs the api key rotated before the demo |
| 20 | 0.238s | mlx | mlx | Okay, long story short, we missed the deadline by two days. |
| 21 | 0.157s | mlx | mlx | I think we should ship it Friday. |
| 22 | 0.167s | mlx | mlx | Yeah, basically the dashboard is broken again. |
| 23 | 0.196s | mlx | mlx | Can you send me the link to that doc. |
| 25 | 0.177s | mlx | mlx | Let's move the meeting to three thirty instead. |
| 26 | 0.202s | mlx | mlx | okay so the customer said the alerts are firing twice. |

## Rejected Attempt Diagnostics

| id | provider | latency | outcome | reason | detail | raw candidate | sanitized candidate |
| --- | --- | ---: | --- | --- | --- | --- | --- |
| 17 | mlx | 0.170s | rejected | protectedMarkerLoss | i think | Yeah, the new hire starts next Monday. | Yeah, the new hire starts next Monday. |

## Manual Review

Sample `17` is accepted as a raw fallback. MLX rejected the candidate because it
dropped the protected marker `i think`, and the final pasted text preserves the
raw transcript.

## Generated Artifacts

- `production-acceptance.json`: structured live benchmark result.
- `report.md`: agent-readable benchmark summary.
- `report.pdf`: visual report.
- `report.docx`: editable Word-compatible report.
- `charts/production-chain-latency.png`: per-sample latency/path chart.
- `qa-render/`: rendered PDF QA images.
