# Task 3 - Swift Native MLX Provider Spike

Date: 2026-07-06

## Purpose

Validate whether Local Flow can load the approved cleanup model through native Swift MLX before integrating MLX into the app runtime.

Approved model:

`mlx-community/Qwen2.5-1.5B-Instruct-4bit`

Native package path tested:

- `mlx-swift-lm` 3.31.4
- `mlx-swift` 0.31.6
- `LLMRegistry.qwen2_5_1_5b`
- `LLMModelFactory.shared.loadContainer(from:using:configuration:)`

## Commands

Toolchain setup:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -downloadComponent MetalToolchain
xcodebuild -showComponent MetalToolchain -json
```

Manual metallib build:

```sh
/private/var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain-v17.6.109.0.Y9Y3BE/Metal.xctoolchain/usr/bin/metal \
  -Wall -Wextra -fno-fast-math -Wno-c++17-extensions \
  -I bench/.build/checkouts/mlx-swift/Source/Cmlx/mlx \
  -I bench/.build/checkouts/mlx-swift/Source/Cmlx/mlx/mlx/backend/metal/kernels \
  $(find bench/.build/checkouts/mlx-swift/Source/Cmlx/mlx/mlx/backend/metal/kernels -name '*.metal' -print) \
  -o bench/.build/arm64-apple-macosx/debug/mlx.metallib
```

Swift tests:

```sh
cd bench
./test.sh
```

Spike run:

```sh
cd bench
swift run mlx-cleanup-spike --output ../docs/reports/mlx-cleanup-benchmark/runs/2026-07-06-task-3-swift-native-mlx-spike/mlx-swift-spike-result.json
```

Manual metallib check:

```sh
xcrun -sdk macosx metal ...
```

Observed result:

```text
xcrun: error: unable to find utility "metal", not a developer tool or in PATH
```

After full Xcode and the MetalToolchain component were installed, `xcrun` still
failed to activate the compiler wrapper. The direct mounted compiler path worked
and produced:

```text
bench/.build/arm64-apple-macosx/debug/mlx.metallib
```

## Result

The Swift package integration builds, tests pass, and the native Swift MLX spike
loads the approved model after `mlx.metallib` is colocated with the spike
executable.

Final status:

```text
loaded_and_generated
```

Recorded timings:

- Load: `1.017s`
- Warmup: `1.334s`
- Generation: `0.141s`
- Total: `2.492s`

Raw output:

```text
So, I think we should ship it on Friday.
```

## Decision

Native Swift MLX is viable for the approved model. Do not integrate it into the
production app pipeline until the Metal shader library packaging story is made
repeatable for a fresh checkout.

The next implementation task should decide whether to:

- add a deterministic build step that generates/copies `mlx.metallib`, or
- find the supported SwiftPM resource path that lets `mlx-swift` discover
  `default.metallib` without a manual colocated file.

The output changed `friday` to `on Friday`, which is acceptable for this spike
but confirms that production integration still needs the planned cleanup
quality guardrails.
