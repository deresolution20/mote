# Task Spec 3: Swift-Native MLX Provider Spike

## Spec Tier

This is a task spec under
`spec/phase-3-mlx-performance-reliability-hardening.md`. It follows
`spec/task-2-cleanup-benchmark-harness-integration.md`.

## Objective

Prove the Swift-native MLX integration path for Local Flow cleanup before any
production provider switch is attempted.

The task must answer one concrete question:

```text
Can Local Flow load the approved Qwen2.5 1.5B MLX model from Swift, warm it up,
run a cleanup prompt, and capture timing/output data without using oMLX, a local
server, or a Python runtime helper?
```

This task is a spike with a measurable deliverable. It does not make MLX the
default cleanup provider.

## Background

Python `mlx-lm` benchmark tooling proved that
`mlx-community/Qwen2.5-1.5B-Instruct-4bit` is worth pursuing:

- Cached model load: `0.489s`.
- Warmup: `0.180s`.
- Median cleanup latency: `0.240s`.
- p90 cleanup latency: `0.264s`.
- Cached model footprint: about `880 MB`.

That proof used Python because it was the fastest way to test model viability.
The app runtime direction remains Swift-native MLX inside the macOS app.

Official MLX Swift project facts checked for this task:

- `mlx-swift-lm` is the Swift package for LLM and VLM inference on top of MLX
  Swift.
- Package products include `MLXLLM`, `MLXLMCommon`, and `MLXHuggingFace`.
- The package supports quantized model loading.
- The current package line uses SwiftPM and targets Apple platforms, including
  macOS.
- Model loading can use Hugging Face integration or local model files.

The important unknown is whether the approved model
`mlx-community/Qwen2.5-1.5B-Instruct-4bit` is supported directly by the current
MLX Swift LM registry/configuration path, or whether Local Flow needs a custom
model configuration or a different packaging path.

## Scope

### In Scope

- Add an isolated Swift-native MLX proof target or spike entrypoint.
- Use MLX Swift / MLX Swift LM libraries where available.
- Attempt to load `mlx-community/Qwen2.5-1.5B-Instruct-4bit` from Swift.
- Determine and document the exact model loading path:
  - Built-in registry/configuration support.
  - Hugging Face based loading.
  - Local model directory loading.
  - Custom configuration requirement.
  - Hard blocker.
- Run one cleanup prompt through the Swift-native MLX path when the model loads.
- Capture timing data:
  - Dependency/model setup notes.
  - Model load seconds.
  - Warmup seconds.
  - Generation seconds.
  - Total cleanup seconds.
- Capture raw model output for the sample prompt.
- Write spike output in a machine-readable format that Task 2 and Task 1 can
  consume or summarize.
- Document the exact Swift package versions and products used.
- Keep the active app cleanup path unchanged.

### Out Of Scope

- Making MLX the default cleanup provider.
- Adding a provider selector UI.
- Adding a production provider abstraction.
- Implementing final sanitizer or plausibility guard behavior.
- Running the full acceptance suite through Swift-native MLX.
- Removing Ollama.
- Requiring oMLX.
- Requiring a local MLX HTTP server or daemon.
- Requiring Python as part of the app runtime.
- Changing ASR, audio capture, text insertion, permissions, or HUD behavior.

## Preferred Implementation Shape

The spike should be isolated from the production dictation path. Acceptable
locations are:

```text
bench/
```

or a clearly isolated SwiftPM executable/spike target that does not change
`LocalFlow` app behavior.

The preferred shape is:

```text
Swift executable target
  -> MLX Swift LM package products
  -> approved local/Hugging Face MLX model
  -> one cleanup prompt
  -> JSON + Markdown spike output
```

The app target may receive dependency declarations only when required to prove
the Swift-native integration. If package changes are made in the app package,
the implementation summary must explicitly confirm that no production cleanup
call site changed.

## Dependency Constraints

- Use official MLX Swift / MLX Swift LM packages as the primary integration
  path.
- Pin package versions through SwiftPM rather than relying on floating local
  checkouts.
- Record the package version or commit used by the spike.
- Record the Swift compiler version, Xcode version when available, and macOS
  version used for the spike run.
- Record whether the package requires a newer Swift tools version or macOS
  deployment target than Local Flow currently declares.
- Explicitly confirm whether 4-bit quantized model loading works through the
  Swift path or is the blocking issue.
- Record tokenizer setup separately from model-weight loading so tokenizer
  failures are not mistaken for inference failures.
- Do not vendor large model files into git.
- Do not add a background service, daemon, desktop companion app, or HTTP server.
- Do not add cloud inference.
- Do not add telemetry, accounts, analytics, or remote uploads.

## Input Contract

The spike must accept or define:

- The model id:
  `mlx-community/Qwen2.5-1.5B-Instruct-4bit`.
- One cleanup sample drawn from the benchmark manifest or copied exactly from a
  benchmark sample.
- A concise cleanup prompt matching the product goal:
  preserve meaning, remove obvious transcription filler, and return only the
  cleaned text.
- A local cache/model directory path when local model loading is used.

The spike does not need to expose a stable public CLI yet, but the command used
to run it must be documented in the implementation notes.

If both Hugging Face based loading and local model directory loading are
available, prefer the path that is easiest to reproduce in a fresh local checkout
and record which path was used. First-time downloads are allowed only as explicit
setup behavior; the app runtime direction remains local model files after setup.

## Output Contract

The spike must write a result file under the Task 2 benchmark/reporting world,
or an equivalent clearly named spike folder that Task 2 can consume later.

Minimum machine-readable fields:

- `task`: `swift-native-mlx-provider-spike`
- `created_at`
- `machine_context`
- `swift_toolchain`
- `mlx_swift_package`
- `mlx_swift_lm_package`
- `model_id`
- `model_source`
- `model_load_path`
- `load_seconds`
- `warmup_seconds`
- `generation_seconds`
- `total_seconds`
- `prompt`
- `raw_output`
- `cleaned_output_candidate`
- `status`
- `blockers`
- `notes`

Field formatting rules:

- `created_at` must be ISO 8601 with timezone.
- Timing values must be JSON numbers in seconds, rounded to no fewer than three
  decimal places when present.
- Fields for phases that did not execute must be `null`, not omitted.
- `blockers` and `notes` must be arrays of strings.
- `machine_context` must include macOS version and Apple Silicon chip/memory
  information when available from local system APIs.

Valid `status` values:

- `loaded_and_generated`
- `loaded_but_generation_failed`
- `model_not_supported`
- `package_or_toolchain_blocked`
- `setup_blocked`

If the model cannot load, the output must still be written with `status`,
`blockers`, package facts, and the exact failure message or summarized failure
class.

The spike must fail gracefully. A setup, tokenizer, model-load, or generation
failure should produce a non-success `status` result file and a non-zero process
exit code, not a silent pass or partial success.

## Acceptance Criteria

Task 3 is complete when all of these are true:

- A Swift-native MLX spike target or entrypoint exists.
- The spike uses MLX Swift / MLX Swift LM directly.
- The spike does not use oMLX.
- The spike does not use a local MLX server.
- The spike does not use Python as an app runtime helper.
- The spike attempts to load
  `mlx-community/Qwen2.5-1.5B-Instruct-4bit`.
- The spike records whether the model is supported directly, requires custom
  configuration, or is blocked.
- The spike records whether tokenizer loading and 4-bit quantized weight loading
  succeeded independently.
- When loading succeeds, the spike runs one cleanup prompt and records raw
  output.
- When loading fails, the spike records a clear blocker and enough package/model
  detail for the next task to make a decision.
- Timing fields are recorded for every phase that executes.
- No production dictation call site is changed.
- Ollama remains the active app cleanup path.
- The spike result can be used by Task 1 reporting or Task 2 benchmark data
  collection without manual retyping.

## Verification Plan

The implementation task must verify:

1. Run the exact Swift build command for the spike target.
2. Run the exact spike command with one cleanup sample.
3. Confirm the result file exists and parses as JSON.
4. Validate that the result JSON contains every required field and uses the
   required status vocabulary.
5. Confirm the result file contains `model_id`,
   `mlx-community/Qwen2.5-1.5B-Instruct-4bit`, `status`, package facts, and
   timing fields.
6. Confirm `created_at`, timing fields, `blockers`, and `notes` follow the output
   formatting rules.
7. If the spike status is `loaded_and_generated`, confirm `raw_output` is
   non-empty.
8. If the spike status is not `loaded_and_generated`, confirm `blockers` is
   non-empty and actionable.
9. Confirm no production cleanup call site changed in `app/Sources/LocalFlow`.
10. Run `cd bench && ./test.sh` if the `bench/` package is modified.
11. Run the relevant Swift build command for any modified app package.
12. Confirm `git diff --check` is clean.

## Risks

- The approved Qwen2.5 1.5B MLX model may not be registered by the current MLX
  Swift LM package.
- Swift model loading may need a custom configuration even though Python
  `mlx-lm` can load the same model.
- MLX Swift LM package requirements may force a Swift tools or macOS deployment
  target decision.
- Hugging Face tokenizer integration may introduce setup complexity even when
  inference itself is local.
- First-time model download behavior may require network access during setup.
- Local model cache paths may differ across machines.
- The spike may show good load/generation behavior while still producing unsafe
  cleanup text. Safety behavior remains a later task.

## Handoff To Task 4

Task 4 should create the production cleanup provider abstraction and app setting
only after Task 3 shows the viable Swift-native integration path.

If Task 3 returns `loaded_and_generated`, Task 4 can wrap the proven call shape
behind a provider interface while keeping Ollama available.

If Task 3 returns `model_not_supported` or `package_or_toolchain_blocked`, Task 4
must not build a production selector yet. The next task should first resolve the
MLX Swift model packaging or choose a different approved Swift-loadable model.

## Source References Checked

- MLX Swift: https://github.com/ml-explore/mlx-swift
- MLX Swift Examples: https://github.com/ml-explore/mlx-swift-examples
- MLX Swift LM: https://github.com/ml-explore/mlx-swift-lm
