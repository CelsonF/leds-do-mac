import AppKit
import SwiftUI

@main
struct LEDsApp: App {
    @StateObject private var model = KeyboardLightModel()

    var body: some Scene {
        MenuBarExtra {
            KeyboardLightPanel().environmentObject(model)
        } label: {
            Image(systemName: model.mode == .off ? "lightbulb" : "lightbulb.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class KeyboardLightModel: ObservableObject {
    private let keyboard = KeyboardBacklight()
    private var lastBrightness: Float = 0.5

    @Published private(set) var isAvailable = false
    @Published var mode: KeyboardLightMode = .off

    init() {
        refresh()
    }

    func refresh() {
        isAvailable = keyboard.isAvailable
        guard isAvailable else {
            mode = .off
            return
        }

        let brightness = keyboard.brightness
        if brightness > 0.001 { lastBrightness = brightness }
        mode = keyboard.autoBrightness ? .automatic : (brightness > 0.001 ? .on : .off)
    }

    func setMode(_ newMode: KeyboardLightMode) {
        guard isAvailable else { return }

        switch newMode {
        case .on:
            let brightness = lastBrightness > 0.001 ? lastBrightness : 0.5
            if keyboard.setBrightness(brightness) { mode = .on } else { refresh() }

        case .off:
            let brightness = keyboard.brightness
            if brightness > 0.001 { lastBrightness = brightness }
            if keyboard.setBrightness(0) { mode = .off } else { refresh() }

        case .automatic:
            if keyboard.setAutoBrightness(true) { mode = .automatic } else { refresh() }
        }
    }

    func quit() {
        NSApp.terminate(nil)
    }
}

enum KeyboardLightMode: String, CaseIterable, Identifiable {
    case on = "Ligada"
    case off = "Apagada"
    case automatic = "Ambiente"

    var id: Self { self }

    var help: String {
        switch self {
        case .on: "Mantém a luz do teclado ligada."
        case .off: "Mantém a luz do teclado apagada."
        case .automatic: "O sensor de luz ambiente decide quando acender."
        }
    }
}

struct KeyboardLightPanel: View {
    @EnvironmentObject var model: KeyboardLightModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Luz do teclado", systemImage: "keyboard")
                .font(.headline)

            if model.isAvailable {
                Picker("Modo da luz", selection: Binding(
                    get: { model.mode }, set: { model.setMode($0) }
                )) {
                    ForEach(KeyboardLightMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(model.mode.help)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("A luz do teclado não está disponível neste Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Text("LEDs do Mac").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Sair") { model.quit() }
            }
        }
        .padding(16)
        .frame(width: 300)
        .onAppear { model.refresh() }
    }
}
