<img src="Icon/preview.png" width="128" alt="Ícone do LEDs do Mac: lâmpada LED acesa sobre fundo roxo">

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

## Instalar

Abra o **Terminal** (Aplicativos › Utilitários), cole esta linha e aperte Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/CelsonF/leds-do-mac/main/install.sh | zsh
```

O [instalador](install.sh) baixa a versão mais recente, coloca o app em **Aplicativos** e abre.
Para atualizar, rode a mesma linha de novo.

> **Por que pelo Terminal?** O app não é notarizado pela Apple (isso exige uma conta paga de desenvolvedor).
> Baixado pelo navegador, o macOS diz que não pode verificar o app e oferece mover para o Lixo.
> Arquivos baixados pelo Terminal não recebem essa marca, então o app abre direto.

### Permissão do Caps Lock

Na primeira abertura, o macOS pede a permissão **Monitoramento de Entrada**: clique em
**Abrir Ajustes do Sistema**, ative "LEDs" e abra o app de novo.
Só você pode ativar essa permissão; nenhum instalador consegue fazer isso por você.

Ao atualizar, o instalador limpa a permissão antiga (que deixa de valer na versão nova) e o pedido aparece de novo.

### Instalar pelo .zip (alternativa)

1. Baixe `LEDs-do-Mac.zip` na página de [Releases](../../releases/latest), descompacte e arraste `LEDs.app` para **Aplicativos**.
2. Ao abrir, o macOS bloqueia. Vá em **Ajustes do Sistema › Privacidade e Segurança**, role até o aviso sobre "LEDs" e clique em **Abrir Mesmo Assim**.
   Ou, pelo Terminal: `xattr -dr com.apple.quarantine /Applications/LEDs.app`

## Compilar

Precisa só das Command Line Tools do Xcode (`xcode-select --install`).

```bash
./build.sh
open build/LEDs.app
```

O app é assinado ad hoc: **toda vez que recompilar**, o macOS trata como app novo e é preciso dar a permissão do Caps Lock outra vez.

## Como funciona

- `Sources/CapsLockLED.swift`: IOKit HID, escreve no elemento de LED (página 0x08, uso 0x02). Muda só a luz, não o estado do Caps Lock. A escrita roda numa fila em segundo plano, sem travar a interface. Nos modos Aceso/Apagado não há polling: um event tap que só escuta (`CapsLockWatcher`) avisa quando o Caps Lock muda e o app reaplica a luz, já que o sistema mexe no LED nessa hora. Também reaplica quando o Mac acorda. Parado, o app não acorda o processador.
- `Sources/KeyboardBacklight.swift`: `KeyboardBrightnessClient` do framework privado CoreBrightness. Mexer no brilho desliga o ajuste automático (senão o sensor de luz suprime a luz em ambiente claro).
- `Sources/MagSafeLED.swift`: chave SMC `ACLC` (1 byte: 0 sistema, 1 apagado, 3 verde, 4 laranja). Ler não precisa de root. Para escrever, o app pede a senha via `osascript` e roda o próprio executável com `--magsafe <valor>`, que só aceita esses 4 valores.

O ícone é desenhado em código (`Icon/make-icon.swift`, sem imagens externas). Depois de mudar o desenho, gere de novo `Resources/AppIcon.icns` e `Icon/preview.png`:

```bash
Icon/make-icon.sh
```

Diagnóstico pelo terminal:

```bash
/Applications/LEDs.app/Contents/MacOS/LEDs --status
```

Usa APIs privadas da Apple: uma atualização do macOS pode quebrar a luz do teclado ou o MagSafe.
Testado num MacBook Pro M5 com macOS 27.

## English

Menu bar app for Apple Silicon MacBooks (macOS 14+) that controls the Caps Lock LED (on, off, blink, without changing Caps Lock state), the keyboard backlight (brightness and ambient auto-adjust) and the MagSafe 3 LED color (green, orange, off, system; asks for the admin password). Install with `curl -fsSL https://raw.githubusercontent.com/CelsonF/leds-do-mac/main/install.sh | zsh` (the app is not notarized, so a browser download gets blocked by Gatekeeper), or build with `./build.sh`. The camera LED is hardware-wired and cannot be controlled.

## Licença

[MIT](LICENSE)
