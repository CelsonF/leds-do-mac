#!/bin/zsh
# Compila e empacota o LEDs.app (só precisa das Command Line Tools do Xcode).
set -euo pipefail
cd "${0:A:h}"

APP=build/LEDs.app
WIDGET="$APP/Contents/PlugIns/LEDsWidget.appex"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Info.plist)
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc -O -swift-version 5 -parse-as-library \
  -target arm64-apple-macos26.0 \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/LEDs"

cp Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# O widget é uma extensão separada. Ele mostra os botões; a ação é executada
# pelo App Intent no app principal, que é o único processo com acesso ao brilho.
mkdir -p "$WIDGET/Contents/MacOS"
swiftc -O -swift-version 5 -parse-as-library \
  -target arm64-apple-macos26.0 \
  Sources/KeyboardBacklight.swift \
  Sources/KeyboardLightControl.swift \
  Sources/KeyboardLightIntent.swift \
  WidgetExtension/KeyboardLightControlWidget.swift \
  -o "$WIDGET/Contents/MacOS/LEDsWidget"
cp WidgetExtension/Info.plist "$WIDGET/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$WIDGET/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$WIDGET/Contents/Info.plist"
codesign --force --sign - --entitlements WidgetExtension/LEDsWidget.entitlements "$WIDGET"

codesign --force --sign - --identifier local.leds-do-mac --entitlements LEDsApp.entitlements "$APP"

echo "OK: $PWD/$APP"
