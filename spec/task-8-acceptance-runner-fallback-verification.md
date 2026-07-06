# Task 8: Acceptance Runner And Fallback Verification

## Objective

Add a deterministic acceptance runner for cleanup decisions so the app can verify
primary-provider cleanup, provider fallback, and raw fallback without requiring
live MLX or Ollama in unit tests.

## Scope

- Keep Ollama as the default provider.
- When MLX is selected, try MLX first and Ollama second.
- If every provider returns `nil`, fall back to the raw transcript.
- Preserve the existing `Cleaner.clean(_:) -> String?` API for `AppState`.
- Add a structured result type that records:
  - raw transcript
  - text to paste
  - cleaned text when a provider succeeds
  - final path
  - attempted provider IDs
- Add a batch runner for acceptance samples so future acceptance work can keep
  sample IDs attached to results.

## Out Of Scope

- Making MLX the default provider.
- Removing Ollama.
- Running a live MLX/Ollama benchmark report. That remains evidence for Task 9.
- Adding user-facing provider diagnostics.

## Acceptance

- Primary provider success returns the provider-cleaned text.
- If the primary provider returns `nil`, the fallback provider is tried.
- If all providers return `nil`, the result is raw fallback.
- Empty provider lists produce raw fallback.
- Fallback providers are not called after primary success.
- The MLX provider chain is `[.mlx, .ollama]`.
- The Ollama provider chain is `[.ollama]`.
- Batch runner results preserve acceptance sample IDs.
- Focused runner tests and the full app test suite pass.
