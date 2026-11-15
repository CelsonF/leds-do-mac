import SwiftUI
import WidgetKit

private struct KeyboardLightEntry: TimelineEntry {
    let date = Date()
}

private struct KeyboardLightProvider: TimelineProvider {
    func placeholder(in context: Context) -> KeyboardLightEntry { KeyboardLightEntry() }

    func getSnapshot(in context: Context, completion: @escaping (KeyboardLightEntry) -> Void) {
        completion(KeyboardLightEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KeyboardLightEntry>) -> Void) {
        completion(Timeline(entries: [KeyboardLightEntry()], policy: .never))
    }
}

private struct KeyboardLightWidgetView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Luz do teclado", systemImage: "keyboard")
                .font(.headline)

            HStack(spacing: 8) {
                Button(intent: SetKeyboardLightIntent(mode: .on)) {
                    Label("Ligar", systemImage: "lightbulb.fill")
                }
                .buttonStyle(.borderedProminent)

                Button(intent: SetKeyboardLightIntent(mode: .off)) {
                    Label("Apagar", systemImage: "lightbulb")
                }
                .buttonStyle(.bordered)
            }

            Button(intent: SetKeyboardLightIntent(mode: .automatic)) {
                Label("Usar luz ambiente", systemImage: "sun.max")
            }
            .buttonStyle(.bordered)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct KeyboardLightWidget: Widget {
    let kind = "LEDsKeyboardLight"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KeyboardLightProvider()) { _ in
            KeyboardLightWidgetView()
        }
        .configurationDisplayName("Luz do teclado")
        .description("Liga, apaga ou devolve a luz do teclado ao sensor ambiente.")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct LEDsWidgetBundle: WidgetBundle {
    var body: some Widget {
        KeyboardLightWidget()
    }
}
