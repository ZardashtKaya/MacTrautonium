#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=== Building MacTrautonium Swift Packages (Release) ==="
swift build -c release

BUILD_OUT="$PROJECT_DIR/build/plugins"
mkdir -p "$BUILD_OUT"

VST3_BUNDLE="$BUILD_OUT/MacTrautonium.vst3"
AU_BUNDLE="$BUILD_OUT/MacTrautonium.component"

rm -rf "$VST3_BUNDLE" "$AU_BUNDLE"

echo "=== Packaging VST3 Plugin ==="
mkdir -p "$VST3_BUNDLE/Contents/MacOS"
mkdir -p "$VST3_BUNDLE/Contents/Resources"

clang++ -bundle -std=c++17 -fobjc-arc -arch arm64 -mmacosx-version-min=13.0 -O3 \
  -I Sources/MacTrautoniumVST3/vst3sdk -I Sources/MacTrautoniumVST3 \
  Sources/MacTrautoniumVST3/vst3sdk/pluginterfaces/base/funknown.cpp \
  Sources/MacTrautoniumVST3/MacTrautoniumVST3.mm \
  .build/release/libMacTrautoniumLib.a \
  .build/release/libTrautoniumKit.a \
  -framework Cocoa -framework AudioToolbox -framework CoreMIDI -framework AVFoundation -framework CoreGraphics -framework SwiftUI \
  -L/usr/lib/swift -lswiftCore -lswiftFoundation -lswiftAppKit -lswiftDispatch \
  -o "$VST3_BUNDLE/Contents/MacOS/MacTrautonium"

echo "BNDL????" > "$VST3_BUNDLE/Contents/PkgInfo"

cat << 'EOF' > "$VST3_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>English</string>
    <key>CFBundleExecutable</key>
    <string>MacTrautonium</string>
    <key>CFBundleIdentifier</key>
    <string>com.zard.mactrautonium.vst3</string>
    <key>CFBundleName</key>
    <string>MacTrautonium</string>
    <key>CFBundleDisplayName</key>
    <string>MacTrautonium</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

codesign -s - --force "$VST3_BUNDLE"
echo "VST3 built successfully at $VST3_BUNDLE"

echo "=== Packaging Audio Unit (.component) ==="
mkdir -p "$AU_BUNDLE/Contents/MacOS"
mkdir -p "$AU_BUNDLE/Contents/Resources"

clang++ -bundle -std=c++17 -fobjc-arc -arch arm64 -mmacosx-version-min=13.0 -O3 \
  -I Sources/MacTrautoniumVST3 \
  Sources/MacTrautoniumAU/MacTrautoniumAU.mm \
  .build/release/libMacTrautoniumLib.a \
  .build/release/libTrautoniumKit.a \
  -framework Cocoa -framework AudioToolbox -framework CoreMIDI -framework AVFoundation -framework CoreGraphics -framework SwiftUI \
  -L/usr/lib/swift -lswiftCore -lswiftFoundation -lswiftAppKit -lswiftDispatch \
  -o "$AU_BUNDLE/Contents/MacOS/MacTrautonium"

echo "BNDLaumu" > "$AU_BUNDLE/Contents/PkgInfo"

cat << 'EOF' > "$AU_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>English</string>
    <key>CFBundleExecutable</key>
    <string>MacTrautonium</string>
    <key>CFBundleIdentifier</key>
    <string>com.zard.mactrautonium.audiounit</string>
    <key>CFBundleName</key>
    <string>MacTrautonium</string>
    <key>CFBundleDisplayName</key>
    <string>MacTrautonium</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleSignature</key>
    <string>aumu</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>AudioComponents</key>
    <array>
        <dict>
            <key>name</key>
            <string>Zard: MacTrautonium</string>
            <key>description</key>
            <string>MacTrautonium Synthesizer</string>
            <key>factoryFunction</key>
            <string>MacTrautoniumAUFactory</string>
            <key>manufacturer</key>
            <string>Zard</string>
            <key>type</key>
            <string>aumu</string>
            <key>subtype</key>
            <string>mxtr</string>
            <key>version</key>
            <integer>65536</integer>
            <key>sandboxSafe</key>
            <true/>
        </dict>
    </array>
</dict>
</plist>
EOF

codesign -s - --force "$AU_BUNDLE"
echo "Audio Unit built successfully at $AU_BUNDLE"

echo "=== All plugins built successfully in $BUILD_OUT ==="
