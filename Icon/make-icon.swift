// Desenha o ícone do app (lâmpada LED em degradê sobre fundo roxo) e gera
// o AppIcon.iconset com todos os tamanhos do macOS + uma prévia em PNG.
// Uso: rode Icon/make-icon.sh (compila isto e converte com iconutil).
import AppKit

// Desenho em espaço 1024x1024 (origem embaixo à esquerda). S = escala atual,
// usada só em sombras (NSShadow ignora a transformação).
var S: CGFloat = 1

func hex(_ v: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255,
            blue: CGFloat(v & 0xff) / 255, alpha: a)
}

func shadow(_ c: NSColor, blur: CGFloat, dy: CGFloat = 0) -> NSShadow {
    let s = NSShadow()
    s.shadowColor = c
    s.shadowBlurRadius = blur * S
    s.shadowOffset = NSSize(width: 0, height: dy * S)
    return s
}

func glow(_ c: NSColor, at p: NSPoint, radius r: CGFloat, alpha a: CGFloat) {
    let g = NSGradient(colors: [c.withAlphaComponent(a), c.withAlphaComponent(a * 0.4), c.withAlphaComponent(0)],
                       atLocations: [0, 0.4, 1], colorSpace: .sRGB)!
    g.draw(fromCenter: p, radius: 0, toCenter: p, radius: r, options: [])
}

/// Forma padrão de ícone do macOS: 824x824 com margem de 100 no quadro de 1024.
func bodyPath() -> NSBezierPath {
    NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
}

func drawIcon() {
    let body = bodyPath()

    // sombra do ícone + fundo roxo em degradê
    NSGraphicsContext.saveGraphicsState()
    shadow(hex(0x000000, 0.35), blur: 28, dy: -14).set()
    hex(0x0A0A1C).setFill(); body.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: hex(0x33206E), ending: hex(0x0A0A1C))!.draw(in: body, angle: -90)

    NSGraphicsContext.saveGraphicsState()
    body.addClip()

    // luz quente da lâmpada iluminando o fundo
    glow(hex(0xFFB547), at: NSPoint(x: 512, y: 590), radius: 440, alpha: 0.50)

    // lâmpada: símbolo SF pintado com degradê (amarelo claro → laranja)
    let name = NSImage(systemSymbolName: "lightbulb.led.fill", accessibilityDescription: nil) != nil
        ? "lightbulb.led.fill" : "lightbulb.fill"
    let sym = NSImage(systemSymbolName: name, accessibilityDescription: nil)!
        .withSymbolConfiguration(.init(pointSize: 520, weight: .regular))!
    let tinted = NSImage(size: sym.size, flipped: false) { r in
        sym.draw(in: r)
        NSGraphicsContext.current?.compositingOperation = .sourceIn
        NSGradient(colors: [hex(0xFFF6C2), hex(0xFFC845), hex(0xFF7A3D)],
                   atLocations: [0, 0.5, 1], colorSpace: .sRGB)!.draw(in: r, angle: -90)
        return true
    }
    let h: CGFloat = 560, w = sym.size.width * h / sym.size.height
    NSGraphicsContext.saveGraphicsState()
    shadow(hex(0xFFB547, 0.8), blur: 50).set()
    tinted.draw(in: NSRect(x: 512 - w / 2, y: 512 - h / 2, width: w, height: h))
    NSGraphicsContext.restoreGraphicsState()

    // borda interna sutil: ajuda o ícone a se destacar em fundo escuro (Dock no modo escuro)
    hex(0xFFFFFF, 0.08).setStroke()
    body.lineWidth = 6
    body.stroke()

    NSGraphicsContext.restoreGraphicsState()
}

func render(_ px: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high
    NSColor.clear.set(); NSRect(x: 0, y: 0, width: px, height: px).fill(using: .copy)
    S = CGFloat(px) / 1024
    let t = NSAffineTransform(); t.scale(by: S); t.concat()
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func save(_ rep: NSBitmapImageRep, _ path: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("uso: make-icon <saida.iconset> <previa.png>\n".data(using: .utf8)!)
    exit(2)
}
let iconset = args[1]
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

// Cada tamanho é desenhado do zero (vetorial), não reduzido de uma imagem grande.
for base in [16, 32, 128, 256, 512] {
    save(render(base), "\(iconset)/icon_\(base)x\(base).png")
    save(render(base * 2), "\(iconset)/icon_\(base)x\(base)@2x.png")
}
save(render(256), args[2])
print("ok")
