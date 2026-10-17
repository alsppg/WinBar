import AppKit

/// Inicialização com o sistema via LaunchAgent do usuário (~/Library/LaunchAgents/<label>.plist):
/// RunAtLoad abre o WinBar ao iniciar a sessão e KeepAlive/SuccessfulExit=false reabre se ele cair
/// ("Sair" termina com código 0 e NÃO é reaberto). Preferido ao SMAppService porque não depende da
/// assinatura do app e o estado é verificável: `launchctl print gui/$UID/io.github.alsppg.winbar`.
/// O item aparece em Ajustes do Sistema > Geral > Itens de Início > "Permitir em segundo plano".
enum LoginItem {
    static let label = "io.github.alsppg.winbar"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }
    private static var domain: String { "gui/\(getuid())" }
    static var executablePath: String {
        Bundle.main.executablePath ?? (Bundle.main.bundlePath + "/Contents/MacOS/WinBar")
    }

    static var isInstalled: Bool { FileManager.default.fileExists(atPath: plistURL.path) }

    /// true quando o plist existente aponta para ESTE bundle (app movido ou reinstalado em outro lugar = false).
    static var pointsHere: Bool {
        guard let d = NSDictionary(contentsOf: plistURL), let args = d["ProgramArguments"] as? [String] else { return false }
        return args.first == executablePath
    }

    /// Processo iniciado pelo launchd (pai = 1) em vez de `open`/Finder.
    static var launchedByLaunchd: Bool { getppid() == 1 }

    static func set(enabled: Bool) { if enabled { enable() } else { disable() } }

    /// A cada abertura: garante o agente quando o ajuste está ligado (autorreparo se o plist sumiu ou o
    /// caminho mudou) e remove quando está desligado.
    static func ensure(enabled: Bool) {
        if enabled { if !isInstalled || !pointsHere { enable() } }
        else if isInstalled { disable() }
    }

    static func enable() {
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": ["SuccessfulExit": false],
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua",
        ]
        do {
            try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: plistURL.path)
        } catch { Log.warn("login item: não gravou o LaunchAgent"); return }
        launchctl(["enable", "\(domain)/\(label)"])
        // Se o agente já está carregado nesta sessão o bootstrap falha (inofensivo); se não está, o launchd
        // abre uma 2ª instância, que sai sozinha ao ver esta (AppDelegate) — o agente passa a valer no próximo login.
        launchctl(["bootstrap", domain, plistURL.path])
        Log.info("login item: LaunchAgent ativo")
    }

    /// Só remove o plist: não derruba a instância em execução (um bootout mataria a barra na hora).
    static func disable() {
        try? FileManager.default.removeItem(at: plistURL)
        Log.info("login item: LaunchAgent removido")
    }

    @discardableResult
    private static func launchctl(_ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run(); p.waitUntilExit() } catch { return -1 }
        return p.terminationStatus
    }
}
