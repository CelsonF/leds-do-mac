<img src="Icon/preview.png" width="128" alt="Ícone do LEDs do Mac: lâmpada LED acesa sobre fundo roxo">

# LEDs do Mac

Um widget simples para controlar a luz do teclado do MacBook pela área de trabalho ou Central de Notificações.

[Baixar a versão mais recente](../../releases/latest) · [Reportar um problema](../../issues)

> Requer um Mac com Apple Silicon (M1 ou mais novo), luz de teclado integrada e macOS 14 ou mais novo.

## O que faz

O widget oferece três ações: **Ligar**, **Apagar** e **Usar luz ambiente**. O último devolve o controle ao sensor de luz do Mac. Ao ligar manualmente, o app restaura o último brilho conhecido; se não houver um brilho salvo, usa 50%.

Não há controle de Caps Lock, MagSafe, cor, intensidade manual, senha de administrador ou permissão de Monitoramento de Entrada.

### Adicionar o widget

1. Instale e abra **LEDs.app** uma vez.
2. Na área de trabalho, clique com dois dedos e escolha **Editar Widgets**. Você também pode abrir a Central de Notificações e clicar em **Editar Widgets**.
3. Procure por **LEDs do Mac** e adicione o widget pequeno onde preferir.

O macOS escolhe o local do widget; o app não adiciona widgets automaticamente.

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
- O widget só envia a ação escolhida para o app principal; ele não acessa o hardware diretamente.
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

O app usa `KeyboardBrightnessClient`, do framework privado CoreBrightness do macOS, para definir o brilho da luz integrada do teclado. Os modos Ligada e Apagada desativam o ajuste automático; Ambiente o ativa novamente. O widget usa App Intents para pedir a ação ao app principal.

Por usar uma API privada da Apple, uma atualização do macOS pode afetar esse recurso. Testado em um MacBook Pro M5 com macOS 27.

## English

**LEDs do Mac** is a small desktop and Notification Center widget for an Apple Silicon MacBook keyboard backlight: **On**, **Off**, or **Ambient**, which returns control to the Mac's light sensor. Install and open the app once, then add the widget from **Edit Widgets**. It requires macOS 14+, a built-in keyboard backlight, and uses no Input Monitoring, administrator password, camera, or personal-file access.

Install with:

```bash
curl -fsSL https://raw.githubusercontent.com/CelsonF/leds-do-mac/main/install.sh | zsh
```

The installer verifies the release SHA-256 before installation. A DMG is also available on the [latest release](../../releases/latest). The app is not notarized by Apple yet, so browser downloads may require **Open Anyway** in macOS Privacy & Security.

## Licença

[MIT](LICENSE)
