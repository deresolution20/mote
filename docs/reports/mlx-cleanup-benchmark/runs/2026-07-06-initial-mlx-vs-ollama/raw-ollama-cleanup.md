# Ollama cleanup-hop benchmark

- Input: the 24 verbatim reference transcripts (fillers included)
- temperature 0.1, num_predict 256, non-streaming `/api/generate`
- Latency includes Ollama model residency effects — first call per model may be slower (load)

## gemma3:4b

Median 0.914 s · p90 1.485 s · first call 12.070 s

| id | latency | cleaned output (verify meaning by eye) |
| --- | --- | --- |
| 01 | 12.070 s | I think we should ship it Friday. |
| 02 | 0.929 s | Yeah, basically the dashboard is broken again. |
| 03 | 1.666 s | I think you can find that document here: [https://github.com/openai/tiktoken](https://github.com/openai/tiktoken) |
| 04 | 0.908 s | I was thinking maybe we grab lunch after standup. |
| 05 | 0.899 s | Let’s move the meeting to three thirty instead. |
| 07 | 0.897 s | It’s probably a caching issue, you know. |
| 08 | 0.913 s | The query takes forever when I add the GROUP BY. |
| 09 | 0.894 s | Remind me to follow up with Sarah tomorrow morning. |
| 10 | 0.928 s | I’ll push the fix after I grab a coffee. |
| 11 | 0.846 s | The memory usage spikes every night around midnight. |
| 12 | 0.916 s | Can we circle back on the pricing thing next week? |
| 13 | 1.485 s | I honestly think the second option is way better. |
| 14 | 0.918 s | My flight gets in at seven so dinner at eight works. |
| 15 | 0.916 s | Zendesk tickets should route to the triage queue. |
| 16 | 0.916 s | I want to test this on the staging cluster first. |
| 17 | 0.841 s | The new hire starts Monday, I think. |
| 18 | 0.892 s | Let’s just revert it and investigate tomorrow. |
| 19 | 1.223 s | Grafana needs the API key rotated before the demo. |
| 20 | 0.919 s | Long story short, we missed the deadline by two days. |
| 21 | 0.814 s | I think we should ship it Friday. |
| 22 | 0.895 s | Yeah, basically the dashboard is broken again. |
| 23 | 0.850 s | I think you can find that doc here. |
| 25 | 1.004 s | Let’s move the meeting to three thirty instead. |
| 26 | 0.810 s | The customer said the alerts are firing twice. |
