#!/bin/zsh
# Cria um DMG compacto do LEDs do Mac para distribuição.
set -euo pipefail
cd "${0:A:h}"

APP="build/LEDs.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
OUTPUT="dist/LEDs-do-Mac-${VERSION}.dmg"
VOLUME="LEDs do Mac"
BACKGROUND="Resources/DMGBackground@2x.png"
BACKGROUND_NAME="DMGBackground.png"
STAGING=$(mktemp -d)
WORK=$(mktemp -d)
RW_DMG="$WORK/LEDs-do-Mac.dmg"
DEVICE=""
MOUNT=""

cleanup() {
  [[ -n "$DEVICE" ]] && hdiutil detach "$DEVICE" -force -quiet 2>/dev/null || true
  rm -rf "$STAGING"
  rm -rf "$WORK"
}
trap cleanup EXIT

[[ -d "$APP" ]] || { print -u2 "Erro: execute ./build.sh antes de criar o DMG."; exit 1; }
[[ -f "$BACKGROUND" ]] || { print -u2 "Erro: fundo do DMG não encontrado em $BACKGROUND."; exit 1; }

mkdir -p dist "$STAGING"
ditto "$APP" "$STAGING/LEDs.app"
ln -s /Applications "$STAGING/Applications"
# O Finder exibe o fundo em pontos. Esta versão de 1040 × 620 px, marcada como
# 144 DPI, ocupa 520 × 310 pt e fica nítida em telas Retina.
mkdir -p "$STAGING/background"
sips -c 620 1040 "$BACKGROUND" --out "$STAGING/background/$BACKGROUND_NAME" >/dev/null
sips --setProperty dpiWidth 144 --setProperty dpiHeight 144 "$STAGING/background/$BACKGROUND_NAME" >/dev/null
rm -f "$OUTPUT"

hdiutil create -quiet -volname "$VOLUME" -srcfolder "$STAGING" -ov -format UDRW "$RW_DMG"
ATTACH_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG")
DEVICE=$(print -r -- "$ATTACH_OUTPUT" | awk 'NR == 1 { print $1; exit }')
MOUNT=$(print -r -- "$ATTACH_OUTPUT" | awk '/\/Volumes\// { match($0, /\/Volumes\/.*/); print substr($0, RSTART, RLENGTH); exit }')
[[ -n "$DEVICE" ]] || { print -u2 "Erro: não consegui montar o DMG temporário."; exit 1; }
[[ -n "$MOUNT" ]] || { print -u2 "Erro: não encontrei o volume montado do DMG temporário."; exit 1; }
mv "$MOUNT/background" "$MOUNT/.background"

# Um DMG é uma janela do Finder, não uma página responsiva. Este tamanho cabe
# em telas compactas e a imagem tem resolução Retina para permanecer nítida.
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "LEDs do Mac"
        open
        tell container window
            set current view to icon view
            set toolbar visible to false
            set statusbar visible to false
            set bounds to {200, 180, 720, 490}
        end tell
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 88
        set background picture of viewOptions to POSIX file "$MOUNT/.background/DMGBackground.png"
        set position of item "LEDs.app" to {145, 150}
        set position of item "Applications" to {375, 150}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

hdiutil detach "$DEVICE" -quiet
DEVICE=""
hdiutil convert "$RW_DMG" -quiet -format UDZO -imagekey zlib-level=9 -o "$OUTPUT"
print "OK: $PWD/$OUTPUT"
