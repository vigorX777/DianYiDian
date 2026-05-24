#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="点一点.app"
APP_DIR="$ROOT_DIR/.build/app/$APP_NAME"
DIST_DIR="$ROOT_DIR/.build/dist"
EXECUTABLE="$ROOT_DIR/.build/release/DianYiDian"
RESOURCES_DIR="$ROOT_DIR/Sources/DianYiDian/Resources"
ICONSET_DIR="$ROOT_DIR/.build/AppIcon.iconset"
ICON_FILE="$RESOURCES_DIR/AppIcon.icns"
ZIP_FILE="$DIST_DIR/点一点-0.5.0.zip"

cd "$ROOT_DIR"
swift build -c release --product DianYiDian

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$DIST_DIR"

if [[ ! -f "$ICON_FILE" && -f "$RESOURCES_DIR/AppIcon.svg" ]]; then
  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"
  qlmanage -t -s 1024 -o "$ROOT_DIR/.build" "$RESOURCES_DIR/AppIcon.svg" >/dev/null 2>&1
  SOURCE_PNG="$ROOT_DIR/.build/AppIcon.svg.png"
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$SOURCE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
    double_size=$((size * 2))
    sips -z "$double_size" "$double_size" "$SOURCE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET_DIR" -o "$ICON_FILE"
fi

cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/DianYiDian"
cp "$ROOT_DIR/Config/DianYiDian-Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ICON_FILE" "$APP_DIR/Contents/Resources/AppIcon.icns"
printf "APPL????" > "$APP_DIR/Contents/PkgInfo"
chmod +x "$APP_DIR/Contents/MacOS/DianYiDian"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$APP_DIR" >/dev/null
fi

rm -f "$ZIP_FILE"
ditto -c -k --norsrc --keepParent "$APP_DIR" "$ZIP_FILE"

echo "$APP_DIR"
echo "$ZIP_FILE"
