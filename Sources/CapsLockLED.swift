import CoreGraphics
import Foundation
import IOKit.hid

/// LED do Caps Lock via IOKit HID.
/// Liga/desliga só a luz — o estado real do Caps Lock não muda.
/// Requer a permissão "Monitoramento de Entrada" (Ajustes > Privacidade e Segurança).
///
/// A escrita no teclado leva alguns milissegundos (a primeira, que abre o
/// dispositivo, ~60 ms), então tudo roda numa fila serial fora da main thread.
/// A ordem dos pedidos é preservada pela fila.
final class CapsLockLED: @unchecked Sendable {
    private let queue = DispatchQueue(label: "leds.capslock", qos: .userInitiated)

    // Acessados só dentro de `queue`.
    private var manager: IOHIDManager?
    private var opened: [(device: IOHIDDevice, leds: [IOHIDElement])] = []

    private static let options = IOOptionBits(kIOHIDOptionsTypeNone)

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

    /// Abre os teclados em segundo plano, para o primeiro clique ser instantâneo.
    func prepare() {
        queue.async { self.openKeyboards() }
    }

    /// Acende/apaga o LED em segundo plano. `completion` (opcional) roda na main thread
    /// com false se nenhum LED foi alterado.
    func setLED(_ on: Bool, completion: (@MainActor (Bool) -> Void)? = nil) {
        queue.async {
            let ok = self.apply(on)
            if let completion {
                Task { @MainActor in completion(ok) }
            }
        }
    }

    /// Versão síncrona: espera a escrita terminar (usada ao sair do app).
    @discardableResult
    func setLEDNow(_ on: Bool) -> Bool {
        queue.sync { apply(on) }
    }

    /// Devolve o LED ao estado real do Caps Lock, esperando terminar.
    func restoreNow() {
        setLEDNow(capsLockIsOn)
    }

    // MARK: - Dentro da fila

    private func apply(_ on: Bool) -> Bool {
        openKeyboards()
        if write(on) { return true }
        // O sistema às vezes recusa uma escrita isolada: reabre e tenta de novo.
        closeKeyboards()
        openKeyboards()
        return write(on)
    }

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
}

/// Avisa quando o estado do Caps Lock muda, sem polling: um event tap
/// "listen-only" recebe só eventos de modificadores (flagsChanged).
/// Usa a mesma permissão "Monitoramento de Entrada" do LED.
/// Precisa ser criado na main thread; o aviso chega na main thread.
final class CapsLockWatcher {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var last: Bool
    private let onChange: @MainActor (Bool) -> Void

    /// Retorna nil se o sistema não deixar criar o event tap (sem permissão).
    init?(onChange: @escaping @MainActor (Bool) -> Void) {
        self.onChange = onChange
        last = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)

        let mask = CGEventMask(1) << CGEventMask(CGEventType.flagsChanged.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                if let refcon {
                    Unmanaged<CapsLockWatcher>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else { return nil }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        self.tap = tap
        self.source = source
    }

    deinit {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        // O sistema desliga taps lentos ou após certas entradas: religa.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        let now = event.flags.contains(.maskAlphaShift)
        guard now != last else { return } // Shift, Cmd etc. não interessam
        last = now
        MainActor.assumeIsolated { onChange(now) }
    }
}
