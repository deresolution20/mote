#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/.build/Mote.app"
ARCHIVE="${ARCHIVE_PATH:-$ROOT/.build/Mote-notarization.zip}"
NOTARIZE=0
source "$ROOT/Scripts/notarization.sh"

usage() {
  cat <<'USAGE'
Usage: release.sh [--notarize] [--archive PATH]

Builds a Developer ID-signed, hardened-runtime app and packages it as a zip.

Options:
  --notarize       Submit the zip to Apple's notary service, staple the ticket,
                   and run stapler/spctl validation. Requires NOTARY_PROFILE,
                   the Keychain profile created by xcrun notarytool
                   store-credentials.
  --archive PATH   Write the notarization zip to PATH.
  --help           Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --notarize)
      NOTARIZE=1
      shift
      ;;
    --archive)
      if [[ $# -lt 2 ]]; then
        echo "error: --archive requires a path" >&2
        exit 2
      fi
      ARCHIVE="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option '$1'" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if (( NOTARIZE )) && [[ -z "${NOTARY_PROFILE:-}" ]]; then
  echo "error: --notarize requires NOTARY_PROFILE to name an xcrun notarytool Keychain profile" >&2
  exit 2
fi

"$ROOT/bundle.sh" --release

package_app_archive "$APP" "$ARCHIVE"
echo "Packaged $ARCHIVE"

if (( NOTARIZE )); then
  notarize_app_archive "$APP" "$ARCHIVE" "$NOTARY_PROFILE"
  echo "Notarized and validated $APP"
  echo "Repackaged stapled app at $ARCHIVE"
fi
