#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$PROJECT_DIR/scripts/build_plugins.sh"

BUILD_OUT="$PROJECT_DIR/build/plugins"
USER_VST3_DIR="$HOME/Library/Audio/Plug-Ins/VST3"
USER_AU_DIR="$HOME/Library/Audio/Plug-Ins/Components"

mkdir -p "$USER_VST3_DIR" "$USER_AU_DIR"

echo "=== Installing MacTrautonium.vst3 ==="
rm -rf "$USER_VST3_DIR/MacTrautonium.vst3"
cp -R "$BUILD_OUT/MacTrautonium.vst3" "$USER_VST3_DIR/"
echo "Installed to $USER_VST3_DIR/MacTrautonium.vst3"

echo "=== Installing MacTrautonium.component ==="
rm -rf "$USER_AU_DIR/MacTrautonium.component"
cp -R "$BUILD_OUT/MacTrautonium.component" "$USER_AU_DIR/"
echo "Installed to $USER_AU_DIR/MacTrautonium.component"

echo "=== Resetting AudioComponentRegistrar cache ==="
killall -9 AudioComponentRegistrar 2>/dev/null || true

echo "=== Validating Audio Unit with auval ==="
auval -v aumu mxtr Zard || {
    echo "Warning: auval exited with code $?, checking details above."
}

echo "=== Installation Complete! ==="
echo "MacTrautonium is now available in your DAWs (Logic Pro, Ableton Live, Reaper, Bitwig, Cubase, Studio One, FL Studio)."
