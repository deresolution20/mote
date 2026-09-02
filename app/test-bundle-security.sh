#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$ROOT/Scripts/metal_library.sh"

if [[ ! -f "$ROOT/Scripts/signing.sh" ]]; then
  echo "signing helper is missing" >&2
  exit 1
fi
source "$ROOT/Scripts/signing.sh"

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mote-metallib-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

if find_mlx_metallib "$TEST_ROOT" >/dev/null; then
  echo "expected an empty build tree to have no Metal library" >&2
  exit 1
fi

mkdir -p "$TEST_ROOT/release"
touch "$TEST_ROOT/release/mlx.metallib"

FOUND="$(find_mlx_metallib "$TEST_ROOT")"
if [[ "$FOUND" != "$TEST_ROOT/release/mlx.metallib" ]]; then
  echo "did not select the release Metal library" >&2
  exit 1
fi

DEVELOPER_ID_OUTPUT='  1) ABCDEF0123456789ABCDEF0123456789ABCDEF01 "Developer ID Application: Mote Release (ABCDE12345)"'
RESOLVED="$(CODESIGN_IDENTITY_LIST="$DEVELOPER_ID_OUTPUT" resolve_signing_identity release)"
if [[ "$RESOLVED" != "Developer ID Application: Mote Release (ABCDE12345)" ]]; then
  echo "did not select the Developer ID Application identity" >&2
  exit 1
fi

LOCAL_ID_OUTPUT='  1) ABCDEF0123456789ABCDEF0123456789ABCDEF01 "LocalFlow Dev"'
RESOLVED="$(CODESIGN_IDENTITY_LIST="$LOCAL_ID_OUTPUT" resolve_signing_identity development)"
if [[ "$RESOLVED" != "LocalFlow Dev" ]]; then
  echo "did not select the stable development identity" >&2
  exit 1
fi

if CODESIGN_IDENTITY_LIST="$LOCAL_ID_OUTPUT" resolve_signing_identity release >/dev/null 2>"$TEST_ROOT/release-identity-error"; then
  echo "release mode accepted a development identity" >&2
  exit 1
fi

if SIGNING_IDENTITY="LocalFlow Dev" resolve_signing_identity release >/dev/null 2>"$TEST_ROOT/explicit-identity-error"; then
  echo "release mode accepted an explicit non-Developer-ID identity" >&2
  exit 1
fi

SIGNING_LOG="$TEST_ROOT/signing.log"
codesign() { print -r -- "$*" >> "$SIGNING_LOG"; }
SIGNING_IDENTITY="Developer ID Application: Mote Release (ABCDE12345)" sign_app_bundle "$TEST_ROOT/Mote.app" release
if ! rg -q -- '--options runtime .*--timestamp' "$SIGNING_LOG"; then
  echo "release signing did not enable the hardened runtime and timestamp" >&2
  exit 1
fi
if ! rg -q -- '--verify --deep --strict' "$SIGNING_LOG"; then
  echo "release signing did not run strict verification" >&2
  exit 1
fi

: > "$SIGNING_LOG"
SIGNING_IDENTITY="LocalFlow Dev" sign_app_bundle "$TEST_ROOT/Mote.app" development
if rg -q -- '--options runtime|--timestamp' "$SIGNING_LOG"; then
  echo "development signing unexpectedly enabled release-only flags" >&2
  exit 1
fi

if [[ ! -x "$ROOT/release.sh" ]]; then
  echo "release packaging script is missing or not executable" >&2
  exit 1
fi
HELP="$("$ROOT/release.sh" --help)"
if [[ "$HELP" != *"--notarize"* || "$HELP" != *"NOTARY_PROFILE"* ]]; then
  echo "release packaging help does not document notarization credentials" >&2
  exit 1
fi

NOTARY_OUTPUT="$TEST_ROOT/notary-output.txt"
if "$ROOT/release.sh" --notarize >"$NOTARY_OUTPUT" 2>&1; then
  echo "notarization mode ran without a Keychain profile" >&2
  exit 1
fi
if ! rg -q "NOTARY_PROFILE" "$NOTARY_OUTPUT"; then
  echo "notarization mode did not require NOTARY_PROFILE before building" >&2
  exit 1
fi

if [[ ! -f "$ROOT/Scripts/notarization.sh" ]]; then
  echo "notarization helper is missing" >&2
  exit 1
fi

(
  source "$ROOT/Scripts/notarization.sh"

  FAKE_APP="$TEST_ROOT/Fake.app"
  FAKE_ARCHIVE="$TEST_ROOT/Fake.zip"
  mkdir -p "$FAKE_APP/Contents"
  print -r -- "unsigned payload" > "$FAKE_APP/Contents/payload.txt"

  xcrun() {
    if [[ "$1" == "stapler" && "$2" == "staple" ]]; then
      print -r -- "ticket" > "$3/Contents/.notary-ticket"
    fi
  }
  spctl() { return 0; }

  package_app_archive "$FAKE_APP" "$FAKE_ARCHIVE"
  notarize_app_archive "$FAKE_APP" "$FAKE_ARCHIVE" "Mote-notary"

  ARCHIVE_LIST="$(unzip -l "$FAKE_ARCHIVE")"
  if [[ "$ARCHIVE_LIST" != *"Fake.app/Contents/.notary-ticket"* ]]; then
    echo "the final release archive does not include the stapled ticket" >&2
    exit 1
  fi
)

set +e
BUNDLE_USAGE_OUTPUT="$(cd "$ROOT/.." && ./app/bundle.sh --invalid 2>&1)"
BUNDLE_EXIT=$?
set -e
if [[ "$BUNDLE_EXIT" -ne 2 || "$BUNDLE_USAGE_OUTPUT" != *"usage:"* ]]; then
  echo "bundle.sh is not invokable from the repository root" >&2
  printf '%s\n' "$BUNDLE_USAGE_OUTPUT" >&2
  exit 1
fi

echo "bundle Metal library checks passed"
