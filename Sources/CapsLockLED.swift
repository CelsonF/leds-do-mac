import CoreGraphics
import Foundation
import IOKit.hid

/// LED do Caps Lock via IOKit HID.
/// Liga/desliga só a luz — o estado real do Caps Lock não muda.
/// Requer a permissão "Monitoramento de Entrada" (Ajustes > Privacidade e Segurança).
final class CapsLockLED {
    private var manager: IOHIDManager?

    var hasAccess: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    /// true se o sistema ainda não perguntou (o pedido vai aparecer).
    var accessNotAsked: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeUnknown
    }

    @discardableResult
    func requestAccess() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    /// Estado real do Caps Lock (independente do LED).
    var capsLockIsOn: Bool {
        CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
    }

    /// Teclados já abertos, com seus elementos de LED do Caps Lock.
    private var opened: [(device: IOHIDDevice, leds: [IOHIDElement])] = []

    private static let options = IOOptionBits(kIOHIDOptionsTypeNone)

    /// Abre cada teclado individualmente (IOHIDManagerOpen falha inteiro
    /// se um único dispositivo recusar, então não dá pra confiar nele).
    private func openKeyboards() {
        if !opened.isEmpty { return }
        if manager == nil {
            let m = IOHIDManagerCreate(kCFAllocatorDefault, Self.options)
            IOHIDManagerSetDeviceMatching(m, [
                kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
                kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard,
            ] as CFDictionary)
            manager = m
        }
        guard let manager, let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return }

        let ledMatch = [
            kIOHIDElementUsagePageKey: kHIDPage_LEDs,
            kIOHIDElementUsageKey: kHIDUsage_LED_CapsLock,
        ] as CFDictionary

        for device in devices where IOHIDDeviceOpen(device, Self.options) == kIOReturnSuccess {
            let leds = IOHIDDeviceCopyMatchingElements(device, ledMatch, Self.options) as? [IOHIDElement] ?? []
            if leds.isEmpty {
                IOHIDDeviceClose(device, Self.options)
            } else {
                opened.append((device, leds))
            }
        }
    }

    private func closeKeyboards() {
        for entry in opened { IOHIDDeviceClose(entry.device, Self.options) }
        opened.removeAll()
    }

    private func write(_ on: Bool) -> Bool {
        var changed = false
        for (device, leds) in opened {
            for element in leds {
                let value = IOHIDValueCreateWithIntegerValue(
                    kCFAllocatorDefault, element, mach_absolute_time(), on ? 1 : 0
                )
                if IOHIDDeviceSetValue(device, element, value) == kIOReturnSuccess {
                    changed = true
                }
            }
        }
        return changed
    }

    /// Acende/apaga o LED em todo teclado que tenha LED de Caps Lock.
    /// Retorna false se nenhum LED foi alterado.
    @discardableResult
    func setLED(_ on: Bool) -> Bool {
        openKeyboards()
        if write(on) { return true }
        // O sistema às vezes recusa uma escrita isolada: reabre e tenta de novo.
        closeKeyboards()
        openKeyboards()
        return write(on)
    }

    /// Devolve o LED ao estado real do Caps Lock.
    func restore() {
        setLED(capsLockIsOn)
    }
}
