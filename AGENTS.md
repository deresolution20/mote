# Mote — agent guide

Mote is an on-device macOS dictation app (Swift 6, SwiftPM, macOS 26+, Apple Silicon).
Read `README.md` for the product, `SECURITY.md` for the security posture, and
`docs/decisions.md` for why things are the way they are.

## Layout

| Path | What lives there |
| --- | --- |
| `Package.swift` | The app package (targets: `Mote`, `MoteCleanup`, `mote-cleanup-acceptance`, `mote-streaming-benchmark`, `MoteTests`) |
| `Sources/Mote/` | App: SwiftUI views, capture, permissions, stores, delivery |
| `Sources/MoteCleanup/` | MLX cleanup, safety and plausibility guards, Markdown formatting |
| `Sources/MoteCleanupAcceptance/`, `Sources/MoteStreamingBenchmark/` | CLI harnesses for acceptance and streaming benchmarks |
| `Tests/MoteTests/` | Swift Testing suites |
| `Resources/` | `Mote.entitlements` |
| `scripts/` | `bundle.sh`, `release.sh`, shell checks; helpers in `scripts/lib/` |
| `Tools/Bench/` | Separate SwiftPM package for ASR/cleanup benchmarks; voice samples in `samples/` (WAVs gitignored) |
| `docs/` | Decisions, formatting guide, `superpowers/` plans and specs, `reports/`, `history/` (original PRD, old specs, handoffs) |

## Commands (run from the repo root)

```bash
make test        # swift test
make check       # swift test + product-identity and bundle-security shell checks
make build       # swift build --product Mote
make bundle      # build and sign .build/Mote.app (development)
make bench-test  # Tools/Bench unit tests
```

## Rules

- Keep the product identity `Mote` / `dev.brice.mote`; `scripts/test-product-identity.sh` enforces it.
- New design specs and implementation plans go in `docs/superpowers/specs/` and `docs/superpowers/plans/`.
- `docs/history/` is a frozen record; do not update paths in it.
- Never commit audio samples, model files, credentials, or `reference/` clones.
