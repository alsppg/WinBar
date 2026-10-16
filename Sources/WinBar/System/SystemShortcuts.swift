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
    /// `parameters` = [caractere, keyCode, modificadores]; os bits coincidem com CGEventFlags. O bit fn (8388608)
    /// faz parte da identidade das teclas F: testado ao vivo, F11 sintético só dispara "Mostrar Mesa" com ele.
    private static let usableFlags: UInt64 = CGEventFlags.maskShift.rawValue | CGEventFlags.maskControl.rawValue
        | CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskCommand.rawValue | CGEventFlags.maskSecondaryFn.rawValue
    private static func key(id: Int, default fallback: Key?) -> Key? {
        guard let hot = CFPreferencesCopyAppValue("AppleSymbolicHotKeys" as CFString, "com.apple.symbolichotkeys" as CFString) as? [String: Any],
              let entry = hot["\(id)"] as? [String: Any] else { return fallback }
        let enabled = (entry["enabled"] as? Bool) ?? ((entry["enabled"] as? Int) == 1)
        guard enabled else { return nil }
        guard let value = entry["value"] as? [String: Any], let p = value["parameters"] as? [Int], p.count >= 3,
              p[1] >= 0, p[1] != 65535 else { return fallback }
        return Key(keyCode: CGKeyCode(p[1]), flags: CGEventFlags(rawValue: UInt64(p[2]) & usableFlags))
    }

    static func press(_ k: Key) { AXController.postKey(keyCode: k.keyCode, flags: k.flags) }
}
