#!/bin/zsh
# Gera Resources/AppIcon.icns e Icon/preview.png a partir de Icon/make-icon.swift.
# Só precisa rodar de novo se mudar o desenho do ícone.
set -euo pipefail
cd "${0:A:h}/.."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

swiftc -O Icon/make-icon.swift -o "$TMP/make-icon"
"$TMP/make-icon" "$TMP/AppIcon.iconset" Icon/preview.png
mkdir -p Resources
iconutil -c icns "$TMP/AppIcon.iconset" -o Resources/AppIcon.icns

echo "OK: Resources/AppIcon.icns e Icon/preview.png"
