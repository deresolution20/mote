# Task 4 - Swift MLX Metallib Repeatability

Date: 2026-07-06

## Purpose

Make the native Swift MLX setup reproducible by replacing the manual
`mlx.metallib` command from Task 3 with a repo-owned SwiftPM command.

## Command Added

```sh
cd bench
swift run mlx-metallib-prepare
```

The command:

- Queries `xcodebuild -showComponent MetalToolchain -json`.
- Parses `toolchainSearchPath`.
- Uses the discovered `Metal.xctoolchain/usr/bin/metal` compiler directly.
- Finds MLX Swift `.metal` sources under
  `.build/checkouts/mlx-swift/Source/Cmlx/mlx/mlx/backend/metal/kernels`.
- Writes `mlx.metallib` next to the SwiftPM debug executables.

Observed output:

```text
Metal source files: 39
Wrote: bench/.build/arm64-apple-macosx/debug/mlx.metallib
```

The generated metallib was about `142 MB`.

## Runtime Preflight

`mlx-cleanup-spike` now checks for `mlx.metallib` next to its executable before
spawning the MLX worker process. If the file is missing, the spike writes a
`package_or_toolchain_blocked` result with this action:

```sh
cd bench
swift run mlx-metallib-prepare
```

## Smoke Result

Smoke command:

```sh
cd bench
swift run mlx-cleanup-spike --output ../docs/reports/mlx-cleanup-benchmark/runs/2026-07-06-task-4-metallib-repeatability/mlx-swift-spike-result.json
```

Result:

- Status: `loaded_and_generated`
- Load: `0.963s`
- Warmup: `0.140s`
- Generation: `0.144s`
- Total: `1.246s`

Raw output:

```text
So, I think we should ship it on Friday.
```

## Verification

```sh
cd bench
./test.sh
```

Result:

```text
18 tests in 3 suites passed
```

No production app files under `app/Sources/LocalFlow` changed.
