# ASR benchmark results

- Samples: 20 short, filler-heavy dictation utterances (Brice's voice, 16 kHz mono)
- Latency = wall-clock batch transcription of the whole file, model pre-loaded and warmed
  (a proxy for end-of-speech latency; streaming behavior is evaluated separately in Phase 1)
- WER = word-level Levenshtein vs verbatim reference (fillers included), case/punctuation-insensitive
- Content WER = same, with pure disfluencies (um/uh/…) stripped from both sides — the
  fairness metric for Apple SpeechTranscriber, which removes fillers with no verbatim option

## Summary

| Engine | Load | Warmup (1st transcribe) | Median latency | p90 latency | Mean WER | Mean content WER |
| --- | --- | --- | --- | --- | --- | --- |
| WhisperKit large-v3-turbo | 4.191 s | 92.356 s | 0.494 s | 0.510 s | 13.8% | 12.0% |
| WhisperKit base.en | 2.602 s | 5.875 s | 0.082 s | 0.093 s | 23.1% | 19.7% |
| Apple SpeechTranscriber | 0.054 s | 0.091 s | 0.078 s | 0.090 s | 19.2% | 16.0% |
| Parakeet v3 (FluidAudio) | 11.253 s | 0.075 s | 0.071 s | 0.073 s | 11.7% | 10.5% |

## Per-sample details

### WhisperKit large-v3-turbo

| id | audio | latency | WER | content WER | hypothesis |
| --- | --- | --- | --- | --- | --- |
| 01 | 2.5 s | 0.493 s | 27.3% | 22.2% | I'm so like I think we should uship it Friday. |
| 02 | 3.2 s | 0.465 s | 27.3% | 20.0% | Yeah so basically the other dashboard is broken again. |
| 03 | 2.3 s | 0.502 s | 7.7% | 8.3% | Can you um can you send me the the link to that dog? |
| 04 | 3.5 s | 0.510 s | 33.3% | 27.3% | So I was thinking maybe we'll we grab lunch after stand-up. |
| 05 | 2.9 s | 0.493 s | 30.0% | 33.3% | A let's move the meeting to like 3.30 instead. |
| 06 | 3.4 s | 0.496 s | 8.3% | 10.0% | Okay so um the customer said the alerts are off firing twice. |
| 07 | 2.6 s | 0.502 s | 0.0% | 0.0% | I mean it's it's probably a caching issue you know. |
| 08 | 3.3 s | 0.502 s | 7.7% | 8.3% | So like the query takes us forever when I add the group by. |
| 09 | 3.2 s | 0.490 s | 8.3% | 10.0% | Um remind me to it to follow up with Sarah tomorrow morning. |
| 10 | 3.2 s | 0.483 s | 16.7% | 9.1% | Yeah I'll push the fix after I grab a coffee. |
| 11 | 3.3 s | 0.473 s | 18.2% | 10.0% | so the other memory usage spikes every night around midnight. |
| 12 | 3.3 s | 0.489 s | 0.0% | 0.0% | Um can we like circle back on the pricing thing next week? |
| 13 | 2.9 s | 0.480 s | 9.1% | 9.1% | Honestly I think that the second option is is way better. |
| 14 | 3.3 s | 0.499 s | 23.1% | 25.0% | And my flight gets in at like 7 so dinner at 8 works. |
| 15 | 3.9 s | 0.518 s | 23.1% | 18.2% | So basically um Zendesk tickets should route to the other Tridge queue. |
| 16 | 3.1 s | 0.491 s | 0.0% | 0.0% | I want to um to test this on the staging cluster first. |
| 17 | 2.6 s | 0.463 s | 20.0% | 11.1% | Yeah the other new hire starts Monday I think. |
| 18 | 3.5 s | 0.511 s | 0.0% | 0.0% | Um let's just uh let's just revert it and investigate tomorrow. |
| 19 | 3.7 s | 0.508 s | 8.3% | 9.1% | So Grafana needs a needs the API key rotated before the demo. |
| 20 | 3.8 s | 0.499 s | 7.7% | 8.3% | Okay um long story short we we missed the deadline by 2 days. |

### WhisperKit base.en

| id | audio | latency | WER | content WER | hypothesis |
| --- | --- | --- | --- | --- | --- |
| 01 | 2.5 s | 0.082 s | 18.2% | 22.2% | I'm so like I think we should us ship it Friday. |
| 02 | 3.2 s | 0.081 s | 27.3% | 20.0% | Yes, so basically the other dashboard is is broken again. |
| 03 | 2.3 s | 0.084 s | 15.4% | 16.7% | Can you um can you send me the link to that dog? |
| 04 | 3.5 s | 0.090 s | 33.3% | 27.3% | So I was thinking maybe we'll we grab lunch after stand up. |
| 05 | 2.9 s | 0.076 s | 40.0% | 33.3% | Let's move the meeting to light 330 instead. |
| 06 | 3.4 s | 0.091 s | 33.3% | 30.0% | OK so I'm the customer said the alerts are upfiring twice. |
| 07 | 2.6 s | 0.080 s | 10.0% | 10.0% | I mean it's probably a caching issue you know. |
| 08 | 3.3 s | 0.090 s | 7.7% | 8.3% | So like the query takes up forever when I add the group by. |
| 09 | 3.2 s | 0.094 s | 8.3% | 10.0% | "Um, remind me to a to follow up with Sarah tomorrow morning." |
| 10 | 3.2 s | 0.081 s | 16.7% | 9.1% | Yeah I'll push the fix after I grab a coffee. |
| 11 | 3.3 s | 0.078 s | 27.3% | 20.0% | Sew the other memory usage spikes every night around midnight. |
| 12 | 3.3 s | 0.083 s | 8.3% | 0.0% | Can we like circle back on the pricing thing next week? |
| 13 | 2.9 s | 0.078 s | 9.1% | 9.1% | Honestly I think that the second option is is way better. |
| 14 | 3.3 s | 0.080 s | 30.8% | 25.0% | My flight gets in at like 7 so dinner as 8 works |
| 15 | 3.9 s | 0.090 s | 46.2% | 36.4% | So basically armzendesk tickets should root to the other trades queue. |
| 16 | 3.1 s | 0.080 s | 25.0% | 18.2% | I want to untetest this on the staging cluster first. |
| 17 | 2.6 s | 0.077 s | 20.0% | 11.1% | Yeah the other new hire starts Monday I think. |
| 18 | 3.5 s | 0.085 s | 36.4% | 44.4% | Some let's just are let's just reverted and investigate tomorrow. |
| 19 | 3.7 s | 0.096 s | 25.0% | 18.2% | So Grafana needs the "appi key" rotated before the demo. |
| 20 | 3.8 s | 0.093 s | 23.1% | 25.0% | Ok I'm long story short we we missed the deadline by 2 days. |

### Apple SpeechTranscriber

| id | audio | latency | WER | content WER | hypothesis |
| --- | --- | --- | --- | --- | --- |
| 01 | 2.5 s | 0.064 s | 9.1% | 0.0% | So like I think we should uh ship it Friday. |
| 02 | 3.2 s | 0.078 s | 36.4% | 30.0% | Yes, so basically the other dashboard is broken again. |
| 03 | 2.3 s | 0.070 s | 23.1% | 25.0% | Can you um, can you send me the link to the dog? |
| 04 | 3.5 s | 0.085 s | 33.3% | 27.3% | So I was thinking maybe we'll we grab lunch after stand-up. |
| 05 | 2.9 s | 0.067 s | 30.0% | 22.2% | Let's move the meeting to like 330 instead. |
| 06 | 3.4 s | 0.090 s | 16.7% | 20.0% | Okay, so on the customer said the alerts are off firing twice. |
| 07 | 2.6 s | 0.073 s | 10.0% | 10.0% | I mean, it's probably a caching issue, you know. |
| 08 | 3.3 s | 0.079 s | 7.7% | 8.3% | So like the query takes are forever when I add the group by. |
| 09 | 3.2 s | 0.065 s | 25.0% | 10.0% | Remind me to follow up with Sarah tomorrow morning. |
| 10 | 3.2 s | 0.081 s | 8.3% | 0.0% | Yeah, I'll I'll push the fix after I grab a coffee. |
| 11 | 3.3 s | 0.081 s | 18.2% | 10.0% | So the other memory usage spikes every night around midnight. |
| 12 | 3.3 s | 0.074 s | 8.3% | 9.1% | How can we like circle back on the pricing thing next week? |
| 13 | 2.9 s | 0.075 s | 18.2% | 18.2% | Honestly, I think that the 2nd option is is way better. |
| 14 | 3.3 s | 0.071 s | 23.1% | 16.7% | My flight gets in at like 7 so dinner at 8 works. |
| 15 | 3.9 s | 0.087 s | 30.8% | 27.3% | So basically, um Zendesk tickets should route to the other Tridge Q. |
| 16 | 3.1 s | 0.080 s | 0.0% | 0.0% | I want to, um, to test this on the staging cluster first. |
| 17 | 2.6 s | 0.069 s | 20.0% | 11.1% | Yeah, the other new hire starts Monday, I think. |
| 18 | 3.5 s | 0.094 s | 18.2% | 22.2% | Some let's just are, let's just revert it and investigate tomorrow. |
| 19 | 3.7 s | 0.089 s | 25.0% | 27.3% | So Grifana needs and needs the Appi key rotated before the demo. |
| 20 | 3.8 s | 0.091 s | 23.1% | 25.0% | Okay, I'm long story short, we missed the deadline by 2 days. |

### Parakeet v3 (FluidAudio)

| id | audio | latency | WER | content WER | hypothesis |
| --- | --- | --- | --- | --- | --- |
| 01 | 2.5 s | 0.068 s | 9.1% | 11.1% | I'm so like I think we should uh ship it Friday. |
| 02 | 3.2 s | 0.070 s | 27.3% | 20.0% | Yes so basically the other dashboard is is broken again. |
| 03 | 2.3 s | 0.070 s | 15.4% | 16.7% | Can you um can you send me the the link to the dog? |
| 04 | 3.5 s | 0.073 s | 25.0% | 27.3% | So I was thinking maybe we o we grab lunch after stand-up. |
| 05 | 2.9 s | 0.073 s | 20.0% | 22.2% | Uh let's move the meeting to like 3.30 instead. |
| 06 | 3.4 s | 0.070 s | 8.3% | 10.0% | Okay so um the customer said the alerts are up firing twice. |
| 07 | 2.6 s | 0.071 s | 10.0% | 10.0% | I mean it's it's probably a cashing issue you know. |
| 08 | 3.3 s | 0.071 s | 7.7% | 8.3% | So like the query takes a forever when I add the group by. |
| 09 | 3.2 s | 0.072 s | 8.3% | 10.0% | Um remind me to it to follow up with Sarah tomorrow morning. |
| 10 | 3.2 s | 0.073 s | 8.3% | 0.0% | Yeah I'll I'll push the fix after I grab a coffee. |
| 11 | 3.3 s | 0.073 s | 18.2% | 10.0% | So the other memory usage spikes every night around midnight. |
| 12 | 3.3 s | 0.071 s | 0.0% | 0.0% | Um can we like circle back on the pricing thing next week? |
| 13 | 2.9 s | 0.068 s | 9.1% | 9.1% | Honestly I think that the second option is is way better. |
| 14 | 3.3 s | 0.071 s | 7.7% | 8.3% | A my flight gets in at like seven so dinner at eight works. |
| 15 | 3.9 s | 0.074 s | 23.1% | 18.2% | So basically um zendesk tickets should route to the other trig queue. |
| 16 | 3.1 s | 0.070 s | 0.0% | 0.0% | I want to um to test this on the staging cluster first. |
| 17 | 2.6 s | 0.065 s | 20.0% | 11.1% | Yeah the other new hire starts Monday I think. |
| 18 | 3.5 s | 0.071 s | 0.0% | 0.0% | Um let's just uh let's just revert it and investigate tomorrow. |
| 19 | 3.7 s | 0.073 s | 16.7% | 18.2% | So Grafana needs a needs the appy key rotated before the demo. |
| 20 | 3.8 s | 0.074 s | 0.0% | 0.0% | Okay um long story short we we missed the deadline by two days. |

## References

| id | reference |
| --- | --- |
| 01 | um so like i think we should uh ship it friday |
| 02 | yeah so basically the uh the dashboard is is broken again |
| 03 | can you um can you send me the the link to that doc |
| 04 | so i was thinking maybe we uh we grab lunch after standup |
| 05 | uh let's move the meeting to like three thirty instead |
| 06 | okay so um the customer said the alerts are uh firing twice |
| 07 | i mean it's it's probably a caching issue you know |
| 08 | so like the query takes uh forever when i add the group by |
| 09 | um remind me to uh to follow up with sarah tomorrow morning |
| 10 | yeah i'll uh i'll push the fix after i grab a coffee |
| 11 | so the uh the memory usage spikes every night around midnight |
| 12 | um can we like circle back on the pricing thing next week |
| 13 | honestly i think the the second option is is way better |
| 14 | uh my flight gets in at like seven so dinner at eight works |
| 15 | so basically um zendesk tickets should route to the uh the triage queue |
| 16 | i want to um to test this on the staging cluster first |
| 17 | yeah the uh the new hire starts monday i think |
| 18 | um let's just uh let's just revert it and investigate tomorrow |
| 19 | so grafana needs uh needs the api key rotated before the demo |
| 20 | okay um long story short we we missed the deadline by two days |
