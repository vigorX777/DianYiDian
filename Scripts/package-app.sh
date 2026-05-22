#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="点一点.app"
APP_DIR="$ROOT_DIR/.build/app/$APP_NAME"
EXECUTABLE="$ROOT_DIR/.build/release/DianYiDian"

cd "$ROOT_DIR"
swift build -c release --product DianYiDian

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"

cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/DianYiDian"
cp "$ROOT_DIR/Config/DianYiDian-Info.plist" "$APP_DIR/Contents/Info.plist"
printf "APPL????" > "$APP_DIR/Contents/PkgInfo"
chmod +x "$APP_DIR/Contents/MacOS/DianYiDian"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$APP_DIR" >/dev/null
fi

echo "$APP_DIR"
