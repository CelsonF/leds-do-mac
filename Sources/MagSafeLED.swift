import Foundation
import IOKit
import IOKit.ps

/// Cores do LED MagSafe 3 (valores da chave SMC "ACLC").
/// 3 = verde e 4 = laranja são os valores usados pela comunidade; 0 devolve o controle ao sistema.
enum MagSafeColor: UInt8, CaseIterable, Identifiable {
    case green = 3, orange = 4, off = 1, system = 0

    var id: UInt8 { rawValue }

    var label: String {
        switch self {
        case .green: "Verde"
        case .orange: "Laranja"
        case .off: "Apagado"
        case .system: "Sistema"
        }
    }
}

/// Acesso mínimo ao SMC (AppleSMC). Ler não precisa de root; escrever precisa.
final class SMC {
    private var conn: io_connect_t = 0

    init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard IOServiceOpen(service, mach_task_self_, 0, &conn) == kIOReturnSuccess else { return nil }
    }

    deinit { IOServiceClose(conn) }

    // Layout de SMCKeyData_t (80 bytes): key@0, keyInfo.dataSize@28, keyInfo.dataType@32,
    // result@40, data8@42, bytes@48..80. Seletor 2 = kSMCHandleYPCEvent.
    private enum Cmd: UInt8 { case read = 5, write = 6, keyInfo = 9 }

    private static func fourCC(_ s: String) -> UInt32 {
        s.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }

    private func call(_ key: String, _ cmd: Cmd, size: UInt32 = 0, byte: UInt8? = nil) -> [UInt8]? {
        var input = [UInt8](repeating: 0, count: 80)
        withUnsafeBytes(of: Self.fourCC(key).littleEndian) { for i in 0..<4 { input[i] = $0[i] } }
        withUnsafeBytes(of: size.littleEndian) { for i in 0..<4 { input[28 + i] = $0[i] } }
        input[42] = cmd.rawValue
        if let byte { input[48] = byte }

        var output = [UInt8](repeating: 0, count: 80)
        var outSize = 80
        let kr = IOConnectCallStructMethod(conn, 2, &input, 80, &output, &outSize)
        guard kr == kIOReturnSuccess, output[40] == 0 else { return nil }
        return output
    }

    func keySize(_ key: String) -> UInt32? {
        guard let out = call(key, .keyInfo) else { return nil }
        return out[28..<32].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
    }

    func readByte(_ key: String) -> UInt8? {
        guard keySize(key) == 1, let out = call(key, .read, size: 1) else { return nil }
        return out[48]
    }

    func writeByte(_ key: String, _ value: UInt8) -> Bool {
        guard keySize(key) == 1 else { return false }
        return call(key, .write, size: 1, byte: value) != nil
    }
}

/// LED do conector MagSafe 3.
final class MagSafeLED {
    static let key = "ACLC"

    var isSupported: Bool { SMC()?.keySize(Self.key) == 1 }

    var current: UInt8? { SMC()?.readByte(Self.key) }

    var isOnAC: Bool {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        guard let type = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() else { return false }
        return (type as String) == kIOPMACPowerKey
    }

    /// Muda a cor. Pede a senha de administrador (macOS) e roda este mesmo executável
    /// como root com `--magsafe <valor>`. Retorna nil se deu certo, ou a mensagem de erro.
    func set(_ color: MagSafeColor) async -> String? {
        if geteuid() == 0 {
            return SMC()?.writeByte(Self.key, color.rawValue) == true ? nil : "Falha ao escrever no SMC."
        }
        let exe = Bundle.main.executablePath ?? CommandLine.arguments[0]
        let escaped = exe
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script (quoted form of \"\(escaped)\") & \" --magsafe \(color.rawValue)\" with administrator privileges"

        return await withCheckedContinuation { cont in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-e", script]
            let errPipe = Pipe()
            p.standardError = errPipe
            p.standardOutput = FileHandle.nullDevice
            p.terminationHandler = { proc in
                let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if proc.terminationStatus == 0 {
                    cont.resume(returning: nil)
                } else if err.contains("-128") {
                    cont.resume(returning: "Cancelado.")
                } else {
                    cont.resume(returning: "Não deu certo: \(err)")
                }
            }
            do { try p.run() } catch { cont.resume(returning: error.localizedDescription) }
        }
    }

    /// Modo linha de comando (roda como root via `set`). Só aceita os valores conhecidos.
    static func runCLI(_ arg: String) -> Int32 {
        guard let v = UInt8(arg), let color = MagSafeColor(rawValue: v) else {
            fputs("valor inválido: use 0, 1, 3 ou 4\n", stderr); return 2
        }
        guard geteuid() == 0 else { fputs("precisa rodar como root\n", stderr); return 1 }
        guard let smc = SMC(), smc.keySize(key) == 1 else { fputs("chave ACLC indisponível\n", stderr); return 1 }
        return smc.writeByte(key, color.rawValue) ? 0 : 1
    }
}
