#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAILURES=0

require_pattern() {
  local pattern="$1"
  local target_path="$2"
  local description="$3"
  if ! rg -q -- "$pattern" "$target_path"; then
    print -u2 -- "missing Mote identity: $description"
    FAILURES=$((FAILURES + 1))
  fi
}

require_absent_path() {
  local target_path="$1"
  if [[ -e "$target_path" ]]; then
    print -u2 -- "stale identity path: $target_path"
    FAILURES=$((FAILURES + 1))
  fi
}

require_pattern 'name: "Mote"' "$ROOT/Package.swift" 'Swift package/executable target'
require_pattern 'name: "MoteCleanup"' "$ROOT/Package.swift" 'cleanup module'
require_pattern 'name: "MoteTests"' "$ROOT/Package.swift" 'test target'
require_pattern 'name: "mote-cleanup-acceptance"' "$ROOT/Package.swift" 'acceptance executable'
require_pattern 'name: "mote-streaming-benchmark"' "$ROOT/Package.swift" 'streaming benchmark executable'
require_pattern 'APP="\.build/Mote\.app"' "$ROOT/scripts/bundle.sh" 'Mote.app bundle path'
require_pattern 'cp \.build/release/Mote ' "$ROOT/scripts/bundle.sh" 'Mote executable copy'
require_pattern '<string>dev\.brice\.mote</string>' "$ROOT/scripts/bundle.sh" 'bundle identifier'
require_pattern '<string>Mote</string>' "$ROOT/scripts/bundle.sh" 'bundle display name and executable'
require_pattern '<string>1\.0\.0</string>' "$ROOT/scripts/bundle.sh" 'public version 1.0.0'
require_pattern 'dev\.brice\.mote' "$ROOT/scripts/lib/signing.sh" 'signing identifier'

require_absent_path "$ROOT/Sources/LocalFlow"
require_absent_path "$ROOT/Sources/LocalFlowCleanup"
require_absent_path "$ROOT/Sources/LocalFlowCleanupAcceptance"
require_absent_path "$ROOT/Sources/LocalFlowStreamingBenchmark"
require_absent_path "$ROOT/Tests/LocalFlowTests"

require_pattern 'open \.build/Mote\.app' "$ROOT/README.md" 'README launch command'
require_pattern 'swift build --product Mote' "$ROOT/README.md" 'README Mote build product'
require_pattern 'Mote-notary' "$ROOT/README.md" 'README notarization profile'
require_pattern 'dev\.brice\.mote' "$ROOT/README.md" 'README bundle identifier'
require_absent_path "$ROOT/docs/grotdown-formatting-commands.md"
if [[ ! -f "$ROOT/docs/mote-formatting-commands.md" ]]; then
  print -u2 -- "missing Mote formatting guide"
  FAILURES=$((FAILURES + 1))
fi

STALE_DOCS="$({
  rg -n 'Grotdown|grotdown' \
    "$ROOT/README.md" \
    "$ROOT/SECURITY.md" \
    "$ROOT/docs/mote-formatting-commands.md" 2>/dev/null \
    | rg -v 'Application Support/Grotdown' || true
})"
if [[ -n "$STALE_DOCS" ]]; then
  print -u2 -- "stale public documentation identity references:"
  print -r -u2 -- "$STALE_DOCS"
  FAILURES=$((FAILURES + 1))
fi

STALE_OUTPUT="$({
  rg -n 'LocalFlow|Grotdown|grotdown|dev\.brice\.localflow' "$ROOT/Sources" "$ROOT/Tests" \
    --glob '*.swift' \
    --glob '!**/Mote/Migration/MoteV1Migration.swift' \
    --glob '!**/MoteTests/MotePreferencesTests.swift' \
    --glob '!**/MoteTests/HistoryStoreTests.swift' \
    --glob '!**/MoteTests/SnippetStoreTests.swift' || true
})"
if [[ -n "$STALE_OUTPUT" ]]; then
  print -u2 -- "stale active Swift identity references:"
  print -r -u2 -- "$STALE_OUTPUT"
  FAILURES=$((FAILURES + 1))
fi

if (( FAILURES > 0 )); then
  print -u2 -- "Mote product identity checks failed ($FAILURES groups)"
  exit 1
fi

echo "Mote product identity checks passed"
