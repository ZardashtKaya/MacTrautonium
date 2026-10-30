#!/bin/bash
set -e

echo "=== Building MacTrautonium (Release) ==="
swift build -c release

APP_DIR="build/MacTrautonium.app"
BIN_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

echo "=== Packaging into $APP_DIR ==="
rm -rf "$APP_DIR"
mkdir -p "$BIN_DIR"
mkdir -p "$RES_DIR"

BIN_PATH=$(swift build -c release --show-bin-path)/MacTrautonium
cp "$BIN_PATH" "$BIN_DIR/MacTrautonium"
cp Info.plist "$APP_DIR/Contents/Info.plist"

echo "=== Codesigning locally ==="
codesign --force --deep --sign - "$APP_DIR"

echo "=== Done! ==="
echo "Application created at: $APP_DIR"
echo "You can launch it with: open $APP_DIR"
