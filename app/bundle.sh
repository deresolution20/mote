#!/bin/zsh
# Build LocalFlow and assemble a signed .app bundle.
# A real bundle (not a bare executable) is required so TCC attributes the
# Microphone / Accessibility / Input Monitoring grants to "Local Flow" itself,
# and so NSMicrophoneUsageDescription is honored.
set -e
cd "$(dirname "$0")"

swift build -c release

APP=".build/LocalFlow.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/LocalFlow "$APP/Contents/MacOS/LocalFlow"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>dev.brice.localflow</string>
    <key>CFBundleName</key>
    <string>Local Flow</string>
    <key>CFBundleDisplayName</key>
    <string>Local Flow</string>
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
    <string>Local Flow listens while you hold the dictation hotkey. Audio never leaves this Mac.</string>
</dict>
</plist>
PLIST

# Ad-hoc signature is enough for local use; a stable identity keeps TCC grants
# sticky across rebuilds.
codesign --force --sign - "$APP"

echo "Built $PWD/$APP"
echo "Run:   open $PWD/$APP"
