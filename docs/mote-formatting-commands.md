# Mote formatting commands

Choose **Markdown (GFM)** when you want Mote to safely infer simple
Markdown structure. The formatter runs locally and falls back to Plain text if
the result is unavailable or fails its safety checks.

For code, speak just these two boundary commands:

```text
start code block yaml
end code block
```

Replace `yaml` with `json`, `bash`, `swift`, `javascript`, `typescript`, or
`python` when appropriate. Mote preserves the words between the matched
commands as one fenced block. It does not require narration of punctuation,
backticks, or every Markdown token.

An unmatched start or end command remains literal dictated text. If the source
contains code-like text or backticks that you do not want reformatted, enable
**Preserve code-like text and backticks** in Output settings.
