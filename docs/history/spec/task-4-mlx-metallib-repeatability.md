# Task Spec 4: Swift MLX Metallib Repeatability

## Spec Tier

This is a task spec under
`spec/phase-3-mlx-performance-reliability-hardening.md`. It follows
`spec/task-3-swift-native-mlx-provider-spike.md`.

## Objective

Make the native Swift MLX spike reproducible without a manually generated
`mlx.metallib` file.

The task must answer one concrete question:

```text
Can a fresh local checkout prepare the MLX Metal shader library through a
repo-owned command and then run the Swift MLX cleanup spike without manual
compiler-path copying?
```

## Scope

### In Scope

- Add a repeatable repo-owned command for building `mlx.metallib`.
- Discover the installed Apple Metal Toolchain from
  `xcodebuild -showComponent MetalToolchain -json`.
- Use the discovered `toolchainSearchPath` instead of hardcoding the mounted
  cryptex path.
- Discover MLX Swift Metal kernel sources from the SwiftPM `mlx-swift` checkout.
- Write `mlx.metallib` next to the SwiftPM executable output directory.
- Add an actionable runtime preflight for the Swift MLX spike when
  `mlx.metallib` is missing.
- Keep production app cleanup behavior unchanged.

### Out Of Scope

- Full repeated-call performance benchmarking.
- Making MLX the default provider.
- Adding provider selection UI.
- Integrating MLX into the production app pipeline.
- Removing Ollama.
- Requiring oMLX, a local server, or a Python runtime helper.

## Acceptance Criteria

- `bench` exposes `swift run mlx-metallib-prepare`.
- The command locates the installed Metal Toolchain through Xcode component JSON.
- The command compiles MLX Swift `.metal` kernel sources into `mlx.metallib`.
- The command writes `mlx.metallib` next to the SwiftPM debug executables.
- `swift run mlx-cleanup-spike` can run after the preparation command.
- If `mlx.metallib` is absent, the spike writes an actionable blocker instead of
  relying on an MLX abort.
- Unit tests cover the parser, path layout, source discovery, compiler plan, and
  runtime preflight.
- `cd bench && ./test.sh` passes.
- No production code in `app/Sources/LocalFlow` changes.

## Verification Plan

1. Run `cd bench && ./test.sh`.
2. Run `cd bench && swift run mlx-metallib-prepare`.
3. Confirm `bench/.build/arm64-apple-macosx/debug/mlx.metallib` exists.
4. Run `cd bench && swift run mlx-cleanup-spike --output <task-4-run-json>`.
5. Confirm the result JSON exists, parses, and reports `loaded_and_generated`.
6. Confirm `git diff -- app/Sources/LocalFlow` is empty.
7. Confirm `git diff --check` is clean.
