import AppKit
import ApplicationServices

/// Estado das permissões que a barra precisa.
enum PermissionGate {
    /// Depois de uma atualização a entrada do TCC pode continuar "ligada" mas inválida (a assinatura do app
    /// mudou): AXIsProcessTrusted responde sim e as chamadas reais falham com apiDisabled. Sonda de verdade.
    static var accessibility: Bool {
        guard AXIsProcessTrusted() else { return false }
        var raw: AnyObject?
        let err = AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedApplicationAttribute as CFString, &raw)
        return err != .apiDisabled
    }
    static var screenRecording: Bool { CGPreflightScreenCaptureAccess() }

    /// Mostra o prompt do sistema para Accessibility (uma vez por sessão).
    static func requestAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    static func requestScreenRecording() {
        _ = CGRequestScreenCaptureAccess()
    }

    static func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    static func openScreenRecordingSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    private static func open(_ s: String) {
        if let url = URL(string: s) { NSWorkspace.shared.open(url) }
    }

    /// Relança o app (necessário depois de conceder Accessibility em alguns casos).
    /// Um shell separado espera este processo sair e então pede ao launchd para reabrir o agente (assim a
    /// nova instância continua gerenciada por ele); sem agente carregado, cai no `open`. Esperar a saída é
    /// obrigatório: com a instância antiga viva, o LaunchServices ignora o pedido e a nova sairia pelo guarda
    /// de instância única.
    static func relaunch() {
        let path = Bundle.main.bundlePath.replacingOccurrences(of: "'", with: "'\\''")
        let pid = ProcessInfo.processInfo.processIdentifier
        let service = "gui/\(getuid())/\(LoginItem.label)"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done; sleep 0.3; /bin/launchctl kickstart \(service) 2>/dev/null || /usr/bin/open -n '\(path)'"]
        do { try task.run() } catch { Log.error("relaunch falhou ao iniciar o shell"); return }
        NSApp.terminate(nil)
    }
}
