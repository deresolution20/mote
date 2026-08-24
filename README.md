# Grotdown

Grotdown is a menu-bar dictation app for support engineering. It transcribes
speech and cleans text entirely on your Apple Silicon Mac, then types or copies
the result where you need it. Your voice and your text stay on this Mac;
Grotdown has no server.

## What you get

- A rebindable global hotkey — **Option-Space** by default — with hold-to-talk
  and tap-to-toggle capture modes.
- On-device Parakeet transcription and MLX-only cleanup, with the raw
  transcript as the terminal safety fallback.
- A guarded **Plain text** or **Markdown (GFM)** output choice. Markdown falls
  back to Plain whenever local formatting is unavailable or unsafe.
- Explicit spoken code blocks: say `start code block yaml`, dictate the code,
  then say `end code block`.
- A compact capture panel, non-activating recording HUD, and local History and
  Snippets library for reuse.
- Local microphone selection, a live input meter, Personal Dictionary, and
  accessible macOS Settings.
- Manual insertion is the default for a new installation. Automatic insertion
  can be enabled later; a changed target leaves the result pending rather than
  typing into a different application.

## Requirements

- macOS 26 or later
- Apple Silicon Mac
- Xcode Command Line Tools / Swift 6.3 or later
- Microphone and Accessibility permission

## Build and launch

```bash
git clone https://github.com/deresolution20/local-flow.git
cd local-flow/app
./bundle.sh
open .build/LocalFlow.app
```

On first launch, Grotdown guides you through the two required permissions.
It then requires explicit approval before downloading any local transcription or
cleanup model. The current MLX cleanup model is
`mlx-community/Qwen2.5-1.5B-Instruct-4bit`; it is not Gemma or Ollama.
For a stable Accessibility permission during development, create a local
code-signing identity named `LocalFlow Dev`; `bundle.sh` uses it when present.

## Use Grotdown

1. Focus a text field in any app.
2. Press **Option-Space** (or your configured hotkey) to dictate.
3. Use the capture panel to select Plain text or Markdown, or make that choice
   your default in Settings.
4. Open the local library from the menu-bar panel to search History, save a
   dictation as a Snippet, and copy, insert, or delete saved text.

When auto-insert is enabled, Grotdown types into an editable focused target.
If macOS cannot identify one, it copies the result instead and records that
honest outcome in History. If the focused target changes before insertion, the
result stays pending for your manual review.

## Markdown and code blocks

Markdown uses a conservative, local formatter that never invents content. For
code, speak only the boundary commands:

```text
start code block yaml
end code block
```

The body between those commands is preserved in a fenced code block. Malformed
or unmatched commands remain literal speech; see
[the formatting-command guide](docs/grotdown-formatting-commands.md).

## Privacy and runtime

The dictation path makes no network calls. Audio is processed in memory and
is not written to disk by the app. History and Snippets are versioned JSON files
in your local Application Support directory. Their directory is owner-only,
their files are owner-only and excluded from device backups, and they are not
encrypted at rest. Cleanup is native Swift MLX only; if it cannot safely return
a result, Grotdown uses the raw transcript.

Model downloads are a separate, consent-gated first-use action. Turning consent
off prevents future Grotdown-initiated model loads/downloads; it does not delete
model artifacts that supporting libraries already cached locally.

## Development checks

```bash
cd app
swift test
swift build --product LocalFlow
./bundle.sh

cd ..
python3 -m unittest discover -s docs/reports/mlx-cleanup-benchmark -p 'test_*.py'
```

Historical MLX-versus-Ollama reports remain under
[`docs/reports/mlx-cleanup-benchmark/`](docs/reports/mlx-cleanup-benchmark/).
They are benchmark evidence, not a description of Grotdown's current runtime.

## License

[MIT](LICENSE) © 2026 Brice Neal
