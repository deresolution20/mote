# ASR benchmark results

- Samples: 24 short, filler-heavy dictation utterances (Brice's voice, 16 kHz mono)
- Latency = wall-clock batch transcription of the whole file, model pre-loaded and warmed
  (a proxy for end-of-speech latency; streaming behavior is evaluated separately in Phase 1)
- WER = word-level Levenshtein vs verbatim reference (fillers included), case/punctuation-insensitive
- Content WER = same, with pure disfluencies (um/uh/…) stripped from both sides — the
  fairness metric for Apple SpeechTranscriber, which removes fillers with no verbatim option

## Summary

| Engine | Load | Warmup (1st transcribe) | Median latency | p90 latency | Mean WER | Mean content WER |
| --- | --- | --- | --- | --- | --- | --- |
| WhisperKit large-v3-turbo | 8.907 s | 1.572 s | 0.482 s | 0.504 s | 23.2% | 14.9% |
| WhisperKit base.en | 4.592 s | 0.581 s | 0.084 s | 0.093 s | 29.9% | 23.2% |
| Apple SpeechTranscriber | 0.065 s | 0.165 s | 0.080 s | 0.097 s | 18.6% | 18.0% |
| Parakeet v3 (FluidAudio) | 0.141 s | 0.096 s | 0.072 s | 0.075 s | 13.6% | 14.0% |

## Per-sample details

### WhisperKit large-v3-turbo

| id | audio | latency | WER | content WER | hypothesis |
| --- | --- | --- | --- | --- | --- |
| 01 | 4.9 s | 0.452 s | 11.1% | 0.0% | So I think we should ship it Friday. |
| 02 | 5.4 s | 0.466 s | 27.3% | 20.0% | Yeah, so basically the dashboard is broken again. |
| 03 | 3.8 s | 0.466 s | 25.0% | 18.2% | Can you send me the link to that doc? |
| 04 | 3.6 s | 0.495 s | 25.0% | 18.2% | So I was thinking maybe we'll grab lunch after standup. |
| 05 | 4.9 s | 0.489 s | 30.0% | 22.2% | Let's move the meeting to like 3:30 instead. |
| 07 | 5.6 s | 0.503 s | 10.0% | 10.0% | I mean, it's probably a caching issue, you know. |
| 08 | 4.1 s | 0.491 s | 7.7% | 0.0% | So like the query takes forever when I add the group by. |
| 09 | 5.1 s | 0.476 s | 25.0% | 10.0% | Remind me to follow up with Sarah tomorrow morning. |
| 10 | 4.4 s | 0.493 s | 25.0% | 18.2% | Yeah, I'll push the fix after I grab a copy. |
| 11 | 4.4 s | 0.468 s | 18.2% | 10.0% | So the memory usage spikes every night around midnight. |
| 12 | 4.1 s | 0.484 s | 8.3% | 0.0% | Can we like circle back on the pricing thing next week? |
| 13 | 3.8 s | 0.473 s | 18.2% | 18.2% | Honestly, I think the second option is way better. |
| 14 | 5.6 s | 0.539 s | 38.5% | 33.3% | My flight gets in at like 7:00, so dinner at 8:00 works. |
| 15 | 5.9 s | 0.500 s | 23.1% | 9.1% | So basically Zendesk tickets should route to the triage queue. |
| 16 | 6.1 s | 0.476 s | 16.7% | 9.1% | I want to test this on the staging cluster first. |
| 17 | 4.6 s | 0.475 s | 20.0% | 11.1% | Yeah, the new hire starts Monday, I think. |
| 18 | 6.1 s | 0.494 s | 54.5% | 44.4% | Let's just revert it and we'll investigate it tomorrow. |
| 19 | 4.9 s | 0.504 s | 25.0% | 18.2% | So, Grafana is the API key rotated before the demo. |
| 20 | 4.6 s | 0.505 s | 15.4% | 8.3% | Okay, long story short, we missed the deadline by two days. |
| 21 | 4.9 s | 0.453 s | 27.3% | 11.1% | So I think we should ship it Friday. |
| 22 | 4.6 s | 0.447 s | 27.3% | 20.0% | yeah so basically the dashboard is broken again |
| 23 | 3.8 s | 0.462 s | 30.8% | 25.0% | Can you send me the link to that doc? |
| 25 | 3.8 s | 0.481 s | 30.0% | 22.2% | Let's move the meeting to like 3:30 instead. |
| 26 | 4.6 s | 0.484 s | 16.7% | 0.0% | Okay, so the customer said the alerts are firing twice. |

### WhisperKit base.en

| id | audio | latency | WER | content WER | hypothesis |
| --- | --- | --- | --- | --- | --- |
| 01 | 4.9 s | 0.083 s | 22.2% | 12.5% | So I think we should chip it Friday. |
| 02 | 5.4 s | 0.081 s | 27.3% | 20.0% | Yeah, so basically the dashboard is broken again. |
| 03 | 3.8 s | 0.078 s | 25.0% | 18.2% | Can you send me the link to that doc? |
| 04 | 3.6 s | 0.085 s | 58.3% | 54.5% | So I was thinking maybe the Grappling chapter stand up. |
| 05 | 4.9 s | 0.075 s | 30.0% | 22.2% | Let's move the meeting to like 330 instead. |
| 07 | 5.6 s | 0.093 s | 40.0% | 40.0% | I mean it's probably I mean it's probably a cashing issue you know |
| 08 | 4.1 s | 0.093 s | 7.7% | 0.0% | So, like the query takes forever when I add the group by. |
| 09 | 5.1 s | 0.081 s | 25.0% | 10.0% | Remind me to follow up with Sarah tomorrow morning. |
| 10 | 4.4 s | 0.091 s | 25.0% | 18.2% | Yeah, I'll push the fix after I grab a copy. |
| 11 | 4.4 s | 0.077 s | 18.2% | 10.0% | So the memory usage spikes every night around midnight. |
| 12 | 4.1 s | 0.087 s | 8.3% | 0.0% | Can we like circle back on the pricing thing next week? |
| 13 | 3.8 s | 0.076 s | 18.2% | 18.2% | Honestly, I think the second option is way better. |
| 14 | 5.6 s | 0.085 s | 53.8% | 50.0% | I like it in it like 7 so dinner at 8 works. |
| 15 | 5.9 s | 0.092 s | 46.2% | 36.4% | Basically, Zendes' ticket should route to the triage queue. |
| 16 | 6.1 s | 0.081 s | 16.7% | 9.1% | I want to test this on the staging cluster first. |
| 17 | 4.6 s | 1.041 s | 20.0% | 22.2% | Yeah, the uh, new hour starts Monday I think. |
| 18 | 6.1 s | 0.104 s | 27.3% | 22.2% | Let's just, uh, let's just revert it and we'll investigate it tomorrow. |
| 19 | 4.9 s | 0.089 s | 33.3% | 27.3% | So, Grafani is the API key rotated before the demo. |
| 20 | 4.6 s | 0.088 s | 15.4% | 8.3% | Okay, long story short, we missed the deadline by two days. |
| 21 | 4.9 s | 0.070 s | 27.3% | 11.1% | So I think we should ship it Friday. |
| 22 | 4.6 s | 0.076 s | 27.3% | 20.0% | Yeah, so basically the dashboard is broken again. |
| 23 | 3.8 s | 0.072 s | 46.2% | 41.7% | Can you see the link to that doc? |
| 25 | 3.8 s | 0.080 s | 50.0% | 44.4% | Let's put the meaning to like 3/30 instead. |
| 26 | 4.6 s | 0.086 s | 50.0% | 40.0% | Okay, so the customer said they learned to fire twice. |

### Apple SpeechTranscriber

| id | audio | latency | WER | content WER | hypothesis |
| --- | --- | --- | --- | --- | --- |
| 01 | 4.9 s | 0.075 s | 0.0% | 0.0% | Um, so I think we should ship it Friday. |
| 02 | 5.4 s | 0.081 s | 27.3% | 20.0% | Yeah, so basically the dashboard is broken again. |
| 03 | 3.8 s | 0.073 s | 0.0% | 0.0% | Can you, um, can you send me the link to that doc? |
| 04 | 3.6 s | 0.074 s | 33.3% | 36.4% | So I was thinking maybe uh, grab lunch after stand-up. |
| 05 | 4.9 s | 0.077 s | 20.0% | 22.2% | Uh, let's move the meeting to like 330 instead. |
| 07 | 5.6 s | 0.100 s | 40.0% | 40.0% | I mean, it's probably, I mean, it's probably a cashing issue, you know. |
| 08 | 4.1 s | 0.078 s | 7.7% | 0.0% | So like the query takes forever when I add the group by? |
| 09 | 5.1 s | 0.079 s | 8.3% | 10.0% | Um, remind me to uh, follow up with Sarah tomorrow morning. |
| 10 | 4.4 s | 0.090 s | 0.0% | 0.0% | Yeah, I'll uh, I'll push the fix after I grab a coffee. |
| 11 | 4.4 s | 0.084 s | 9.1% | 10.0% | So the uh, memory usage spikes every night around midnight? |
| 12 | 4.1 s | 0.076 s | 0.0% | 0.0% | Um, can we like circle back on the pricing thing next week? |
| 13 | 3.8 s | 0.076 s | 27.3% | 27.3% | Honestly, I think the 2nd option is way better. |
| 14 | 5.6 s | 0.083 s | 23.1% | 16.7% | Um, my flight gets in at like 7, so dinner at 8 works. |
| 15 | 5.9 s | 0.097 s | 23.1% | 27.3% | So basically, um, Zindes tickets should route to the uh, triage cue. |
| 16 | 6.1 s | 0.092 s | 0.0% | 0.0% | I want to, um, to test this on the staging cluster first. |
| 17 | 4.6 s | 0.078 s | 20.0% | 11.1% | Yeah, the new hire starts Monday, I think. |
| 18 | 6.1 s | 0.113 s | 18.2% | 22.2% | Um, let's just, uh, let's just revert it and we'll investigate it tomorrow. |
| 19 | 4.9 s | 0.093 s | 25.0% | 27.3% | So Griffon is uh, is the API key rotated before the demo. |
| 20 | 4.6 s | 0.085 s | 23.1% | 16.7% | Okay, long story short, we missed the deadline by 2 days. |
| 21 | 4.9 s | 0.086 s | 36.4% | 44.4% | Um, so I like, think we should, uh, we should ship it Friday. |
| 22 | 4.6 s | 0.080 s | 36.4% | 40.0% | Yeah, so basically the uh, dashboard's broken again. |
| 23 | 3.8 s | 0.075 s | 7.7% | 8.3% | Can you, um, can you send me the link to that doc? |
| 25 | 3.8 s | 0.076 s | 20.0% | 22.2% | Uh, let's move the meeting to like 330 instead. |
| 26 | 4.6 s | 0.079 s | 41.7% | 30.0% | Okay, so the customer said they learned firing twice. |

### Parakeet v3 (FluidAudio)

| id | audio | latency | WER | content WER | hypothesis |
| --- | --- | --- | --- | --- | --- |
| 01 | 4.9 s | 0.067 s | 0.0% | 0.0% | Um so I think we should ship it Friday. |
| 02 | 5.4 s | 0.073 s | 18.2% | 20.0% | Yeah, so basically the uh dashboard is uh broken again. |
| 03 | 3.8 s | 0.067 s | 0.0% | 0.0% | Can you um can you send me the link to that doc? |
| 04 | 3.6 s | 0.071 s | 33.3% | 36.4% | So I was thinking maybe uh grab lunch after stand-up. |
| 05 | 4.9 s | 0.075 s | 0.0% | 0.0% | Uh let's move the meeting to like three thirty instead. |
| 07 | 5.6 s | 0.076 s | 30.0% | 30.0% | I mean it's probably I mean it's probably a caching issue, you know. |
| 08 | 4.1 s | 0.072 s | 0.0% | 0.0% | So like the query takes uh forever when I add the group by? |
| 09 | 5.1 s | 0.073 s | 16.7% | 10.0% | Um, remind me to s uh follow up with Sarah tomorrow morning. |
| 10 | 4.4 s | 0.072 s | 8.3% | 9.1% | Yeah, I'll uh I'll push the fix after I grab a copy. |
| 11 | 4.4 s | 0.072 s | 9.1% | 10.0% | So the uh memory usage spikes every night around midnight? |
| 12 | 4.1 s | 0.072 s | 0.0% | 0.0% | Um can we like circle back on the pricing thing next week? |
| 13 | 3.8 s | 0.070 s | 18.2% | 18.2% | Honestly, I think the second option is way better. |
| 14 | 5.6 s | 0.072 s | 0.0% | 0.0% | Uh my flight gets in at like seven, so dinner at eight works. |
| 15 | 5.9 s | 0.074 s | 7.7% | 9.1% | So basically um Zendesk tickets should route to the uh triage queue. |
| 16 | 6.1 s | 0.070 s | 0.0% | 0.0% | I want to um to test this on the staging cluster first. |
| 17 | 4.6 s | 0.068 s | 20.0% | 22.2% | Yeah, the uh new hour starts Monday I think. |
| 18 | 6.1 s | 0.074 s | 18.2% | 22.2% | Um, let's just uh let's just revert it and we'll investigate it tomorrow. |
| 19 | 4.9 s | 0.075 s | 25.0% | 27.3% | So Grafani's uh it's the API key rotated before the demo. |
| 20 | 4.6 s | 0.072 s | 15.4% | 8.3% | Okay, uh long story short, we missed the deadline by two days. |
| 21 | 4.9 s | 0.070 s | 36.4% | 44.4% | Um so I like think we should uh we should ship it Friday. |
| 22 | 4.6 s | 0.068 s | 36.4% | 40.0% | Yeah, so basically the uh dashboard's broken again. |
| 23 | 3.8 s | 0.065 s | 7.7% | 8.3% | Can you um can you send me the link to that doc? |
| 25 | 3.8 s | 0.068 s | 10.0% | 11.1% | Uh let's move the mean to like three thirty instead. |
| 26 | 4.6 s | 0.069 s | 16.7% | 10.0% | Okay, so the the customer said the alerts are firing twice. |

## References

| id | reference |
| --- | --- |
| 01 | um, so I think we should ship it Friday |
| 02 | yeah so basically the uh the dashboard is is broken again |
| 03 | can you um, can you send me the link to that doc? |
| 04 | so i was thinking maybe we uh we grab lunch after standup |
| 05 | uh let's move the meeting to like three thirty instead |
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
| 21 | um so like i think we should uh ship it friday |
| 22 | yeah so basically the uh the dashboard is is broken again |
| 23 | can you um can you send me the the link to that doc |
| 25 | uh let's move the meeting to like three thirty instead |
| 26 | okay so um the customer said the alerts are uh firing twice |
