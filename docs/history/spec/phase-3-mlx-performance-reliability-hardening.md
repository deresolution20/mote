# Phase 3 Spec: MLX Performance And Reliability Hardening

## Current Status

Task 14 completed the default-provider decision. MLX is now the accepted default
cleanup provider after the 2026-07-08 production-chain acceptance run and
manual approval of sample 17's raw fallback. A follow-up cleanup removed the
hidden Ollama rollback/fallback path, so raw transcript is now the only terminal
safety fallback after MLX.

## Spec Tier

This is a phase spec. It sits below the Local Flow product definition and above
future task specs. It defines one finishable chunk of work: making cleanup faster
and safer without changing the core product promise.

## Objective

Add a production-ready MLX cleanup path for Local Flow so post-ASR text cleanup
is faster, more predictable, and still fully local. MLX must not weaken the
existing privacy, raw fallback, or meaning-preservation guarantees. This phase
is now implemented through the accepted MLX-only runtime.

The current app remains a native macOS menu-bar dictation tool:

1. Hold Left Option.
2. Capture microphone audio through AVAudioEngine.
3. Transcribe locally with FluidAudio Parakeet v3.
4. Clean text locally.
5. Insert text by direct Unicode typing by default.

This phase changes only the cleanup and benchmark/reporting layer.

## Background And Evidence

The earlier cleanup path used Ollama with `gemma3:4b` over localhost. It was
fully local, but the cleanup hop was the dominant latency source.

Measured Ollama baseline from the existing cleanup benchmark:

- Model: `gemma3:4b`
- Median cleanup latency: `0.914s`
- p90 cleanup latency: `1.485s`
- Cold first call: `12.070s`
- Runtime model footprint: about `3.3 GB`

Approved MLX candidate:

- Model: `mlx-community/Qwen2.5-1.5B-Instruct-4bit`
- License: Apache-2.0
- Cached model footprint: about `880 MB`
- Integration target: Swift-native MLX / MLX Swift inside the app
- Benchmark/proof tooling used Python `mlx-lm`, but Python is not the app
  runtime target.

Measured MLX proof result after unloading a resident 30B model:

- Cached load: `0.489s`
- Warmup: `0.180s`
- Median cleanup latency: `0.240s`
- p90 cleanup latency: `0.264s`

Showpiece research reports were generated from this spike:

- `docs/reports/local-flow-mlx-cleanup-benchmark.pdf`
- `docs/reports/local-flow-mlx-cleanup-benchmark.docx`

The result justified a focused hardening phase. Later Task 14 evidence and
manual review accepted MLX as the production cleanup provider, with raw fallback
for rejected or unavailable output.

## Scope

### In Scope

- Add an MLX cleanup provider that can run without an external desktop app,
  local server, or daemon.
- Bias implementation toward Swift-native MLX / MLX Swift in the app.
- Keep Python `mlx-lm` only for benchmark/proof tooling when useful.
- Use MLX as the production cleanup provider after acceptance.
- Add deterministic output safety checks for MLX cleanup:
  - Strip Markdown/code formatting from cleanup output.
  - Reject added words or added content.
  - Preserve protected markers such as hedges, requests, attribution, intent,
    and personal-dictionary terms.
  - Fall back to raw transcript when output is unsafe.
- Extend formal benchmark runs to emit portfolio-grade reports, not just raw
  timing output.
- Store benchmark reporting code and generated runs under
  `docs/reports/mlx-cleanup-benchmark/`.
- Track memory-pressure context in benchmark reports, because the 30B-model
  unload changed p90 from `0.473s` to `0.264s`.

### Out Of Scope

- Streaming partial transcripts in the HUD.
- Per-app context modes or style presets.
- Replacing FluidAudio Parakeet or changing ASR strategy.
- UI redesign.
- Reintroducing provider selection or Ollama rollback without a new task spec.
- Requiring oMLX, a local MLX server, or any external app as part of the product
  runtime.

## Runtime Direction

The app runtime target is:

```text
Local Flow app -> Swift-native MLX integration -> local Qwen2.5 1.5B model files
```

The app runtime must not become:

```text
Local Flow app -> external oMLX app
Local Flow app -> local MLX HTTP server
Local Flow app -> Python virtualenv helper
```

Task specs may use Python `mlx-lm` for benchmark reproduction, report generation,
or one-off model investigation. Production code should keep the app as
self-contained as practical for a local macOS source build.

## Benchmark Reporting Requirement

Formal cleanup benchmark runs must generate human-readable evidence every time
they are run. The reporting system belongs in its own folder:

```text
docs/reports/mlx-cleanup-benchmark/
  README.md
  generate_report.py
  assets/
  runs/
    YYYY-MM-DD-<short-run-name>/
      report.pdf
      report.docx
      raw-ollama-cleanup.md
      raw-mlx-cleanup.md
      charts/
```

The exact command name should be defined in the first task spec, but the user
experience must be one explicit benchmark/report command for a formal run.

Each run report must include:

- Benchmark date and machine/runtime context.
- Model names and footprints.
- Median and p90 cleanup latency.
- Cold load or warmup observations where measured.
- Per-sample latency visualization.
- Quality notes for meaning preservation and output artifacts.
- The acceptance decision: pass, fail, or inconclusive.
- Raw benchmark outputs for auditability.

## Acceptance Criteria

MLX cleanup became the accepted provider after these criteria were satisfied:

- Median cleanup latency is below `0.350s` on the 24-reference acceptance set.
- p90 cleanup latency is below `0.500s` on the same set.
- There are zero meaning changes on the acceptance set.
- Cleanup output contains no Markdown artifacts, code formatting, links, bullets,
  explanations, or assistant-style replies.
- Protected phrases and markers survive cleanup.
- Unsafe cleanup output falls back to raw text.
- The dictation path has no non-local network dependency.
- A formal benchmark run produces PDF, DOCX, chart assets, and raw outputs under
  `docs/reports/mlx-cleanup-benchmark/runs/`.

## Non-Negotiable Rules

- The dictation path stays local-only.
- Do not add cloud inference, telemetry, accounts, analytics, or remote cleanup.
- Keep the two-permission model: Microphone and Accessibility only.
- Keep direct Unicode typing as the default insertion method.
- Always keep the raw transcript recoverable.
- Cleanup must preserve meaning over polish.
- If cleanup output is questionable, paste raw.
- Do not reintroduce Ollama/provider rollback without a task spec and acceptance
  evidence.

## Quality Risks

The MLX proof run showed strong latency but also showed output issues that task
specs must handle:

- `GROUP BY` was wrapped in backticks.
- `standup` became `the Standup`.
- Some filler words were retained where Ollama cleaned more aggressively.

These are acceptable research findings, not acceptable production behavior. The
phase succeeds only if the safety layer either corrects or rejects this class of
output.

## Suggested Task-Spec Split

Future task specs should be small enough to implement and verify independently:

1. Benchmark reporting system under `docs/reports/mlx-cleanup-benchmark/`.
2. Cleanup benchmark harness changes to produce raw MLX and historical Ollama
   comparison results.
3. Swift-native MLX provider spike with model load, warmup, and one cleanup call.
4. Swift MLX metallib discovery/build/copy repeatability.
5. Repeated Swift MLX cleanup benchmark in one process, excluding one-time load
   and warmup.
6. Provider abstraction, later simplified to the accepted MLX-only runtime.
7. MLX prompt, sanitizer, and plausibility guard.
8. Acceptance runner with raw fallback verification.
9. Final default-provider decision based on benchmark evidence.

Task specs should preserve this order unless a later discovery shows a real
dependency problem.
