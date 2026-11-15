import AppIntents
import Foundation

enum KeyboardLightMode: String, CaseIterable, Identifiable, AppEnum {
    case on = "Ligada"
    case off = "Apagada"
    case automatic = "Ambiente"

    var id: Self { self }

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Modo da luz do teclado")
    static var caseDisplayRepresentations: [KeyboardLightMode: DisplayRepresentation] = [
        .on: DisplayRepresentation(title: "Ligada"),
        .off: DisplayRepresentation(title: "Apagada"),
        .automatic: DisplayRepresentation(title: "Ambiente"),
    ]
}

final class KeyboardLightController {
    private let keyboard = KeyboardBacklight()
    private var lastBrightness: Float = 0.5

    var isAvailable: Bool { keyboard.isAvailable }

    func setMode(_ mode: KeyboardLightMode) -> Bool {
        guard keyboard.isAvailable else { return false }

        switch mode {
        case .on:
            return keyboard.setBrightness(lastBrightness > 0.001 ? lastBrightness : 0.5)
        case .off:
            let brightness = keyboard.brightness
            if brightness > 0.001 { lastBrightness = brightness }
            return keyboard.setBrightness(0)
        case .automatic:
            return keyboard.setAutoBrightness(true)
        }
    }
}
