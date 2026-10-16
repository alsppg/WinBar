import AppKit
import Carbon.HIToolbox

/// Atalhos do sistema em Ajustes do Sistema > Teclado > Atalhos (com.apple.symbolichotkeys), para o WinBar
/// disparar ações do Mission Control exatamente como o teclado faria.
enum SystemShortcuts {
    struct Key { let keyCode: CGKeyCode; let flags: CGEventFlags }

    /// "Mostrar Mesa" (id 36). Padrão do macOS: F11 com o bit fn. nil = o usuário desativou o atalho.
    static var showDesktop: Key? {
        key(id: 36, default: Key(keyCode: CGKeyCode(kVK_F11), flags: .maskSecondaryFn))
    }

    /// "Alternar para a Mesa N" (ids 118…127). Vem desativado de fábrica.
    static func switchToDesktop(_ n: Int) -> Key? {
        guard n >= 1, n <= 10 else { return nil }
        return key(id: 117 + n, default: nil)
    }

    /// Entrada ausente no plist = ajuste de fábrica (`default`); presente = respeita enabled + tecla configurada.
    /// `parameters` = [caractere, keyCode, modificadores]; os bits coincidem com CGEventFlags.
    private static let usableFlags: UInt64 = CGEventFlags.maskShift.rawValue | CGEventFlags.maskControl.rawValue
        | CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskCommand.rawValue
    /// Teclas F1…F20: num evento sintético o bit fn faz parte da identidade da tecla — testado ao vivo, F11 só
    /// dispara "Mostrar Mesa" com ele, mesmo quando o plist guarda modificadores 0.
    private static let functionKeys: Set<Int> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90]
    private static func key(id: Int, default fallback: Key?) -> Key? {
        guard let hot = CFPreferencesCopyAppValue("AppleSymbolicHotKeys" as CFString, "com.apple.symbolichotkeys" as CFString) as? [String: Any],
              let entry = hot["\(id)"] as? [String: Any] else { return fallback }
        let enabled = (entry["enabled"] as? Bool) ?? ((entry["enabled"] as? Int) == 1)
        guard enabled else { return nil }
        guard let value = entry["value"] as? [String: Any], let p = value["parameters"] as? [Int], p.count >= 3,
              p[1] >= 0, p[1] != 65535 else { return fallback }
        var flags = CGEventFlags(rawValue: UInt64(p[2]) & usableFlags)
        if functionKeys.contains(p[1]) { flags.insert(.maskSecondaryFn) }
        return Key(keyCode: CGKeyCode(p[1]), flags: flags)
    }

    static func press(_ k: Key) { AXController.postKey(keyCode: k.keyCode, flags: k.flags) }
}
