import AppKit

struct AppItem {
    let name: String
    let url: URL
    let bundleID: String?
    var sortKey: String { name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) }
    var sectionLetter: String {
        let c = sortKey.first.map { String($0).uppercased() } ?? "#"
        return c.rangeOfCharacter(from: .letters) != nil ? c : "#"
    }
}

/// Índice de aplicativos para o menu Iniciar — a mesma cobertura do app "Apps" do macOS:
/// 1) varredura das pastas de apps (até 3 níveis, sem entrar em bundles);
/// 2) consulta ao Spotlight por todo bundle de aplicativo que o Launch Services conhece,
///    filtrando o que não é "app instalado" (dentro de outros apps, Lixeira, Developer, cache).
final class StartIndex {
    static let shared = StartIndex()
    static let changed = Notification.Name("WinBar.startindex.changed")

    private(set) var items: [AppItem] = []
    private var builtAt: Date?
    private let queue = DispatchQueue(label: "winbar.startindex", qos: .utility)
    private var scanned: [String: AppItem] = [:]
    private var spotlight: [String: AppItem] = [:]
    private var query: NSMetadataQuery?

    private var roots: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [URL(fileURLWithPath: "/Applications"),
                URL(fileURLWithPath: "/System/Applications"),
                URL(fileURLWithPath: "/System/Library/CoreServices"),   // Finder + Applications/ (Acesso às Chaves etc.)
                home.appendingPathComponent("Applications"),
                URL(fileURLWithPath: "/Users/Shared/Applications")]
    }

    func refreshIfStale(completion: (() -> Void)? = nil) {
        if let b = builtAt, Date().timeIntervalSince(b) < 300, !items.isEmpty { completion?(); return }
        queue.async { [weak self] in
            guard let self = self else { return }
            var found: [String: AppItem] = [:]
            let fm = FileManager.default
            for root in self.roots { self.scan(root, depth: 0, into: &found, fm: fm) }
            // Essenciais que nunca podem faltar, independentemente de flags no Info.plist
            for path in ["/System/Library/CoreServices/Finder.app", "/System/Applications/System Settings.app"] where found[path] == nil && fm.fileExists(atPath: path) {
                found[path] = StartIndex.item(for: URL(fileURLWithPath: path))
            }
            Log.info("índice do Iniciar: \(found.count) apps na varredura; Finder: \(found["/System/Library/CoreServices/Finder.app"] != nil)")
            DispatchQueue.main.async {
                self.scanned = found
                self.publish()
                self.builtAt = Date()
                completion?()
                self.startSpotlightQuery()
            }
        }
    }

    private func scan(_ dir: URL, depth: Int, into found: inout [String: AppItem], fm: FileManager) {
        guard depth <= 3,
              let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey, .isApplicationKey],
                                                         options: [.skipsHiddenFiles]) else { return }
        for url in contents {
            let vals = try? url.resourceValues(forKeys: [.isDirectoryKey, .isApplicationKey])
            if vals?.isApplication == true || url.pathExtension == "app" {
                if StartIndex.isUserFacing(url) { found[url.path] = StartIndex.item(for: url) }
            } else if vals?.isDirectory == true {
                scan(url, depth: depth + 1, into: &found, fm: fm)
            }
        }
    }

    /// Exclui agentes e processos de fundo (Dock, Siri, Spotlight, helpers): o que o app "Apps" também não lista.
    private static func isUserFacing(_ url: URL) -> Bool {
        guard let info = Bundle(url: url)?.infoDictionary else { return url.pathExtension == "app" }
        func flag(_ k: String) -> Bool {
            if let b = info[k] as? Bool { return b }
            if let n = info[k] as? NSNumber { return n.boolValue }
            if let s = info[k] as? String { return s == "1" || s.lowercased() == "yes" || s.lowercased() == "true" }
            return false
        }
        if let bid = info["CFBundleIdentifier"] as? String, bid == "com.apple.finder" { return true }
        if flag("LSUIElement") || flag("LSBackgroundOnly") { return false }
        if (info["CFBundlePackageType"] as? String ?? "APPL") != "APPL" { return false }
        return true
    }

    private static func item(for url: URL) -> AppItem {
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        return AppItem(name: name, url: url, bundleID: Bundle(url: url)?.bundleIdentifier)
    }

    // MARK: Spotlight (Launch Services) — pega o que está fora das pastas padrão
    private func startSpotlightQuery() {
        guard query == nil else { return }
        let q = NSMetadataQuery()
        q.predicate = NSPredicate(format: "kMDItemContentType == 'com.apple.application-bundle'")
        q.searchScopes = [NSMetadataQueryLocalComputerScope]
        NotificationCenter.default.addObserver(self, selector: #selector(spotlightFinished(_:)),
                                               name: .NSMetadataQueryDidFinishGathering, object: q)
        query = q
        q.start()
    }

    @objc private func spotlightFinished(_ n: Notification) {
        guard let q = query else { return }
        q.disableUpdates()
        var found: [String: AppItem] = [:]
        for i in 0..<q.resultCount {
            guard let item = q.result(at: i) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  StartIndex.looksInstalled(path) else { continue }
            found[path] = StartIndex.item(for: URL(fileURLWithPath: path))
        }
        q.stop()
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: q)
        query = nil
        spotlight = found
        publish()
    }

    /// Mesmos critérios práticos do app "Apps": só bundles de 1º nível em pastas de apps, nada embutido.
    private static func looksInstalled(_ path: String) -> Bool {
        let p = path as NSString
        guard p.pathExtension == "app" else { return false }
        // Não é um app dentro de outro app/bundle/framework
        let components = p.pathComponents
        if components.dropLast().contains(where: { $0.hasSuffix(".app") || $0.hasSuffix(".framework") || $0.hasSuffix(".bundle") || $0.hasSuffix(".xpc") }) { return false }
        let bad = ["/.Trash/", "/Library/Developer/", "/Xcode.app/", "/private/", "/Volumes/", "/Library/Caches/",
                   "/node_modules/", "/.build/", "/build/", "/DerivedData/", "/Backups.backupdb/", "/Library/Application Support/"]
        if bad.contains(where: { path.contains($0) }) { return false }
        if components.contains(where: { $0.hasPrefix(".") }) { return false }
        guard isUserFacing(URL(fileURLWithPath: path)) else { return false }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix("/Applications/") || path.hasPrefix("/System/Applications/")
            || path.hasPrefix("/System/Library/CoreServices/") || path.hasPrefix("/Users/Shared/")
            || path.hasPrefix(home + "/Applications/") || path.hasPrefix(home + "/Desktop/")
            || path.hasPrefix(home + "/Documents/") || path.hasPrefix(home + "/Downloads/")
    }

    private func publish() {
        var merged = scanned
        for (k, v) in spotlight where merged[k] == nil { merged[k] = v }
        // Mesmo app em dois caminhos (ex.: cópia em Downloads): mantém o que está em /Applications ou /System
        var byBundle: [String: AppItem] = [:]
        var noBundle: [AppItem] = []
        for item in merged.values {
            guard let b = item.bundleID else { noBundle.append(item); continue }
            if let existing = byBundle[b] {
                let preferNew = item.url.path.hasPrefix("/Applications/") || item.url.path.hasPrefix("/System/")
                let preferOld = existing.url.path.hasPrefix("/Applications/") || existing.url.path.hasPrefix("/System/")
                if preferNew && !preferOld { byBundle[b] = item }
            } else { byBundle[b] = item }
        }
        items = (Array(byBundle.values) + noBundle).sorted { $0.sortKey < $1.sortKey }
        NotificationCenter.default.post(name: StartIndex.changed, object: nil)
    }

    func search(_ q: String) -> [AppItem] {
        let needle = q.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        guard !needle.isEmpty else { return items }
        var starts: [AppItem] = [], wordStarts: [AppItem] = [], contains: [AppItem] = []
        for item in items {
            let key = item.sortKey
            if key.hasPrefix(needle) { starts.append(item) }
            else if key.split(separator: " ").contains(where: { $0.hasPrefix(needle) }) { wordStarts.append(item) }
            else if key.contains(needle) { contains.append(item) }
        }
        return starts + wordStarts + contains
    }
}
