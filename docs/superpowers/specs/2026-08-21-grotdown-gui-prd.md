# Grotdown GUI PRD

**Status:** Approved design, pending implementation planning
**Date:** 2026-08-21
**Product:** Grotdown, the support-engineering edition of Local Flow
**Design source:** user-provided `Local LLM Mac App.pdf`

## 1. Summary

Grotdown turns the proven Local Flow dictation pipeline into a dark-native,
menu-bar-first macOS tool for Grafana support engineers. A global hotkey starts
local capture; the existing on-device ASR and MLX cleanup pipeline produces
either plain text or GitHub-Flavored Markdown (GFM); Grotdown inserts or copies
the result and retains a local-only history.

This work is a product repositioning and rename, not a visual reskin. It keeps
the accepted local pipeline intact:

```text
global hotkey -> AVAudioEngine -> Parakeet TDT -> personal dictionary
-> MLX cleanup with terminal raw fallback -> insert or copy
```

Streaming ASR remains HUD-only until its benchmark gate promotes it as a final
transcript source. No GUI work may change that decision.

## 2. Problem and opportunity

Local Flow already has a fast, tested, local dictation core, but its UI is a
functional system menu, a generic waveform overlay, and native settings tabs.
It retains only the most recent dictation. It cannot produce Markdown, has no
support-oriented workflow, and does not expose a complete history or snippets
surface.

Support engineers need to dictate ticket replies, incident notes, and
investigation updates without sending customer data to a cloud service. They
also need results that are ready for the target: quick plain prose when that is
appropriate, or structured GFM when a response includes steps, tasks, tables,
or code.

## 3. Goals

1. Rebrand Local Flow as Grotdown across user-facing surfaces and app assets.
2. Ship the dark Grotdown visual system: five-bar orange-to-gold signal mark,
   design tokens, component states, purpose-driven motion, and concise copy.
3. Replace the menu dropdown with a 340pt capture panel and upgrade the
   existing non-activating HUD without stealing focus from the paste target.
4. Provide a local-only main window for History and Snippets.
5. Let people choose Plain text or Markdown for each dictation and set a
   persistent default.
6. Provide safe, explicit spoken controls for structure that cannot reliably
   be inferred, beginning with fenced code blocks.
7. Preserve Local Flow's core guarantees: on-device operation, raw transcript
   recovery, meaning-preserving cleanup, terminal raw fallback, and the current
   latency/accuracy contracts.

## 4. Non-goals

- A cloud service, account, sync, telemetry, or server-side storage.
- Changing ASR engines or promoting streaming ASR without benchmark evidence.
- Reintroducing Ollama, a cleanup-provider picker, or a fallback provider.
- Rich-text insertion; Markdown is inserted as raw GFM source and Plain is
  inserted as plain text.
- Editing a complete transcript in the capture HUD.
- Per-user fine-tuned writing style, collaboration, or shared snippet sync.

## 5. Users and primary jobs

**Primary user:** Grafana support engineers working in ticket systems,
incident documents, notes, and chat tools.

They need to:

- dictate a response from any focused text field without leaving that app;
- receive clean prose or GFM while keeping sensitive data on-device;
- review, copy, reuse, or save a recent result;
- correct terminology through a personal dictionary; and
- quickly understand recording, processing, insertion, and fallback states.

## 6. Experience requirements

### 6.1 Visual language

Grotdown ships dark first using these code-level tokens:

| Token | Value |
| --- | --- |
| `canvas` | `#08090B` |
| `surface` | `#16181E` |
| `surfaceRaised` | `#1B1E24` |
| `input` | `#0E1014` |
| `border` | `#2A2E37` |
| `signal` | `#F05A28` |
| `signalHover` | `#F0834A` |
| `textPrimary` | `#F4F4F6` |
| `textSecondary` | `#AEB2BB` |
| `textTertiary` | `#7E828B` |
| `success` | `#6CCF8E` |
| `danger` | `#F2495C` |
| `accentYellow` | `#FFF100` |

The signal gradient is `#FADE2A -> #F05A28`. The full gradient appears only on
dark Grotdown surfaces. The menu-bar icon is an alpha-only macOS template icon
at 16pt; the app surface uses the five-bar gradient mark. Placeholder marks
must be replaced with production vector assets before release.

Typography uses Space Grotesk for display/headings, Hanken Grotesk for body,
and Space Mono for labels, specifications, and timers. Spacing uses a 4pt base;
radii are 8/12/16/22pt; timing is 120/200/320ms with ease-out motion.

### 6.2 Menu-bar capture panel

The primary surface is a 340pt-wide panel anchored to the menu-bar icon. It
contains:

- a compact Grotdown header and local-only status;
- idle guidance showing the configured hotkey;
- recent dictations with short, bounded previews;
- a ready state with result preview, Plain/Markdown segmented control, Insert,
  and Copy actions when auto-insert is off; and
- brief, actionable insertion or copy feedback.

The panel is not a substitute for the library. It must not expose unbounded
transcripts or crowded diagnostics; those belong in the main window.

### 6.3 Capture HUD

The existing `NSPanel` overlay stays non-activating, floating, mouse-ignoring,
and focused on the target application. It is restyled as Grotdown's floating
pill and retains its current safe streaming behavior:

- recording: five-bar waveform, timer, and optional one-line raw caption tail;
- transcribing and cleanup: preserve the last raw caption tail while work runs;
- complete: show a short done/inserted indication, then fade out;
- error: show concise failure feedback without exposing transcript content.

The waveform animates only while recording. With Reduce Motion enabled, it
uses a static recording dot and cross-fade state changes instead of pulsing or
scaling.

### 6.4 Main window

An on-demand singleton Grotdown window opens from the capture panel. It uses a
sidebar-detail layout at roughly 960x580pt:

- **History:** searchable, local dictation records; a list selection reveals
  raw and final text, metadata, format, copy, insert, and save-as-snippet
  actions.
- **Snippets:** reusable local text records; users can create them from a
  history record and insert or copy them.
- **Settings:** an entry point to the dedicated macOS Settings scene, not an
  embedded settings screen.

The app remains menu-bar-first; the library does not appear at launch.

### 6.5 Settings

Settings remains a dedicated native macOS `Settings` scene with these tabs:

- **General:** privacy statement, overlay visibility, and auto-insert.
- **Model:** current fixed ASR and MLX model status; no provider selector.
- **Hotkey:** rebindable global dictation hotkey and Hold-to-talk or tap-toggle
  behavior.
- **Output:** default Plain or Markdown format, filler cleanup, code/backtick
  preservation preference, and formatting-command help.
- **Microphone:** input-device selection and live level meter.

The personal dictionary and diagnostic information remain available, reorganized
into these tabs rather than removed.

## 7. Output contract

### 7.1 Plain text

Plain retains Local Flow's current cleanup contract: remove only permitted
fillers and repetitions, improve punctuation/capitalization, preserve meaning,
and return raw text when MLX is unavailable, rejects a candidate, times out, or
errors. It is the zero-surprise format.

### 7.2 Markdown

Markdown produces valid GitHub-Flavored Markdown while preserving the dictated
meaning. It may safely infer familiar structure from natural speech, including
short headings, numbered steps, task items, and simple prose grouping. It must
not invent facts, paraphrase protected meaning, or convert a speculative
statement into a directive.

Markdown conversion is a separate, guarded formatter after the accepted
raw-transcript and cleanup stages. It snapshots the selected `OutputFormat` at
hotkey-down; a preference change during capture applies to the next dictation.
If the formatter returns an unsafe, malformed, or unavailable result, Grotdown
uses the cleaned Plain result. Raw text remains recoverable in all cases.

### 7.3 Spoken formatting commands

Natural language is the default. Explicit commands are required for ambiguity
where inference is unsafe, beginning with code blocks:

```text
start code block [language]
end code block
```

For example, “start code block YAML” opens a `yaml` fence; “end code block”
closes it. Commands are control syntax in Markdown mode, never output text.
Unknown or malformed phrases remain literal dictated content. Future explicit
commands may include Heading, Bullet, Numbered list, and Task; they are not
required for the first release unless a concrete user workflow needs them.

## 8. Persistence and insertion

### 8.1 Local library

History is a durable, local-only store in Application Support. `DictationRecord`
contains a stable ID, creation timestamp, duration, raw text, final text,
format, optional target-app metadata, and insertion outcome. `Snippet` is a
separate reusable record, not a second transcript database.

Records must be created only after a non-empty final result exists. Users can
clear history and delete individual records/snippets from the main window.

### 8.2 Insert and copy behavior

Auto-insert remains on by default. When it is off, the ready panel exposes the
result, output-format override, Insert, and Copy. The app performs a
best-effort editable-target check before insertion. If no editable target is
detectable, it copies the result and reports that precise fallback.

Grotdown must distinguish a known fallback from a successful input event; it
must never claim insertion succeeded when macOS gives no reliable proof. Direct
Unicode typing stays the default to avoid the clipboard. Clipboard paste stays
an explicit compatibility fallback and preserves/restores clipboard contents.

## 9. Technical design

### 9.1 Scene model and AppKit boundary

SwiftUI owns UI value state, selections, preferences, and rendered views. A
small `StatusItemPopoverCoordinator` is the only new AppKit bridge: it owns the
anchored status item and `NSPopover`, exposes show/dismiss events, and hosts the
SwiftUI capture-panel root. It replaces the current system menu implementation.

The existing HUD AppKit boundary remains isolated in `HUDController`. The
main library is an on-demand singleton `Window` scene opened through
`openWindow(id:)`; Settings remains a separate `Settings` scene. Per-window
selection/search state is scene-owned, not another property pile on global
`AppState`.

### 9.2 Proposed module boundaries

```text
LocalFlow/
  App/                 app entry point and scene wiring
  Views/               capture panel, HUD, library, history, snippets, settings
  Models/              OutputFormat, DictationRecord, Snippet, insertion result
  Stores/              HistoryStore, SnippetStore, preferences
  Services/            formatting-command parser, GFM formatter, status popover
  Support/             theme tokens, preview formatting, accessibility helpers
```

`AppState` remains the pipeline coordinator. It publishes a small completed
dictation result to the stores and UI; it does not own history arrays, snippet
editing, view selection, or formatting-command parsing.

### 9.3 Safety boundaries

- Keep MLX-only cleanup and terminal raw fallback unchanged.
- Keep streaming partials visual-only until benchmark promotion.
- Run formatting commands only in Markdown mode.
- Keep command parsing deterministic and separately unit-tested.
- Never persist audio, secret permission tokens, or clipboard snapshots.
- Do not add network calls to the dictation path.

## 10. Failure behavior

| Condition | Required behavior |
| --- | --- |
| Microphone or Accessibility unavailable | clear Settings path; do not begin capture |
| Streaming partial failure | retain the accepted TDT final path and phase-only HUD |
| MLX unavailable/rejected/timed out/errors | use the existing raw fallback |
| GFM formatter unsafe or unavailable | insert/store the cleaned Plain result |
| No editable target detected | copy and show a fallback toast |
| Direct insertion cannot be verified | report the attempted action honestly; retain result in History |
| Empty transcript | insert/store nothing and return to idle |

## 11. Acceptance criteria

1. Every user-facing app surface says Grotdown and uses the approved dark visual
   system; the menu-bar icon is a macOS template asset and app surfaces use the
   gradient mark.
2. The panel, HUD, library window, and Settings scene match the flows in this
   PRD without stealing focus from the receiving app during dictation.
3. Users can choose and persist Plain or Markdown, and override that choice
   before a non-auto-insert result is inserted.
4. The code-block command pair produces valid fenced GFM and is absent from the
   output text; unknown commands remain literal speech.
5. A formatting failure cannot discard or alter the safe Plain result.
6. History and Snippets survive relaunch, remain local, and support bounded
   previews plus full-detail copy/insert operations.
7. No change weakens raw fallback, MLX-only cleanup, on-device operation, or
   the existing streaming-final benchmark gate.
8. Reduce Motion, keyboard access, screen-reader labels, contrast, and focus
   behavior are tested in the final UI.
9. Existing Swift and benchmark-report tests continue to pass; new model/store,
   command-parser, and UI-state tests cover the added behavior.

## 12. Delivery shape

1. **Foundation:** rename/rebrand, icon assets, token layer, preferences and
   models, scene wiring, persistent stores, test harnesses.
2. **Capture experience:** anchored panel, Grotdown HUD, status/toast feedback,
   accessibility and reduced-motion handling.
3. **Output:** Plain/Markdown contract, deterministic command parser, guarded
   GFM formatter, insertion-result reporting.
4. **Library and settings:** History, Snippets, search/detail actions, the
   revised settings tabs, migration, and end-to-end polish.

Each delivery slice must retain a usable current dictation path. Full visual
comparison against the supplied design handoff and a real-dictation smoke test
follow each user-visible slice.

## 13. Review findings carried into the work

- The current app is MenuBarExtra plus Settings only; it has no main window or
  durable History.
- The hotkey is fixed to Left Option, while Grotdown requires a rebindable
  default of Option-Space and optional tap-toggle behavior.
- The current cleanup prompt explicitly forbids Markdown; Markdown must be an
  additive, separately tested formatter rather than a prompt wording change.
- Historical Task 14 report text still describes an Ollama fallback, but the
  current runtime and newer handoff are MLX-only. Historical evidence must be
  labelled as historical when it remains in the repository.

## 14. Decisions and assumptions

- Grotdown is the final product name and visual identity.
- Both Plain and Markdown are first-class final output formats.
- Explicit code-block commands are in the initial Markdown scope.
- The app stays menu-bar-first and opens its library only on demand.
- The default output format, hotkey, and capture mode are durable user
  preferences.
- No source code changes or commit are included in this PRD.
