import SwiftUI
import WidgetKit

@available(macOS 26.0, *)
struct KeyboardLightControlWidget: ControlWidget {
    static let kind = "LEDsKeyboardLightControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: Provider()) { isOn in
            ControlWidgetToggle(
                "Luz do teclado",
                isOn: isOn,
                action: SetKeyboardLightToggleIntent(),
                valueLabel: { isOn in
                    Label(
                        isOn ? "Ambiente" : "Apagada",
                        systemImage: isOn ? "sun.max.fill" : "lightbulb.slash"
                    )
                }
            )
        }
        .displayName("Luz do teclado")
        .description("Liga o controle por luz ambiente ou apaga a luz do teclado.")
    }

    private struct Provider: ControlValueProvider {
        var previewValue: Bool { true }

        func currentValue() async throws -> Bool {
            KeyboardLightState.isAmbientEnabled
        }
    }
}

@available(macOS 26.0, *)
@main
struct LEDsWidgetBundle: WidgetBundle {
    var body: some Widget {
        KeyboardLightControlWidget()
    }
}
