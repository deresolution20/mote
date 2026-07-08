# Local Flow Task 9 Default Provider Decision

> Historical report. Superseded by Task 14, which accepted MLX as the default
> provider after the post-safety production-chain run and manual approval of
> sample 17's raw fallback.

Run label: `task-9-default-provider-decision`

## Decision

Ollama remains the production default cleanup provider. MLX remains opt-in.

When MLX is selected, the app tries MLX first, then Ollama, then raw transcript.

## Evidence

- Task 5 Swift MLX steady-state benchmark: median `0.139s`, p90 `0.164s`,
  load `0.950s`, warmup `0.069s`, 24 samples.
- Earlier formal benchmark: Ollama median `0.914s`, p90 `1.485s`; MLX proof
  median `0.240s`, p90 `0.264s`.
- Task 7 sanitizer and plausibility tests pass.
- Task 8 acceptance-runner and fallback tests pass.

## Default-Switch Status

Acceptance decision: `hold`.

Reason: the production safety and fallback logic exists, but there is not yet a
formal post-safety live benchmark proving the full `MLX -> Ollama -> raw`
production chain meets the latency and zero-meaning-change gates.

Recorded Task 5 raw MLX outputs still include unsafe candidates such as added
`on`, `GROUP BY clause`, `Remember` replacing `Remind me`, `much better`, and
`rotate the API key`. These should now be rejected by the Task 7 safety layer,
but fallback-path latency must be measured before MLX becomes default.

## Next Gate

Run a formal post-safety acceptance benchmark using the production MLX prompt,
`CleanupSafety`, and provider fallback chain. If it passes, switch default to
MLX while keeping Ollama fallback for one validation window.
