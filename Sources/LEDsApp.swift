import AppKit
import IOKit.hid
import ServiceManagement
import SwiftUI

// MARK: - Entrada

@main
enum Entry {
    @MainActor
    static func main() {
        let args = CommandLine.arguments
        // Usado internamente para escrever no SMC como root (ver MagSafeLED.set).
        if let i = args.firstIndex(of: "--magsafe"), i + 1 < args.count {
            exit(MagSafeLED.runCLI(args[i + 1]))
        }
        if args.contains("--status") {
            printStatus()
            exit(0)
        }
        LEDsApp.main()
    }

    static func printStatus() {
        let k = KeyboardBacklight(), c = CapsLockLED(), m = MagSafeLED()
        print("teclado:  disponível=\(k.isAvailable) brilho=\(k.brightness) auto=\(k.autoBrightness)")
        print("capslock: permissão=\(c.hasAccess) capsLigado=\(c.capsLockIsOn)")
        let cur = m.current.map { String(format: "0x%02X", $0) } ?? "-"
        print("magsafe:  suportado=\(m.isSupported) atual=\(cur) naTomada=\(m.isOnAC)")
    }
}

struct LEDsApp: App {
    @StateObject private var model = LEDModel()

    var body: some Scene {
        MenuBarExtra {
            PanelView().environmentObject(model)
        } label: {
            Image(systemName: NSImage(systemSymbolName: "lightbulb.led.fill", accessibilityDescription: nil) != nil
                  ? "lightbulb.led.fill" : "lightbulb.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Estado

enum CapsMode: String, CaseIterable, Identifiable {
    case auto = "Normal", on = "Aceso", off = "Apagado", blink = "Piscar"
    var id: Self { self }
}

@MainActor
final class LEDModel: ObservableObject {
    let caps = CapsLockLED()
    let keyboard = KeyboardBacklight()
    let magsafe = MagSafeLED()

    @Published var capsMode: CapsMode = .auto
    @Published var capsHasAccess = false
    @Published var capsMessage: String?

    @Published var kbdLevel: Double = 0
    @Published var kbdAuto = false
    @Published var kbdEnabled = false
    private var lastKeyboardLevel: Double = 0.5

    @Published var magsafeSupported = false
    @Published var magsafeCurrent: UInt8?
    @Published var onAC = false
    @Published var magsafeBusy = false
    @Published var magsafeMessage: String?

    @Published var launchAtLogin = false
    @Published var loginMessage: String?

    private var blinkTimer: Timer?
    private var blinkPhase = false
    private var capsWatcher: CapsLockWatcher?
    private var wakeObserver: NSObjectProtocol?
    /// Muda a cada troca de modo; reaplicações agendadas de um modo antigo se descartam.
    private var capsGeneration = 0
    private var sigtermSource: DispatchSourceSignal?

    init() {
        refresh()
        if caps.hasAccess {
            caps.prepare()
        } else if caps.accessNotAsked {
            // Primeira abertura: o próprio macOS mostra o pedido de
            // "Monitoramento de Entrada" (só o usuário pode ativar).
            caps.requestAccess()
        }
        // Qualquer forma de sair (botão, Cmd+Q, logout) devolve o LED ao normal.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.cleanUpCaps() }
        }
        // O instalador fecha o app com SIGTERM ao atualizar: trata como saída normal.
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { NSApp.terminate(nil) }
        source.resume()
        sigtermSource = source
    }

    func refresh() {
        capsHasAccess = caps.hasAccess
        if keyboard.isAvailable {
            kbdLevel = Double(keyboard.brightness)
            kbdAuto = keyboard.autoBrightness
            kbdEnabled = kbdLevel > 0.001
            if kbdEnabled { lastKeyboardLevel = kbdLevel }
        }
        magsafeSupported = magsafe.isSupported
        magsafeCurrent = magsafe.current
        onAC = magsafe.isOnAC
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // Caps Lock

    func requestCapsAccess() {
        if caps.accessNotAsked {
            caps.requestAccess() // mostra o pedido do sistema
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
        refresh()
    }

    func setCapsMode(_ mode: CapsMode) {
        stopCapsActivity()
        capsMessage = nil
        capsMode = mode
        let generation = capsGeneration
        let report: @MainActor (Bool) -> Void = { [weak self] ok in
            self?.capsWriteFinished(ok, generation: generation)
        }

        switch mode {
        case .auto:
            caps.setLED(caps.capsLockIsOn, completion: report)

        case .on, .off:
            caps.setLED(mode == .on, completion: report)
            // Sem polling: só reaplica quando o Caps Lock muda (o sistema mexe no LED)
            // ou quando o Mac acorda.
            capsWatcher = CapsLockWatcher { [weak self] _ in self?.reapplyForcedLED() }
            if capsWatcher == nil {
                capsMessage = "Aviso: ao apertar Caps Lock o LED pode voltar ao normal."
            }
            wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.reapplyForcedLED() }
            }

        case .blink:
            blinkPhase = true
            caps.setLED(true, completion: report)
            let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.blinkPhase.toggle()
                    self.caps.setLED(self.blinkPhase)
                }
            }
            // Folga de 10%: o macOS pode agrupar este despertar com outros.
            timer.tolerance = 0.04
            RunLoop.main.add(timer, forMode: .common)
            blinkTimer = timer
        }
    }

    private func capsWriteFinished(_ ok: Bool, generation: Int) {
        guard !ok, generation == capsGeneration else { return }
        stopCapsActivity()
        capsMode = .auto
        capsMessage = "Não consegui acessar o teclado. Se acabou de dar a permissão, saia e abra o app de novo."
    }

    /// O sistema atualiza o LED logo depois da mudança do Caps Lock; reaplica um
    /// pouco depois (duas vezes, para não perder a corrida com ele).
    private func reapplyForcedLED() {
        guard capsMode == .on || capsMode == .off else { return }
        let on = capsMode == .on
        let generation = capsGeneration
        for delay in [0.1, 0.4] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, generation == self.capsGeneration else { return }
                self.caps.setLED(on)
            }
        }
    }

    private func stopCapsActivity() {
        capsGeneration += 1
        blinkTimer?.invalidate()
        blinkTimer = nil
        capsWatcher = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        wakeObserver = nil
    }

    private func cleanUpCaps() {
        let wasForced = capsMode != .auto
        stopCapsActivity()
        if wasForced {
            capsMode = .auto
            caps.restoreNow()
        }
    }

    // Teclado

    func setKeyboard(_ value: Double) {
        if kbdAuto {
            keyboard.setAutoBrightness(false)
            kbdAuto = false
        }
        kbdLevel = value
        kbdEnabled = value > 0.001
        if kbdEnabled { lastKeyboardLevel = value }
        keyboard.setBrightness(Float(value))
    }

    func setKeyboardEnabled(_ enabled: Bool) {
        guard keyboard.isAvailable else { return }
        if enabled {
            let level = lastKeyboardLevel > 0.001 ? lastKeyboardLevel : 0.5
            setKeyboard(level)
        } else {
            if kbdLevel > 0.001 { lastKeyboardLevel = kbdLevel }
            if kbdAuto {
                keyboard.setAutoBrightness(false)
                kbdAuto = false
            }
            keyboard.setBrightness(0)
            kbdLevel = 0
            kbdEnabled = false
        }
    }

    func setKeyboardAuto(_ on: Bool) {
        keyboard.setAutoBrightness(on)
        kbdAuto = on
        if on { kbdEnabled = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.refresh() }
    }

    // MagSafe

    func setMagSafe(_ color: MagSafeColor) {
        magsafeBusy = true
        magsafeMessage = nil
        Task {
            let error = await magsafe.set(color)
            magsafeBusy = false
            magsafeMessage = error
            magsafeCurrent = magsafe.current
        }
    }

    var magsafeCaption: String {
        if !magsafeSupported { return "Este Mac não tem LED MagSafe controlável." }
        if magsafeBusy { return "Aguardando a senha de administrador…" }
        if let magsafeMessage { return magsafeMessage }
        let name = magsafeCurrent.flatMap { MagSafeColor(rawValue: $0)?.label }
            ?? magsafeCurrent.map { String(format: "0x%02X", $0) } ?? "?"
        var text = "Atual: \(name). Cada troca pede a senha de administrador."
        if !onAC { text += " Conecte o carregador MagSafe para ver a luz." }
        return text
    }

    // Geral

    func setLaunchAtLogin(_ on: Bool) {
        loginMessage = nil
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            loginMessage = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func quit() {
        NSApp.terminate(nil) // a limpeza do LED roda em willTerminate
    }
}

// MARK: - Interface

struct PanelView: View {
    @EnvironmentObject var model: LEDModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LEDs do Mac").font(.headline)

            PanelSection(title: "Caps Lock", icon: "capslock") {
                if model.capsHasAccess {
                    Picker("", selection: Binding(get: { model.capsMode }, set: { model.setCapsMode($0) })) {
                        ForEach(CapsMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                } else {
                    Text("Precisa da permissão “Monitoramento de Entrada” (só uma vez).")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Dar permissão…") { model.requestCapsAccess() }
                }
                if let msg = model.capsMessage {
                    Text(msg).font(.caption).foregroundStyle(.orange)
                }
            }

            PanelSection(title: "Luz do teclado", icon: "keyboard") {
                if model.keyboard.isAvailable {
                    Toggle("Luz ligada", isOn: Binding(
                        get: { model.kbdEnabled },
                        set: { model.setKeyboardEnabled($0) }
                    ))
                    .font(.caption)

                    HStack(spacing: 8) {
                        Image(systemName: "sun.min").foregroundStyle(.secondary)
                        Slider(value: Binding(get: { model.kbdLevel }, set: { model.setKeyboard($0) }), in: 0...1)
                        Image(systemName: "sun.max.fill").foregroundStyle(.secondary)
                    }
                    .disabled(!model.kbdEnabled)
                    HStack {
                        Text("Intensidade")
                        Spacer()
                        Text("\(Int(model.kbdLevel * 100))%")
                            .monospacedDigit()
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    Toggle("Automático (luz ambiente)",
                           isOn: Binding(get: { model.kbdAuto }, set: { model.setKeyboardAuto($0) }))
                        .font(.caption)
                } else {
                    Text("Luz do teclado indisponível neste Mac.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            PanelSection(title: "MagSafe", icon: "powerplug") {
                HStack(spacing: 6) {
                    ForEach(MagSafeColor.allCases) { color in
                        Button { model.setMagSafe(color) } label: {
                            HStack(spacing: 4) {
                                Circle().fill(swatch(color)).frame(width: 8, height: 8)
                                Text(color.label).font(.caption)
                            }
                        }
                    }
                }
                .disabled(model.magsafeBusy || !model.magsafeSupported)
                Text(model.magsafeCaption).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                Toggle("Abrir ao iniciar sessão",
                       isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                    .font(.caption)
                Spacer()
                Button("Sair") { model.quit() }
            }
            if let msg = model.loginMessage {
                Text(msg).font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(14)
        .frame(width: 320)
        .onAppear { model.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            model.refresh()
        }
    }

    private func swatch(_ c: MagSafeColor) -> Color {
        switch c {
        case .green: .green
        case .orange: .orange
        case .off: .gray.opacity(0.4)
        case .system: .secondary
        }
    }
}

private struct PanelSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.subheadline.weight(.semibold))
            content
        }
    }
}
