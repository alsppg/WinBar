import AppKit

/// Ações de energia via System Events (pede permissão de Automação uma vez). Bloquear usa o atalho do sistema.
enum PowerActions {
    enum Kind { case sleep, restart, shutDown, logOut, lock }

    static func perform(_ kind: Kind) {
        switch kind {
        case .lock: AXController.lockScreen()
        case .sleep: run("tell application \"System Events\" to sleep")
        case .restart: confirm("Reiniciar o Mac agora?", "Os apps abertos serão fechados.") { run("tell application \"System Events\" to restart") }
        case .shutDown: confirm("Desligar o Mac agora?", "Os apps abertos serão fechados.") { run("tell application \"System Events\" to shut down") }
        case .logOut: confirm("Encerrar a sessão agora?", "Os apps abertos serão fechados.") { run("tell application \"System Events\" to log out") }
        }
    }

    private static func confirm(_ title: String, _ info: String, _ action: @escaping () -> Void) {
        let a = NSAlert()
        a.messageText = title; a.informativeText = info
        a.addButton(withTitle: "Confirmar"); a.addButton(withTitle: "Cancelar")
        a.alertStyle = .warning
        NSApp.activate()
        if a.runModal() == .alertFirstButtonReturn { action() }
    }

    private static func run(_ source: String) {
        var err: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&err)
        if let e = err { Log.warn("AppleScript falhou: \(e[NSAppleScript.errorNumber] ?? "?")") }
    }
}
