import AppKit
import ApplicationServices

/// Estado das permissões que a barra precisa.
enum PermissionGate {
    static var accessibility: Bool { AXIsProcessTrusted() }
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
    /// Um shell separado espera este processo sair antes de chamar `open`, senão o LaunchServices
    /// vê a instância antiga ainda viva e ignora o pedido.
    static func relaunch() {
        let path = Bundle.main.bundlePath.replacingOccurrences(of: "'", with: "'\\''")
        let pid = ProcessInfo.processInfo.processIdentifier
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done; sleep 0.3; /usr/bin/open -n '\(path)'"]
        do { try task.run() } catch { Log.error("relaunch falhou ao iniciar o shell"); return }
        NSApp.terminate(nil)
    }
}
