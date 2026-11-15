import AppIntents

struct SetKeyboardLightToggleIntent: SetValueIntent {
    static var title: LocalizedStringResource = "Luz do teclado"
    // Mantém a escrita no brilho no app principal, fora do sandbox da extensão.
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Luz ambiente")
    var value: Bool

    init() {
        value = false
    }

    func perform() async throws -> some IntentResult {
        _ = KeyboardLightController().setAmbientEnabled(value)
        return .result()
    }
}
