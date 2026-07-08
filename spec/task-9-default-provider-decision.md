# Task 9: Default Provider Decision

## Current Status

Superseded by the Task 14 default-provider decision. Task 9 correctly held the
default at Ollama because the production chain had not yet been benchmarked.
Task 14 later accepted MLX as the default after the post-safety production-chain
run and Brice's manual approval of sample 17's raw fallback.

## Decision

Ollama remains the production default cleanup provider.

MLX remains opt-in through:

```zsh
LOCALFLOW_CLEANUP_PROVIDER=mlx
```

or the persistent `cleanupProvider=mlx` UserDefaults key.

When MLX is selected, the cleanup chain is:

```text
MLX -> Ollama -> raw transcript
```

## Evidence Reviewed

### Performance

The Swift-native MLX steady-state benchmark from Task 5 passed the raw latency
target:

- Model: `mlx-community/Qwen2.5-1.5B-Instruct-4bit`
- Samples: `24`
- Load: `0.950s`
- Warmup: `0.069s`
- Median repeated cleanup latency: `0.139s`
- p90 repeated cleanup latency: `0.164s`

The earlier formal MLX proof also beat Ollama on latency:

- Ollama `gemma3:4b`: median `0.914s`, p90 `1.485s`, first call `12.070s`
- MLX proof: median `0.240s`, p90 `0.264s`

### Safety And Fallback

Task 7 added deterministic MLX output safety checks:

- Strip safe code-fence and inline-code formatting artifacts.
- Reject assistant-style wrappers, links, bullets, and multi-line answers.
- Reject added meaningful words.
- Preserve protected markers and personal-dictionary terms.

Task 8 added deterministic provider fallback:

- Primary provider success uses cleaned text.
- Primary provider failure tries the fallback provider.
- All-provider failure pastes raw.
- The MLX chain is `[.mlx, .ollama]`.

## Failed Default-Switch Gate

MLX does not become the production default yet because there is not a formal
post-safety live acceptance benchmark for the production prompt, sanitizer, and
fallback chain.

The recorded Task 5 raw MLX outputs still include unsafe candidates that the
Task 7 safety layer should reject:

- `ship it Friday` -> `ship it on Friday`
- `GROUP BY` -> `` `GROUP BY` clause ``
- `remind me` -> `Remember`
- `way better` -> `much better`
- `needs the api key rotated` -> `needs to rotate the API key`

Those rejections protect meaning, but they change the user-facing latency story
when the app falls through to Ollama. The current evidence proves fast MLX raw
generation and deterministic fallback behavior. It does not yet prove that the
full production chain meets the phase p90 target while preserving meaning on the
24-reference acceptance set.

## Acceptance Gate For Switching Later

Switch the default to MLX only after a formal post-safety run proves all of the
following on the 24-reference set:

- Median user-facing cleanup latency below `0.350s`.
- p90 user-facing cleanup latency below `0.500s`.
- Zero accepted meaning changes.
- No accepted Markdown/code artifacts, links, bullets, explanations, or
  assistant-style replies.
- Unsafe MLX output falls through to Ollama or raw.
- Raw transcript remains recoverable.
- Ollama remains available as fallback for one validation window.

## Implementation Outcome

No runtime default change is made in this task. The current default selection
test remains correct: with no override, cleanup uses `.ollama`.
