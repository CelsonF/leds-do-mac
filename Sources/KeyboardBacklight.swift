import Foundation
import ObjectiveC

/// Luz do teclado via framework privado CoreBrightness (KeyboardBrightnessClient).
/// O MacBook tem uma zona só: o brilho vale para todas as teclas.
final class KeyboardBacklight {
    private let client: NSObject?
    private(set) var keyboardID: UInt64?

    private typealias CopyIDs = @convention(c) (AnyObject, Selector) -> Unmanaged<NSArray>?
    private typealias GetFloat = @convention(c) (AnyObject, Selector, UInt64) -> Float
    private typealias GetBool = @convention(c) (AnyObject, Selector, UInt64) -> Bool
    private typealias SetBool = @convention(c) (AnyObject, Selector, Bool, UInt64) -> Bool
    private typealias SetBrightness = @convention(c) (AnyObject, Selector, Float, Int32, Bool, UInt64) -> Bool

    init() {
        _ = dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW)
        client = (NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type)?.init()
        keyboardID = nil
        keyboardID = findBuiltInKeyboard()
    }

    var isAvailable: Bool { client != nil && keyboardID != nil }

    private func method<T>(_ name: String, _ type: T.Type) -> (T, Selector)? {
        guard let client else { return nil }
        let sel = NSSelectorFromString(name)
        guard client.responds(to: sel) else { return nil }
        return (unsafeBitCast(client.method(for: sel), to: type), sel)
    }

    private func findBuiltInKeyboard() -> UInt64? {
        guard let client, let (copy, sel) = method("copyKeyboardBacklightIDs", CopyIDs.self),
              let ids = copy(client, sel)?.takeRetainedValue() as? [NSNumber], !ids.isEmpty
        else { return nil }
        if let (isBuiltIn, s) = method("isKeyboardBuiltIn:", GetBool.self),
           let builtIn = ids.first(where: { isBuiltIn(client, s, $0.uint64Value) }) {
            return builtIn.uint64Value
        }
        return ids[0].uint64Value
    }

    /// 0.0 ... 1.0
    var brightness: Float {
        guard let client, let id = keyboardID, let (get, sel) = method("brightnessForKeyboard:", GetFloat.self)
        else { return 0 }
        return get(client, sel, id)
    }

    @discardableResult
    func setBrightness(_ value: Float) -> Bool {
        guard let client, let id = keyboardID,
              let (set, sel) = method("setBrightness:fadeSpeed:commit:forKeyboard:", SetBrightness.self)
        else { return false }
        return set(client, sel, min(max(value, 0), 1), 0, true, id)
    }

    /// "Ajustar o brilho do teclado com pouca luz" (sensor de luz ambiente).
    /// Precisa estar desligado para o brilho manual valer em ambiente claro.
    var autoBrightness: Bool {
        guard let client, let id = keyboardID,
              let (get, sel) = method("isAutoBrightnessEnabledForKeyboard:", GetBool.self)
        else { return false }
        return get(client, sel, id)
    }

    @discardableResult
    func setAutoBrightness(_ on: Bool) -> Bool {
        guard let client, let id = keyboardID,
              let (set, sel) = method("enableAutoBrightness:forKeyboard:", SetBool.self)
        else { return false }
        return set(client, sel, on, id)
    }
}
