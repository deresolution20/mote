# Task 7: MLX Sanitizer And Plausibility Guard

## Current Status

Historical task spec. This task predates the Task 14 default-provider decision.
Its "keep Ollama as default" scope line describes the Task 7 state, not the
current product state. The sanitizer and plausibility guard remain part of the
current MLX-default path.

## Objective

Harden the opt-in Swift MLX cleanup provider so model output is sanitized and
meaning-checked before it can replace the raw transcript.

## Scope

- Keep Ollama as the default provider.
- Add a deterministic safety layer for MLX cleanup output.
- Strip harmless formatting artifacts when the cleaned text remains plausible.
- Reject unsafe output so the app pastes the raw transcript.
- Update the MLX prompt to discourage Markdown, labels, links, bullets,
  backticks, explanations, and assistant-style replies.

## Guard Behavior

The MLX cleanup path must reject output that:

- Adds meaningful words not present in the raw transcript.
- Drops protected markers such as `i think`, `maybe`, `probably`, `can you`,
  `we should`, attribution, or intent markers.
- Drops personal-dictionary terms.
- Contains links, Markdown links, bullets, multi-line answers, or
  assistant-style wrapper text.
- Answers the dictated text instead of cleaning it.

The MLX cleanup path may strip:

- Whole-output code fences when the body is a single safe cleaned sentence.
- Inline backticks around words that already came from the raw transcript.
- Simple labels such as `Output:` or `Cleaned text:`.

## Out Of Scope

- Making MLX the default provider.
- Removing Ollama.
- Building the full provider acceptance runner. That remains Task 8.
- Changing the ASR pipeline.

## Acceptance

- Known MLX artifact output around `GROUP BY` is sanitized when no meaning is
  added.
- Known unsafe MLX output that adds content, such as `GROUP BY clause`, is
  rejected.
- Known unsafe MLX output that changes `standup` to `the Standup` is rejected.
- Assistant-style wrapper output is rejected.
- Markdown links and URLs are rejected.
- Protected marker loss is rejected.
- Focused app tests and the full app test suite pass.
