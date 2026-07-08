# Task 6: Cleanup Provider Abstraction

## Current Status

Historical task spec. This task predates the Task 14 default-provider decision.
Its Ollama-default and MLX-opt-in acceptance bullets describe the Task 6 state,
not the current product state. Current default cleanup is MLX, with Ollama kept
as rollback/fallback.

## Objective

Add a production cleanup provider boundary so Local Flow can keep Ollama as the
default cleanup engine while allowing the approved native Swift MLX path to be
selected for validation.

## Scope

- Preserve the existing `Cleaner` API used by `AppState` and menu UI.
- Move the current Ollama implementation behind `OllamaCleanupProvider`.
- Add a selectable `MLXCleanupProvider` using MLX Swift LM and
  `mlx-community/Qwen2.5-1.5B-Instruct-4bit`.
- Select providers with `LOCALFLOW_CLEANUP_PROVIDER` first, then the
  `cleanupProvider` UserDefaults key.
- Keep `.ollama` as the fallback and production default.
- Keep MLX fail-closed: if `mlx.metallib`, model loading, or generation fails,
  return `nil` so the caller pastes raw text.
- Copy an available `mlx.metallib` into `Contents/Resources` during
  `app/bundle.sh` and expose it through a `Contents/MacOS/Resources` symlink so
  MLX's runtime lookup works without breaking codesign.

## Out of Scope

- Making MLX the default cleanup provider.
- Adding user-facing provider switching controls.
- Bundling model weights inside the app.
- Replacing the Task 7 sanitizer/plausibility acceptance work.

## Acceptance

- `Cleaner.clean(_:)`, `Cleaner.warmUp()`, `Cleaner.model`, and
  `Cleaner.keepAliveMinutes` remain available to existing call sites.
- With no override, provider selection returns `.ollama`.
- `LOCALFLOW_CLEANUP_PROVIDER=mlx` selects `.mlx`.
- `cleanupProvider=mlx` selects `.mlx` when the environment is unset.
- Invalid provider values fall back to `.ollama`.
- Provider construction does not load the MLX model eagerly.
- MLX cleanup checks for `mlx.metallib` in MLX's runtime lookup paths before
  loading.
- The app builds and provider-selection tests pass.

## Manual Use

Development run:

```zsh
LOCALFLOW_CLEANUP_PROVIDER=mlx swift run LocalFlow
```

Persistent app opt-in:

```zsh
defaults write dev.brice.localflow cleanupProvider mlx
```

Return to the default:

```zsh
defaults delete dev.brice.localflow cleanupProvider
```
