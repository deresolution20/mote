# Ollama cleanup-hop benchmark

- Input: the 20 verbatim reference transcripts (fillers included)
- temperature 0.1, num_predict 256, non-streaming `/api/generate`
- Latency includes Ollama model residency effects — first call per model may be slower (load)

## gemma3:4b

Median 0.648 s · p90 0.670 s · first call 2.262 s

| id | latency | cleaned output (verify meaning by eye) |
| --- | --- | --- |
| 01 | 2.262 s | I think we should ship it Friday. |
| 02 | 0.602 s | Yeah, basically the dashboard is broken again. |
| 03 | 0.603 s | I think you can find that document here. |
| 04 | 0.647 s | I was thinking maybe we grab lunch after standup. |
| 05 | 0.648 s | Let’s move the meeting to three thirty instead. |
| 06 | 0.601 s | The customer said the alerts are firing twice. |
| 07 | 0.635 s | It’s probably a caching issue, you know. |
| 08 | 0.650 s | The query takes forever when I add the GROUP BY. |
| 09 | 0.649 s | Remind me to follow up with Sarah tomorrow morning. |
| 10 | 0.667 s | I’ll push the fix after I grab a coffee. |
| 11 | 0.611 s | The memory usage spikes every night around midnight. |
| 12 | 0.652 s | Can we circle back on the pricing thing next week? |
| 13 | 0.623 s | I honestly think the second option is way better. |
| 14 | 0.670 s | My flight gets in at seven so dinner at eight works. |
| 15 | 0.655 s | Zendesk tickets should route to the triage queue. |
| 16 | 0.648 s | I want to test this on the staging cluster first. |
| 17 | 0.692 s | The new hire starts Monday, I think. |
| 18 | 0.624 s | Let’s just revert it and investigate tomorrow. |
| 19 | 0.649 s | Grafana needs the API key rotated before the demo. |
| 20 | 0.670 s | Long story short, we missed the deadline by two days. |

## gemma4:26b

Median 6.796 s · p90 10.464 s · first call 15.335 s

| id | latency | cleaned output (verify meaning by eye) |
| --- | --- | --- |
| 01 | 15.335 s |  |
| 02 | 6.693 s |  |
| 03 | 6.735 s |  |
| 04 | 6.728 s |  |
| 05 | 6.733 s |  |
| 06 | 6.733 s |  |
| 07 | 6.798 s |  |
| 08 | 6.796 s |  |
| 09 | 6.795 s |  |
| 10 | 6.811 s |  |
| 11 | 6.860 s |  |
| 12 | 6.919 s |  |
| 13 | 6.847 s |  |
| 14 | 7.261 s |  |
| 15 | 34.842 s |  |
| 16 | 6.661 s |  |
| 17 | 6.717 s |  |
| 18 | 6.681 s |  |
| 19 | 6.771 s |  |
| 20 | 10.464 s |  |
