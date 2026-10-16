import AppKit

/// Observa apps em execução + janelas e publica a lista ordenada de entradas da barra.
final class AppTracker {
    static let shared = AppTracker()
    static let changed = Notification.Name("WinBar.apps.changed")

    private(set) var entries: [AppEntry] = []
    private let queue = DispatchQueue(label: "winbar.apptracker", qos: .userInitiated)
    private var timer: Timer?
    private var pending = false
    private var iconCache = NSCache<NSString, NSImage>()
    // Só na `queue`: última lista de janelas por app (usada quando o app não responde ao Accessibility) e
    // controle do encerramento automático de quem ficou sem janela.
    private var lastWindows: [pid_t: [WindowInfo]] = [:]
    private var hadWindows = Set<pid_t>()
    private var windowless: [pid_t: Date] = [:]
    /// Carência entre a última janela sumir e o app ser encerrado: tempo de o app abrir outra (⌘N, "Salvar?").
    private let quitGrace: TimeInterval = 3

    private init() {
        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didActivateApplicationNotification, NSWorkspace.didHideApplicationNotification,
                     NSWorkspace.didUnhideApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            nc.addObserver(self, selector: #selector(scheduleRefresh), name: name, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(scheduleRefresh), name: PinStore.changed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(scheduleRefresh), name: SettingsStore.changed, object: nil)
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in self?.scheduleRefresh() }
        scheduleRefresh()
    }

    @objc func scheduleRefresh() {
        guard !pending else { return }
        pending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.pending = false
            self?.refresh()
        }
    }

    private func refresh() {
        let settings = SettingsStore.shared.s
        let pins = PinStore.shared.items
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
                && !($0.bundleIdentifier.map { settings.excludedBundleIDs.contains($0) } ?? false)
        }
        let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
        queue.async { [weak self] in
            guard let self = self else { return }
            var built: [AppEntry] = []
            var seen = Set<String>()

            // Apps em execução (com janelas via AX)
            let now = Date()
            var alive = Set<pid_t>()
            for app in running {
                let bid = app.bundleIdentifier
                let pid = app.processIdentifier
                let id = bid ?? "pid:\(pid)"
                alive.insert(pid)
                // App ocupado que não respondeu ao Accessibility mantém a última lista conhecida: nunca some da
                // barra (nem é encerrado) por um timeout.
                let fresh = app.isFinishedLaunching ? WindowService.windows(for: app) : []
                let windows = fresh ?? self.lastWindows[pid] ?? []
                if let fresh = fresh { self.lastWindows[pid] = fresh }
                if let fresh = fresh, app.isFinishedLaunching {
                    if !fresh.isEmpty { self.hadWindows.insert(pid); self.windowless[pid] = nil }
                    else if self.hadWindows.contains(pid) {
                        // Última janela fechada por qualquer meio (⌘W, botão vermelho…): como no Windows, o app
                        // sem janela encerra — depois da carência, para dar tempo de ele abrir outra.
                        let since = self.windowless[pid] ?? now
                        self.windowless[pid] = since
                        if now.timeIntervalSince(since) >= self.quitGrace && settings.mayQuit(bundleID: bid) {
                            self.hadWindows.remove(pid)
                            DispatchQueue.main.async { AXController.quit(app) }
                        }
                    }
                }
                // Sem janela só fica na barra quem é fixado ou está em "manter em execução" (ex.: Spotify tocando).
                let keep = bid.map { PinStore.shared.isPinned($0) || settings.keepRunningBundleIDs.contains($0) } ?? false
                if settings.excludeNoWindowApps && windows.isEmpty && app.isFinishedLaunching && !keep { continue }
                seen.insert(id)
                built.append(AppEntry(id: id, bundleID: bid, name: app.localizedName ?? id, url: app.bundleURL,
                                      app: app, isPinned: bid.map { PinStore.shared.isPinned($0) } ?? false,
                                      windows: windows, isActive: app.processIdentifier == frontmost,
                                      isHidden: app.isHidden, isLaunching: !app.isFinishedLaunching))
            }
            // Fixados que não estão rodando
            for p in pins where !seen.contains(p.id) {
                let url = URL(fileURLWithPath: p.path)
                let name = p.name ?? FileManager.default.displayName(atPath: p.path).replacingOccurrences(of: ".app", with: "")
                built.append(AppEntry(id: p.id, bundleID: p.id, name: name, url: url, app: nil, isPinned: true,
                                      windows: [], isActive: false, isHidden: false, isLaunching: false))
            }
            for pid in Array(self.lastWindows.keys) where !alive.contains(pid) {
                self.lastWindows[pid] = nil; self.hadWindows.remove(pid); self.windowless[pid] = nil
            }
            let ordered = self.order(built, pins: pins, manual: settings.manualOrder)
            DispatchQueue.main.async {
                self.entries = ordered
                NotificationCenter.default.post(name: AppTracker.changed, object: nil)
            }
        }
    }

    /// Ordem: manualOrder (sessão/arrasto) > fixados na ordem do PinStore > demais por ordem de lançamento.
    private func order(_ list: [AppEntry], pins: [PinnedItem], manual: [String]) -> [AppEntry] {
        let manualIdx = Dictionary(manual.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        let pinIdx = Dictionary(pins.map { ($0.id, $0.order) }, uniquingKeysWith: { a, _ in a })
        func key(_ e: AppEntry) -> (Int, Int, Int, TimeInterval) {
            // Grupo 0 = fixados (colados ao Iniciar), na ordem do PinStore; grupo 1 = demais (ordem manual > lançamento)
            if let p = pinIdx[e.id] { return (0, p, 0, 0) }
            if let m = manualIdx[e.id] { return (1, 0, m, 0) }
            return (1, 1, 0, e.app?.launchDate?.timeIntervalSince1970 ?? 0)
        }
        return list.sorted { key($0) < key($1) }
    }

    func entry(id: String) -> AppEntry? { entries.first { $0.id == id } }

    func icon(for e: AppEntry) -> NSImage {
        let key = (e.url?.path ?? e.id) as NSString
        if let img = iconCache.object(forKey: key) { return img }
        let img: NSImage
        if let app = e.app, let i = app.icon { img = i }
        else if let url = e.url { img = NSWorkspace.shared.icon(forFile: url.path) }
        else { img = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage() }
        img.size = NSSize(width: 64, height: 64)
        iconCache.setObject(img, forKey: key)
        return img
    }

    /// Grava a ordem atual (após arrasto) nos ajustes e no PinStore.
    func commitOrder(_ ids: [String]) {
        SettingsStore.shared.settings.manualOrder = ids
        PinStore.shared.reorder(byBundleIDs: ids)
    }
}
