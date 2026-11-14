#!/bin/zsh
# Compila e empacota o LEDs.app (só precisa das Command Line Tools do Xcode).
set -euo pipefail
cd "${0:A:h}"

APP=build/LEDs.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc -O -swift-version 5 -parse-as-library \
  -target arm64-apple-macos14.0 \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/LEDs"

cp Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - --identifier local.leds-do-mac "$APP"

echo "OK: $PWD/$APP"
