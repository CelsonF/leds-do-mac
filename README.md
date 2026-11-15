<img src="Icon/preview.png" width="128" alt="Ícone do LEDs do Mac: lâmpada LED acesa sobre fundo roxo">

# LEDs do Mac

Um interruptor simples para ligar e desligar a luz do teclado do MacBook pela barra de menus.

[Baixar a versão mais recente](../../releases/latest) · [Reportar um problema](../../issues)

> Requer um Mac com Apple Silicon (M1 ou mais novo), luz de teclado integrada e macOS 14 ou mais novo.

## O que faz

Clique na lâmpada ao lado do relógio e use o único interruptor para ligar ou apagar a luz do teclado. Ao ligar, o app restaura o último brilho conhecido; se não houver um brilho salvo, usa 50%.

Não há controle de Caps Lock, MagSafe, cor, intensidade manual, senha de administrador ou permissão de Monitoramento de Entrada.

## Instalação recomendada

Abra o **Terminal** (Aplicativos › Utilitários), cole esta linha e aperte Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/CelsonF/leds-do-mac/main/install.sh | zsh
```

O [instalador](install.sh) baixa a versão mais recente, confere o SHA-256, instala o app em **Aplicativos** e o abre. Para atualizar, rode a mesma linha novamente.

### Instalar pelo DMG

1. Baixe o `LEDs-do-Mac-<versão>.dmg` na página de [Releases](../../releases/latest).
2. Abra o arquivo e arraste **LEDs.app** para **Applications**.
3. Se o macOS bloquear a primeira abertura, vá em **Ajustes do Sistema › Privacidade e Segurança** e clique em **Abrir Mesmo Assim**.

O DMG usa uma janela compacta com fundo Retina. Os nomes dos ícones são renderizados pelo Finder e acompanham o modo Claro ou Escuro do macOS.

## Segurança e privacidade

- O app acessa apenas o controle de brilho do teclado integrado. Ele não solicita acesso ao teclado, à câmera, a arquivos pessoais ou à conta de administrador.
- O instalador valida o SHA-256 do pacote, a estrutura assinada do bundle e o identificador `local.leds-do-mac` antes de instalar.
- O checksum evita instalar um download corrompido ou alterado depois da publicação. Como ele é publicado no mesmo repositório, não substitui uma assinatura de identidade independente.
- O app usa assinatura ad hoc e ainda não é assinado com Developer ID nem notarizado pela Apple. A notarização exige uma conta Apple Developer e um certificado Developer ID.

## Compilar

Precisa apenas das Command Line Tools do Xcode (`xcode-select --install`).

```bash
./build.sh
open build/LEDs.app
```

Para gerar ZIP, DMG e checksums de uma release:

```bash
./package-release.sh
```

## Como funciona

O app usa `KeyboardBrightnessClient`, do framework privado CoreBrightness do macOS, para definir o brilho da luz integrada do teclado. Ao usar o interruptor, ele desliga o ajuste automático por luz ambiente para que a escolha permaneça estável.

Por usar uma API privada da Apple, uma atualização do macOS pode afetar esse recurso. Testado em um MacBook Pro M5 com macOS 27.

## English

**LEDs do Mac** is a single menu-bar switch that turns an Apple Silicon MacBook keyboard backlight on or off. It requires macOS 14+, a built-in keyboard backlight, and uses no Input Monitoring, administrator password, camera, or personal-file access.

Install with:

```bash
curl -fsSL https://raw.githubusercontent.com/CelsonF/leds-do-mac/main/install.sh | zsh
```

The installer verifies the release SHA-256 before installation. A DMG is also available on the [latest release](../../releases/latest). The app is not notarized by Apple yet, so browser downloads may require **Open Anyway** in macOS Privacy & Security.

## Licença

[MIT](LICENSE)
