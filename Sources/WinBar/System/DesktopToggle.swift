import AppKit

/// "Mostrar área de trabalho" (canto inferior direito / área vazia da barra / menu).
/// Caminho principal: o atalho nativo "Mostrar Mesa" do Mission Control — todas as janelas saem de uma vez,
/// o segundo clique (ou clicar numa janela) traz tudo de volta, e a barra fica no lugar (janela `.stationary`).
/// Reserva, só se o usuário desativou esse atalho: oculta todos os apps e minimiza o que resistir.
final class DesktopToggle {
    static let shared = DesktopToggle()
    private var hiddenPIDs: [pid_t] = []
    private var minimized: [WindowInfo] = []     // janelas de apps que ignoraram o hide()
    private var previousActive: pid_t?
    private var ignoreActivationsUntil = Date.distantPast
    private(set) var showingDesktop = false      // só no caminho de reserva

    func toggle() {
        if let key = SystemShortcuts.showDesktop { SystemShortcuts.press(key); return }
        ignoreActivationsUntil = Date().addingTimeInterval(1.5)   // ocultar/restaurar dispara ativações do sistema
        if showingDesktop { restore() } else { showDesktop() }
    }

    private func showDesktop() {
        let me = ProcessInfo.processInfo.processIdentifier
        previousActive = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isHidden && $0.processIdentifier != me }
        hiddenPIDs = apps.map { $0.processIdentifier }
        minimized.removeAll()
        // O WinBar vira o app ativo ANTES de ocultar os outros: senão, ao ocultar o último visível, o macOS
        // ativa (e desoculta) outro app sozinho, e uma janela volta a aparecer.
        NSApp.activate()
        for app in apps { _ = app.hide() }
        showingDesktop = true
        // Teimosos: quem continuar visível depois de 0,4 s é reocultado; se ainda resistir, tem as janelas
        // minimizadas via Acessibilidade.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self = self, self.showingDesktop else { return }
            NSApp.activate()
            for app in apps where !app.isHidden && !app.isTerminated {
                if app.hide() { continue }
                for w in WindowService.windows(for: app) ?? [] where !w.isMinimized {
                    AXController.minimize(w); self.minimized.append(w)
                }
            }
        }
    }

    private func restore() {
        for w in minimized { AXUIElementSetAttributeValue(w.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse) }
        minimized.removeAll()
        for pid in hiddenPIDs { _ = NSRunningApplication(processIdentifier: pid)?.unhide() }
        hiddenPIDs.removeAll()
        showingDesktop = false
        if let pid = previousActive, let app = NSRunningApplication(processIdentifier: pid) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { AXController.bringToFront(app, allWindows: false) }
        }
        previousActive = nil
    }

    /// Ativação feita pelo usuário cancela o estado "mostrando área de trabalho" (o próximo clique oculta de novo).
    func noteAppActivated() {
        guard showingDesktop, Date() > ignoreActivationsUntil else { return }
        showingDesktop = false; hiddenPIDs.removeAll(); minimized.removeAll(); previousActive = nil
    }
}
