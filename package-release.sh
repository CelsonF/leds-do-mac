#!/bin/zsh
# Gera os artefatos públicos e os checksums da versão indicada no Info.plist.
set -euo pipefail
cd "${0:A:h}"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
ZIP="dist/LEDs-do-Mac.zip"

./build.sh
./make-dmg.sh
rm -f "$ZIP" "$ZIP.sha256"
ditto -c -k --sequesterRsrc --keepParent build/LEDs.app "$ZIP"
shasum -a 256 "$ZIP" > "$ZIP.sha256"
shasum -a 256 "dist/LEDs-do-Mac-${VERSION}.dmg" > "dist/LEDs-do-Mac-${VERSION}.dmg.sha256"

print "OK: artefatos da versão $VERSION em $PWD/dist"
