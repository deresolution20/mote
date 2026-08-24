#!/bin/zsh
# Build LocalFlow and assemble a signed .app bundle.
# A real bundle (not a bare executable) is required so TCC attributes the
# Microphone / Accessibility grants to "Grotdown" itself,
# and so NSMicrophoneUsageDescription is honored.
set -e
cd "$(dirname "$0")"
source "$(dirname "$0")/Scripts/metal_library.sh"

swift build -c release

APP=".build/LocalFlow.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/LocalFlow "$APP/Contents/MacOS/LocalFlow"

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
    <string>dev.brice.localflow</string>
    <key>CFBundleName</key>
    <string>Grotdown</string>
    <key>CFBundleDisplayName</key>
    <string>Grotdown</string>
    <key>CFBundleExecutable</key>
    <string>LocalFlow</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Grotdown listens while you use the dictation hotkey. Audio stays on this Mac.</string>
</dict>
</plist>
PLIST

# Prefer the stable "LocalFlow Dev" self-signed identity if it exists — it keeps
# the Accessibility grant valid across rebuilds. Ad-hoc otherwise (TCC then
# requires remove/re-add in Accessibility after every rebuild).
if security find-identity -v -p codesigning 2>/dev/null | grep -q "LocalFlow Dev"; then
  echo "signing with LocalFlow Dev identity"
  codesign --force --sign "LocalFlow Dev" --identifier "dev.brice.localflow" "$APP"
else
  echo "signing ad-hoc (create a 'LocalFlow Dev' cert in Keychain Access to stop TCC re-grants)"
  codesign --force --sign - "$APP"
fi

codesign -dvv "$APP" 2>&1 | grep -E "Identifier=|Authority=" || true

echo "Built $PWD/$APP"
echo "Run:   open $PWD/$APP"
