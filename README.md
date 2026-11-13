# LEDs do Mac

App de barra de menus (ícone de lâmpada ao lado do relógio) para controlar os LEDs do MacBook.
Sem janela, sem ícone no Dock.

| LED | Controles | Precisa de |
|---|---|---|
| Caps Lock | Normal · Aceso · Apagado · Piscar | Permissão "Monitoramento de Entrada" (uma vez) |
| Luz do teclado | Brilho 0–100% · Automático (sensor de luz) | Nada |
| MagSafe 3 | Verde · Laranja · Apagado · Sistema | Senha de administrador a cada troca |

O LED da câmera não é controlável: é ligado em hardware à câmera.
A luz do teclado é uma zona só (todas as teclas juntas, branca).

**Requisitos:** Mac com Apple Silicon (M1 ou mais novo), macOS 14 ou mais novo.
O MagSafe só aparece nos modelos com conector MagSafe 3.

## Baixar e usar

1. Baixe `LEDs-do-Mac.zip` na página de [Releases](../../releases/latest) e descompacte.
2. Arraste `LEDs.app` para a pasta **Aplicativos**.
3. Abra o app. Como ele não é notarizado pela Apple, o macOS bloqueia na primeira vez:
   vá em **Ajustes do Sistema › Privacidade e Segurança**, role até o aviso sobre "LEDs" e clique em **Abrir Mesmo Assim**.
   Ou, pelo Terminal:
   ```bash
   xattr -dr com.apple.quarantine /Applications/LEDs.app
   ```
4. Clique na lâmpada na barra de cima.

### Permissão do Caps Lock

Na primeira vez, clique em **Dar permissão…** e ative "LEDs" em
Ajustes do Sistema › Privacidade e Segurança › Monitoramento de Entrada. Depois saia e abra o app de novo.

## Compilar

Precisa só das Command Line Tools do Xcode (`xcode-select --install`).

```bash
./build.sh
open build/LEDs.app
```

O app é assinado ad hoc: **toda vez que recompilar**, o macOS trata como app novo e é preciso dar a permissão do Caps Lock outra vez.

## Como funciona

- `Sources/CapsLockLED.swift`: IOKit HID, escreve no elemento de LED (página 0x08, uso 0x02). Muda só a luz, não o estado do Caps Lock. Nos modos Aceso/Apagado reaplica a cada 1 s, porque apertar Caps Lock faz o sistema mexer no LED.
- `Sources/KeyboardBacklight.swift`: `KeyboardBrightnessClient` do framework privado CoreBrightness. Mexer no brilho desliga o ajuste automático (senão o sensor de luz suprime a luz em ambiente claro).
- `Sources/MagSafeLED.swift`: chave SMC `ACLC` (1 byte: 0 sistema, 1 apagado, 3 verde, 4 laranja). Ler não precisa de root. Para escrever, o app pede a senha via `osascript` e roda o próprio executável com `--magsafe <valor>`, que só aceita esses 4 valores.

Diagnóstico pelo terminal:

```bash
/Applications/LEDs.app/Contents/MacOS/LEDs --status
```

Usa APIs privadas da Apple: uma atualização do macOS pode quebrar a luz do teclado ou o MagSafe.
Testado num MacBook Pro M5 com macOS 27.

## English

Menu bar app for Apple Silicon MacBooks (macOS 14+) that controls the Caps Lock LED (on, off, blink, without changing Caps Lock state), the keyboard backlight (brightness and ambient auto-adjust) and the MagSafe 3 LED color (green, orange, off, system; asks for the admin password). Download the `.zip` from [Releases](../../releases/latest), or build with `./build.sh`. The camera LED is hardware-wired and cannot be controlled.

## Licença

[MIT](LICENSE)
