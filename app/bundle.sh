#!/bin/zsh
# Build Mote and assemble a signed .app bundle.
# A real bundle (not a bare executable) is required so TCC attributes the
# Microphone / Accessibility grants to "Mote" itself,
# and so NSMicrophoneUsageDescription is honored.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
source "$SCRIPT_DIR/Scripts/metal_library.sh"
source "$SCRIPT_DIR/Scripts/signing.sh"

MODE="development"
if [[ "${1:-}" == "--release" ]]; then
  MODE="release"
elif [[ -n "${1:-}" ]]; then
  echo "usage: $0 [--release]" >&2
  exit 2
fi

swift build -c release

APP=".build/Mote.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/Mote "$APP/Contents/MacOS/Mote"

METALLIB="$(find_mlx_metallib ".build" "$PWD" || true)"
if [[ -z "$METALLIB" ]]; then
  echo "error: MLX metallib not found; refusing to build a bundle with unavailable cleanup." >&2
  exit 1
fi

cp "$METALLIB" "$APP/Contents/Resources/mlx.metallib"
if [[ ! -f "$APP/Contents/Resources/mlx.metallib" ]]; then
  echo "error: failed to copy MLX metallib into the app bundle." >&2
  exit 1
fi
ln -s ../Resources "$APP/Contents/MacOS/Resources"
echo "copied MLX metallib from $METALLIB"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>dev.brice.mote</string>
    <key>CFBundleName</key>
    <string>Mote</string>
    <key>CFBundleDisplayName</key>
    <string>Mote</string>
    <key>CFBundleExecutable</key>
    <string>Mote</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Mote listens while you use the dictation hotkey. Audio stays on this Mac.</string>
</dict>
</plist>
PLIST

if [[ "$MODE" == "release" ]]; then
  echo "signing release with Developer ID Application identity"
  sign_app_bundle "$APP" release "$SCRIPT_DIR/Mote.entitlements"
else
  IDENTITY="$(resolve_signing_identity development)"
  if [[ "$IDENTITY" == "-" ]]; then
    echo "signing ad-hoc (set up 'LocalFlow Dev' to preserve TCC grants across rebuilds)"
  else
    echo "signing development with $IDENTITY"
  fi
  sign_app_bundle "$APP" development "$SCRIPT_DIR/Mote.entitlements"
fi

codesign -dvv "$APP" 2>&1 | grep -E "Identifier=|Authority=|TeamIdentifier=" || true

echo "Built $PWD/$APP"
echo "Run:   open $PWD/$APP"
