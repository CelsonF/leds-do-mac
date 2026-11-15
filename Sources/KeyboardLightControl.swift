import Foundation

enum KeyboardLightState {
    static let appGroup = "group.local.leds-do-mac"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static var isAmbientEnabled: Bool {
        get { defaults.bool(forKey: "keyboardLightAmbientEnabled") }
        set { defaults.set(newValue, forKey: "keyboardLightAmbientEnabled") }
    }
}

final class KeyboardLightController {
    private let keyboard = KeyboardBacklight()

    /// Ligado devolve a luz ao sensor ambiente do macOS; desligado a apaga.
    @discardableResult
    func setAmbientEnabled(_ enabled: Bool) -> Bool {
        guard keyboard.isAvailable else { return false }

        let didChange = enabled
            ? keyboard.setAutoBrightness(true)
            : keyboard.setBrightness(0)

        if didChange { KeyboardLightState.isAmbientEnabled = enabled }
        return didChange
    }
}
