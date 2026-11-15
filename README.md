<img src="Icon/preview.png" width="128" alt="Ícone do LEDs do Mac: lâmpada LED acesa sobre fundo roxo">

# LEDs do Mac

Controle as luzes do seu MacBook pela barra de menus: o LED do Caps Lock, a luz do teclado e o LED do carregador MagSafe.
O app fica como uma lâmpada ao lado do relógio. Sem janela, sem ícone no Dock. Grátis e open source.

[Baixar a versão mais recente](../../releases/latest) · [Ver código](.) · [Reportar um problema](../../issues)

> Requer Mac com Apple Silicon (M1 ou mais novo) e macOS 14 ou mais novo.

## Para que serve

O macOS não deixa você mexer nessas luzes diretamente. O LEDs do Mac deixa:

- **Fixar ou apagar a luz do teclado** sem depender do sensor de luz ambiente. Por exemplo: sempre apagada para economizar bateria, ou sempre no mesmo brilho quando a luz do ambiente fica variando.
- **Usar o LED do Caps Lock como sinal**: aceso, apagado ou piscando, sem ligar o Caps Lock (o que você digita não muda).
- **Mudar a cor do LED do MagSafe**: verde, laranja ou apagado. Por exemplo: apagar a luz do carregador à noite no quarto. *(Em teste: ainda não confirmado em todos os modelos.)*

E sem pesar no Mac: parado, usa 0% de CPU e não fica verificando nada em segundo plano.

O que ele **não** faz:

- **LED da câmera:** não dá para controlar. A Apple liga essa luz direto no hardware da câmera, para ninguém conseguir filmar escondido.
- **Tecla por tecla ou cores no teclado:** a luz do teclado do MacBook é uma zona só, branca. O brilho vale para todas as teclas juntas.

## Controles

| LED | Opções | Precisa de |
|---|---|---|
| Caps Lock | Normal · Aceso · Apagado · Piscar | Permissão "Monitoramento de Entrada" (uma vez) |
| Luz do teclado | Ligar/desligar · brilho 0–100% · Automático (sensor de luz) | Nada |
| MagSafe 3 | Verde · Laranja · Apagado · Sistema | Senha de administrador a cada troca |

O MagSafe só aparece nos modelos com conector MagSafe 3. A cor ainda está em teste e pode não funcionar em todos os modelos.

## Instalação recomendada

Abra o **Terminal** (Aplicativos › Utilitários), cole esta linha e aperte Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/CelsonF/leds-do-mac/main/install.sh | zsh
```

O [instalador](install.sh) baixa a versão mais recente, coloca o app em **Aplicativos** e abre.
Para atualizar, rode a mesma linha de novo.

O download é conferido com **SHA-256** antes de instalar. Se o arquivo estiver incompleto ou alterado, o instalador para sem copiar o app.

> **Por que pelo Terminal?** O app não é notarizado pela Apple (isso exige uma conta paga de desenvolvedor).
> Baixado pelo navegador, o macOS diz que não pode verificar o app e oferece mover para o Lixo.
> Arquivos baixados pelo Terminal não recebem essa marca, então o app abre direto.

### Instalar pelo DMG

1. Baixe o `LEDs-do-Mac-<versão>.dmg` na página de [Releases](../../releases/latest).
2. Abra o arquivo e arraste **LEDs.app** para **Applications**.
3. Se o macOS bloquear a primeira abertura, vá em **Ajustes do Sistema › Privacidade e Segurança** e clique em **Abrir Mesmo Assim**.

O instalador DMG usa uma janela compacta com fundo Retina. O fundo não contém texto; os nomes dos ícones são renderizados pelo Finder e acompanham o modo Claro ou Escuro do macOS.

### Permissão do Caps Lock

Na primeira abertura, o macOS pede a permissão **Monitoramento de Entrada**: clique em
**Abrir Ajustes do Sistema**, ative "LEDs" e abra o app de novo.
Só você pode ativar essa permissão; nenhum instalador consegue fazer isso por você.

Ao atualizar, o instalador limpa a permissão antiga (que deixa de valer na versão nova) e o pedido aparece de novo.

### Instalar pelo ZIP

1. Baixe `LEDs-do-Mac.zip` na página de [Releases](../../releases/latest), descompacte e arraste `LEDs.app` para **Aplicativos**.
2. Ao abrir, o macOS bloqueia. Vá em **Ajustes do Sistema › Privacidade e Segurança**, role até o aviso sobre "LEDs" e clique em **Abrir Mesmo Assim**.
   Ou, pelo Terminal: `xattr -dr com.apple.quarantine /Applications/LEDs.app`

## Segurança e privacidade

- O código é público e o instalador valida o SHA-256 do pacote, a estrutura assinada do bundle e o identificador `local.leds-do-mac` antes de instalar.
- A permissão **Monitoramento de Entrada** serve para acessar o LED físico e observar somente mudanças dos modificadores do teclado (`flagsChanged`) quando o Caps Lock está forçado. O app não registra texto digitado e a permissão só pode ser ativada por você nos Ajustes do Sistema.
- A senha de administrador só é solicitada quando você escolhe uma cor do MagSafe. Ela é tratada pelo diálogo do próprio macOS e não é lida ou armazenada pelo app.
- O SHA-256 protege contra download corrompido ou alterado depois da publicação. Como o checksum é publicado no mesmo repositório, ele não substitui uma assinatura de identidade independente.
- Esta versão usa assinatura ad hoc para verificar a estrutura do bundle, mas ainda **não é assinada com Developer ID nem notarizada pela Apple**. A notarização exige uma conta Apple Developer e um certificado Developer ID.

## Compilar

Precisa só das Command Line Tools do Xcode (`xcode-select --install`).

```bash
./build.sh
open build/LEDs.app
```

O app é assinado ad hoc: **toda vez que recompilar**, o macOS trata como app novo e é preciso dar a permissão do Caps Lock outra vez.

Para gerar todos os arquivos de uma release, incluindo checksums:

```bash
./package-release.sh
```

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

Free, open source menu bar app to control the lights on Apple Silicon MacBooks (macOS 14+). It stays in the menu bar and can control:

- **Keyboard backlight:** turn it on or off, set a fixed brightness, or use the ambient-light sensor.
- **Caps Lock LED:** on, off or blinking, without turning Caps Lock on (your typing doesn't change). Needs the Input Monitoring permission.
- **MagSafe 3 LED:** green, orange or off, e.g. to turn off the charger light at night. Asks for the admin password. *(Beta: not yet confirmed on every model.)*

Idle, it uses 0% CPU and doesn't poll. It can't control the camera LED (Apple wires it to the camera in hardware) or individual keys (the keyboard backlight is a single white zone). MagSafe control is experimental and requires a Mac with MagSafe 3.

Install with `curl -fsSL https://raw.githubusercontent.com/CelsonF/leds-do-mac/main/install.sh | zsh`. The installer checks the published SHA-256 before installing. A DMG and ZIP are also available on the [latest release](../../releases/latest). The app is not notarized by Apple yet, so browser downloads may need the **Open Anyway** confirmation in macOS Privacy & Security.

## Licença

[MIT](LICENSE)
