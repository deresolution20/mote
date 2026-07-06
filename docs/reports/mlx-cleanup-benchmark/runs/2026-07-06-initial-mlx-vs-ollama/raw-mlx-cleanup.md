# MLX cleanup-hop benchmark

- Model: `mlx-community/Qwen2.5-1.5B-Instruct-4bit`
- Input: 24 verbatim reference transcripts
- Load: 0.489 s
- Warmup: 0.180 s
- Median: 0.240 s
- p90: 0.264 s
- Temperature: 0.0

| id | latency | reference | cleaned output (verify meaning by eye) |
| --- | --- | --- | --- |
| 01 | 0.217 s | um, so I think we should ship it Friday | I think we should ship it Friday. |
| 02 | 0.238 s | yeah so basically the uh the dashboard is is broken again | Yeah, so basically the dashboard is broken again. |
| 03 | 0.247 s | can you um, can you send me the link to that doc? | Can you send me the link to that doc? |
| 04 | 0.265 s | so i was thinking maybe we uh we grab lunch after standup | So, I was thinking maybe we grab lunch after the Standup. |
| 05 | 0.230 s | uh let's move the meeting to like three thirty instead | Let's move the meeting to three thirty instead. |
| 07 | 0.223 s | i mean it's it's probably a caching issue you know | i mean it's probably a caching issue. |
| 08 | 0.263 s | so like the query takes uh forever when i add the group by | So, the query takes forever when I add the `GROUP BY`. |
| 09 | 0.239 s | um remind me to uh to follow up with sarah tomorrow morning | Remind me to follow up with Sarah tomorrow morning. |
| 10 | 0.256 s | yeah i'll uh i'll push the fix after i grab a coffee | Yeah, I'll push the fix after I grab a coffee. |
| 11 | 0.240 s | so the uh the memory usage spikes every night around midnight | So, the memory usage spikes every night around midnight. |
| 12 | 0.239 s | um can we like circle back on the pricing thing next week | Can we circle back on the pricing thing next week? |
| 13 | 0.249 s | honestly i think the the second option is is way better | Honestly, I think the second option is way better. |
| 14 | 0.253 s | uh my flight gets in at like seven so dinner at eight works | My flight gets in at seven, so dinner at eight works. |
| 15 | 0.265 s | so basically um zendesk tickets should route to the uh the triage queue | So basically, Zendesk tickets should route to the triage queue. |
| 16 | 0.240 s | i want to um to test this on the staging cluster first | I want to test this on the staging cluster first. |
| 17 | 0.240 s | yeah the uh the new hire starts monday i think | Yeah, the new hire starts Monday, I think. |
| 18 | 0.222 s | um let's just uh let's just revert it and investigate tomorrow | Let's just revert it and investigate tomorrow. |
| 19 | 0.259 s | so grafana needs uh needs the api key rotated before the demo | So, Grafana needs the API key rotated before the demo. |
| 20 | 0.264 s | okay um long story short we we missed the deadline by two days | Okay, long story short, we missed the deadline by two days. |
| 21 | 0.218 s | um so like i think we should uh ship it friday | I think we should ship it Friday. |
| 22 | 0.233 s | yeah so basically the uh the dashboard is is broken again | Yeah, so basically the dashboard is broken again. |
| 23 | 0.237 s | can you um can you send me the the link to that doc | Can you send me the link to that doc? |
| 25 | 0.257 s | uh let's move the meeting to like three thirty instead | Let's move the meeting to three thirty instead. |
| 26 | 0.226 s | okay so um the customer said the alerts are uh firing twice | The customer said the alerts are firing twice. |
