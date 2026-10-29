#!/usr/bin/env bash
# Builds "StandUp Pal.app" with SwiftPM (Command Line Tools are enough, no Xcode needed).
#
#   scripts/build-app.sh               # build into ./build/StandUp Pal.app (this Mac's architecture)
#   scripts/build-app.sh --universal   # one app for Apple silicon and Intel
#   scripts/build-app.sh --install     # also copy to /Applications (or ~/Applications) and launch it
#   scripts/build-app.sh --zip         # also write ./build/StandUp-Pal-<version>.zip for a release
#   scripts/build-app.sh --dmg         # also write ./build/StandUp-Pal-<version>.dmg (drag-to-Applications installer)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="StandUp Pal"
EXECUTABLE="StandUpPal"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$APP_NAME.app"

UNIVERSAL=0
INSTALL=0
ZIP=0
DMG=0
for arg in "$@"; do
  case "$arg" in
    --universal) UNIVERSAL=1 ;;
    --install) INSTALL=1 ;;
    --zip) ZIP=1 ;;
    --dmg) DMG=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

cd "$ROOT"
mkdir -p "$BUILD_DIR"
if [[ $UNIVERSAL == 1 ]]; then
  echo "→ Compiling (release, arm64 + x86_64)…"
  BINS=()
  for triple in arm64-apple-macosx14.0 x86_64-apple-macosx14.0; do
    swift build -c release --product "$EXECUTABLE" --triple "$triple"
    # Some SwiftPM versions share one output folder across triples: copy each slice out.
    cp "$(swift build -c release --triple "$triple" --show-bin-path)/$EXECUTABLE" "$BUILD_DIR/$EXECUTABLE-$triple"
    BINS+=("$BUILD_DIR/$EXECUTABLE-$triple")
  done
  BIN="$BUILD_DIR/$EXECUTABLE-universal"
  lipo -create "${BINS[@]}" -output "$BIN"
  rm -f "${BINS[@]}"
else
  echo "→ Compiling (release)…"
  swift build -c release --product "$EXECUTABLE"
  BIN="$(swift build -c release --show-bin-path)/$EXECUTABLE"
fi

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

echo "✓ Built: $APP ($(lipo -archs "$APP/Contents/MacOS/$EXECUTABLE"))"

if [[ $ZIP == 1 ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")"
  ARCHIVE="$BUILD_DIR/StandUp-Pal-$VERSION.zip"
  rm -f "$ARCHIVE"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"
  (cd "$BUILD_DIR" && shasum -a 256 "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256")
  echo "✓ Zipped: $ARCHIVE"
fi

if [[ $DMG == 1 ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")"
  IMAGE="$BUILD_DIR/StandUp-Pal-$VERSION.dmg"
  HELP="If it won't open.txt"
  DMG_WORK="$(mktemp -d)"
  STAGE="$DMG_WORK/stage"
  mkdir -p "$STAGE" "$DMG_WORK/mount"
  ditto "$APP" "$STAGE/$APP_NAME.app"
  ln -s /Applications "$STAGE/Applications"
  cp "$ROOT/Resources/dmg-readme.txt" "$STAGE/$HELP"
  cp "$APP/Contents/Resources/AppIcon.icns" "$STAGE/.VolumeIcon.icns"
  python3 "$ROOT/scripts/dmg-layout.py" "$STAGE/.DS_Store" "$APP_NAME.app" "$HELP"
  hdiutil create -quiet -volname "$APP_NAME" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$DMG_WORK/rw.dmg"
  hdiutil attach -quiet -nobrowse -noautoopen -readwrite -mountpoint "$DMG_WORK/mount" "$DMG_WORK/rw.dmg"
  # Tell Finder the volume has a custom icon (.VolumeIcon.icns): kHasCustomIcon in FinderInfo.
  xattr -wx com.apple.FinderInfo "0000000000000000040000000000000000000000000000000000000000000000" "$DMG_WORK/mount"
  rm -rf "$DMG_WORK/mount/.fseventsd"
  hdiutil detach -quiet "$DMG_WORK/mount"
  rm -f "$IMAGE"
  hdiutil convert -quiet "$DMG_WORK/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$IMAGE"
  rm -rf "$DMG_WORK"
  (cd "$BUILD_DIR" && shasum -a 256 "$(basename "$IMAGE")" > "$(basename "$IMAGE").sha256")
  echo "✓ Disk image: $IMAGE"
fi

if [[ $INSTALL == 1 ]]; then
  # The main Applications folder when we may write there, otherwise the per-user one.
  DEST="/Applications"
  [[ -w "$DEST" ]] || DEST="$HOME/Applications"
  mkdir -p "$DEST"
  pkill -x "$EXECUTABLE" 2>/dev/null || true
  sleep 0.5
  rm -rf "$DEST/$APP_NAME.app"
  # An older copy in ~/Applications would show up as a second app.
  if [[ "$DEST" == "/Applications" && -d "$HOME/Applications/$APP_NAME.app" ]]; then
    rm -rf "$HOME/Applications/$APP_NAME.app"
  fi
  ditto "$APP" "$DEST/$APP_NAME.app"
  echo "✓ Installed: $DEST/$APP_NAME.app"
  open "$DEST/$APP_NAME.app"
fi
