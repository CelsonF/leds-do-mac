import AppKit
import SwiftUI

@main
struct LEDsApp: App {
    @StateObject private var model = KeyboardLightModel()

    var body: some Scene {
        MenuBarExtra {
            KeyboardLightPanel().environmentObject(model)
        } label: {
            Image(systemName: model.isOn ? "lightbulb.fill" : "lightbulb")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class KeyboardLightModel: ObservableObject {
    private let keyboard = KeyboardBacklight()
    private var lastBrightness: Float = 0.5

    @Published private(set) var isAvailable = false
    @Published var isOn = false

    init() {
        refresh()
    }

    func refresh() {
        isAvailable = keyboard.isAvailable
        guard isAvailable else {
            isOn = false
            return
        }

        let brightness = keyboard.brightness
        isOn = brightness > 0.001
        if isOn { lastBrightness = brightness }
    }

    func setLight(_ on: Bool) {
        guard isAvailable else { return }

        if on {
            let brightness = lastBrightness > 0.001 ? lastBrightness : 0.5
            isOn = keyboard.setBrightness(brightness)
        } else {
            let brightness = keyboard.brightness
            if brightness > 0.001 { lastBrightness = brightness }
            isOn = !keyboard.setBrightness(0)
        }
    }

    func quit() {
        NSApp.terminate(nil)
    }
}

struct KeyboardLightPanel: View {
    @EnvironmentObject var model: KeyboardLightModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Luz do teclado", systemImage: "keyboard")
                .font(.headline)

            if model.isAvailable {
                Toggle(isOn: Binding(get: { model.isOn }, set: { model.setLight($0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.isOn ? "Ligada" : "Apagada")
                            .font(.body.weight(.medium))
                        Text("Liga ou desliga a luz do teclado.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
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
        .frame(width: 280)
        .onAppear { model.refresh() }
    }
}
