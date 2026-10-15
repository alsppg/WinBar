import AppKit

/// Apps fixados na barra. Arquivo JSON em ~/Library/Application Support/WinBar/pins.json (0600).
final class PinStore {
    static let shared = PinStore()
    static let changed = Notification.Name("WinBar.pins.changed")

    private(set) var items: [PinnedItem] = []
    private let url: URL

    private struct File: Codable { var version: Int; var items: [PinnedItem] }

    private init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/WinBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o755])
        url = dir.appendingPathComponent("pins.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else {
            items = PinStore.defaults()
            save()
            return
        }
        items = file.items.sorted { $0.order < $1.order }
        renumber()
    }

    private static func defaults() -> [PinnedItem] {
        // Primeiros fixados: Finder não (já está sempre presente) — Safari, Mail e Ajustes se existirem.
        let candidates = ["com.apple.Safari"]
        var out: [PinnedItem] = []
        for b in candidates {
            if let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: b) {
                out.append(PinnedItem(id: b, path: u.path, name: nil, order: out.count))
            }
        }
        return out
    }

    private func renumber() {
        for i in items.indices { items[i].order = i }
    }

    private func save() {
        renumber()
        guard let data = try? JSONEncoder().encode(File(version: 1, items: items)) else { return }
        do {
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            Log.error("pins.json não pôde ser gravado")
        }
        NotificationCenter.default.post(name: PinStore.changed, object: nil)
    }

    func isPinned(_ bundleID: String) -> Bool { items.contains { $0.id == bundleID } }

    func pin(bundleID: String, url: URL) {
        guard !isPinned(bundleID) else { return }
        items.append(PinnedItem(id: bundleID, path: url.path, name: nil, order: items.count))
        save()
    }

    func unpin(bundleID: String) {
        items.removeAll { $0.id == bundleID }
        save()
    }

    /// Reordena os fixados segundo a ordem de bundleIDs dada (ids ausentes mantêm posição relativa no fim).
    func reorder(byBundleIDs order: [String]) {
        let index = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        items.sort { (index[$0.id] ?? Int.max, $0.order) < (index[$1.id] ?? Int.max, $1.order) }
        save()
    }
}
