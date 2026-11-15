#!/bin/zsh
# Instalador do LEDs do Mac.
#
#   curl -fsSL https://raw.githubusercontent.com/CelsonF/leds-do-mac/main/install.sh | zsh
#
# Baixa a versão mais recente do GitHub, coloca em /Applications (ou em
# ~/Applications se não der para escrever lá) e abre o app.
# Arquivos baixados pelo Terminal não recebem a marca de quarentena dos
# navegadores, então o macOS não bloqueia o app (ele não é notarizado pela Apple).
#
# Opcional, para testes: LEDS_INSTALL_DIR=/outra/pasta instala ali e não
# mexe em permissões nem em outras cópias do app.
set -euo pipefail

REPO="CelsonF/leds-do-mac"
APP="LEDs.app"
BUNDLE_ID="local.leds-do-mac"
ZIP_URL="https://github.com/$REPO/releases/latest/download/LEDs-do-Mac.zip"
SHA_URL="https://github.com/$REPO/releases/latest/download/LEDs-do-Mac.zip.sha256"

info() { print -r -- "==> $1"; }
fail() { print -r -- "Erro: $1" >&2; exit 1; }

# 1. Requisitos
[[ "$(uname -s)" == Darwin ]] || fail "o LEDs do Mac só funciona no macOS."
[[ "$(uname -m)" == arm64 ]] || fail "precisa de um Mac com Apple Silicon (M1 ou mais novo)."
macos_major=$(sw_vers -productVersion | cut -d. -f1)
(( macos_major >= 14 )) || fail "precisa do macOS 14 ou mais novo (este é o $(sw_vers -productVersion))."

# 2. Destino
if [[ -n "${LEDS_INSTALL_DIR:-}" ]]; then
  test_mode=1
  dest="$LEDS_INSTALL_DIR"
  mkdir -p "$dest"
else
  test_mode=0
  dest="/Applications"
  if [[ ! -w "$dest" ]]; then
    dest="$HOME/Applications"
    mkdir -p "$dest"
    info "Sem permissão para escrever em /Applications; instalando em $dest"
  fi
fi
target="$dest/$APP"

# 3. Download e conferência
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

info "Baixando a versão mais recente…"
curl -fL --progress-bar "$ZIP_URL" -o "$tmp/LEDs.zip" || fail "não consegui baixar $ZIP_URL"
curl -fL --silent --show-error "$SHA_URL" -o "$tmp/LEDs.zip.sha256" || fail "não consegui baixar a verificação SHA-256."
expected_hash=$(awk 'NR == 1 { print $1 }' "$tmp/LEDs.zip.sha256")
[[ "$expected_hash" =~ ^[a-fA-F0-9]{64}$ ]] || fail "o arquivo de verificação SHA-256 é inválido."
actual_hash=$(shasum -a 256 "$tmp/LEDs.zip" | awk '{ print $1 }')
[[ "$actual_hash" == "$expected_hash" ]] || fail "a verificação SHA-256 falhou; o download foi descartado."
ditto -x -k "$tmp/LEDs.zip" "$tmp/out" || fail "o arquivo baixado está corrompido."
[[ -d "$tmp/out/$APP" ]] || fail "o arquivo baixado não tem o $APP."
codesign --verify --deep --strict "$tmp/out/$APP" 2>/dev/null || fail "a assinatura do app baixado não confere."
got_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$tmp/out/$APP/Contents/Info.plist" 2>/dev/null || true)
[[ "$got_id" == "$BUNDLE_ID" ]] || fail "o app baixado não é o LEDs do Mac ($got_id)."
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$tmp/out/$APP/Contents/Info.plist")

# 4. Fecha a versão aberta antes de substituir o app.
if (( test_mode )); then
  pattern="$target/Contents/MacOS/LEDs"
else
  pattern="/$APP/Contents/MacOS/LEDs"
fi
if pkill -f "$pattern" 2>/dev/null; then
  info "Fechando a versão aberta…"
  for _ in {1..20}; do pgrep -f "$pattern" >/dev/null || break; sleep 0.1; done
fi

# 5. Instala
updating=0
[[ -d "$target" ]] && updating=1
rm -rf "$target"
ditto "$tmp/out/$APP" "$target"
xattr -dr com.apple.quarantine "$target" 2>/dev/null || true

info "LEDs do Mac $version instalado em $target"

# 6. Abre
open "$target"

cat <<'EOF'

Pronto! Procure a lâmpada na barra de cima, perto do relógio.
EOF
