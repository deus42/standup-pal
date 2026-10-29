#!/usr/bin/env bash
# Builds "StandUp Pal.app" with SwiftPM (Command Line Tools are enough, no Xcode needed).
#
#   scripts/build-app.sh            # build into ./build/StandUp Pal.app
#   scripts/build-app.sh --install  # also copy to ~/Applications and launch it
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="StandUp Pal"
EXECUTABLE="StandUpPal"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$APP_NAME.app"

cd "$ROOT"
echo "→ Compiling (release)…"
swift build -c release --product "$EXECUTABLE"
BIN="$(swift build -c release --show-bin-path)/$EXECUTABLE"

echo "→ Assembling bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$EXECUTABLE"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

echo "→ Rendering icon…"
ICON_WORK="$(mktemp -d)"
trap 'rm -rf "$ICON_WORK"' EXIT
"$BIN" --export-icon "$ICON_WORK/icon-1024.png"
ICONSET="$ICON_WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$ICON_WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$ICON_WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "→ Signing (ad-hoc)…"
codesign --force --deep --sign - --timestamp=none "$APP" >/dev/null
codesign --verify --deep --strict "$APP"

echo "✓ Built: $APP"

if [[ "${1:-}" == "--install" ]]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
  pkill -x "$EXECUTABLE" 2>/dev/null || true
  sleep 0.5
  rm -rf "$DEST/$APP_NAME.app"
  cp -R "$APP" "$DEST/"
  echo "✓ Installed: $DEST/$APP_NAME.app"
  open "$DEST/$APP_NAME.app"
fi
