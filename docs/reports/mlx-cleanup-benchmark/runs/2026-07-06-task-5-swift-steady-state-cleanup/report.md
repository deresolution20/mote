# Local Flow Swift MLX Steady-State Benchmark

Run label: `Task 5 Swift Steady State`

## Executive Summary

This benchmark measures the native Swift MLX cleanup path after one model load and one warmup generation. The summary latency excludes one-time model load and warmup, so it reflects repeated cleanup calls inside one long-lived process.

## Performance Metrics

- Model: `mlx-community/Qwen2.5-1.5B-Instruct-4bit`.
- Sample count: `24`.
- Load: `0.950s`.
- Warmup: `0.069s`.
- Repeated-call median: `0.139s`; p90 `0.164s`; p95 `0.166s`; max `0.199s`.
- Mean repeated-call latency: `0.142s`.
- Total benchmark loop time: `3.413s`.

## Runtime Contract

- Native Swift MLX / MLX Swift LM.
- No oMLX app.
- No local MLX HTTP server.
- No Python runtime helper in the measured cleanup path.
- `mlx.metallib` is prepared by `swift run mlx-metallib-prepare`.

## Sample Results

| id | latency | cleaned output |
| --- | ---: | --- |
| 01 | 0.139s | So, I think we should ship it on Friday. |
| 02 | 0.133s | Yeah, so basically the dashboard is broken again. |
| 03 | 0.133s | Can you send me the link to that doc? |
| 04 | 0.151s | So I was thinking maybe we grab lunch after standup. |
| 05 | 0.134s | Let's move the meeting to three thirty instead. |
| 07 | 0.113s | It's probably a caching issue. |
| 08 | 0.199s | The query takes a long time to execute when I add the `GROUP BY` clause. |
| 09 | 0.126s | Remember to follow up with Sarah tomorrow morning. |
| 10 | 0.157s | Yeah, I'll push the fix after I grab a coffee. |
| 11 | 0.124s | The memory usage spikes every night around midnight. |
| 12 | 0.142s | Can we circle back on the pricing thing next week? |
| 13 | 0.139s | Honestly, I think the second option is much better. |
| 14 | 0.157s | My flight gets in at seven, so dinner at eight works. |
| 15 | 0.166s | So basically, Zendesk tickets should route to the triage queue. |
| 16 | 0.141s | I want to test this on the staging cluster first. |
| 17 | 0.125s | The new hire starts Monday, I think. |
| 18 | 0.127s | Let's just revert it and investigate tomorrow. |
| 19 | 0.156s | Grafana needs to rotate the API key before the demo. |
| 20 | 0.164s | Okay, long story short, we missed the deadline by two days. |
| 21 | 0.141s | So, I think we should ship it on Friday. |
| 22 | 0.132s | Yeah, so basically the dashboard is broken again. |
| 23 | 0.133s | Can you send me the link to that doc? |
| 25 | 0.132s | Let's move the meeting to three thirty instead. |
| 26 | 0.148s | Okay, so the customer said the alerts are firing twice. |

## Generated Artifacts

- `swift-steady-benchmark.json`: structured Swift benchmark result.
- `report.md`: agent-readable summary.
- `report.pdf`: visual report.
- `report.docx`: editable Word-compatible report.
- `charts/steady-state-latency.png`: per-sample latency chart.
- `qa-render/`: rendered PDF QA images.
