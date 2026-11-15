import AppIntents

struct SetKeyboardLightIntent: AppIntent {
    static var title: LocalizedStringResource = "Definir luz do teclado"
    static var description = IntentDescription("Liga, desliga ou deixa o sensor ambiente controlar a luz do teclado.")
    // Em macOS 14–26, esta é a forma compatível de o WidgetKit pedir que a
    // ação execute no app principal. Em versões atuais ela é mantida para
    // preservar o suporte aos sistemas mínimos do projeto.
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Modo")
    var mode: KeyboardLightMode

    init() {
        mode = .on
    }

    init(mode: KeyboardLightMode) {
        self.mode = mode
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Definir luz do teclado como \(\.$mode)")
    }

    func perform() async throws -> some IntentResult {
        _ = KeyboardLightController().setMode(mode)
        return .result()
    }
}
