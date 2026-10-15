import AppKit

/// Menu Iniciar: trilho de atalhos à esquerda, busca no topo e lista A-Z de apps.
final class StartMenu: Flyout, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate, NSMenuDelegate {
    private enum Row { case header(String); case app(AppItem) }
    private var rows: [Row] = []
    private let search = NSSearchField()
    private let table = NSTableView()
    private let empty = makeLabel("Nenhum resultado", font: W10.Font.base, color: W10.Color.textMuted, align: .center)
    var onOpenSettings: (() -> Void)?

    init() {
        super.init(size: NSSize(width: W10.Size.startMenuWidth, height: W10.Size.startMenuHeight), wantsKey: true)
        let rail = W10.Size.startRailWidth
        let pad = W10.Size.flyoutPadding
        let h = content.bounds.height, w = content.bounds.width

        // Trilho esquerdo
        let railBG = NSView(frame: NSRect(x: 0, y: 0, width: rail, height: h))
        railBG.wantsLayer = true; railBG.layer?.backgroundColor = W10.Color.bg.withAlphaComponent(0.5).cgColor
        content.addSubview(railBG)
        let home = FileManager.default.homeDirectoryForCurrentUser
        let railItems: [(String, String, () -> Void)] = [
            ("power", "Ligar/Desligar", { [weak self] in self?.powerMenu() }),
            ("gearshape", "Ajustes do WinBar", { [weak self] in self?.close(); self?.onOpenSettings?() }),
            ("arrow.down.circle", "Downloads", { [weak self] in self?.open(folder: home.appendingPathComponent("Downloads")) }),
            ("doc", "Documentos", { [weak self] in self?.open(folder: home.appendingPathComponent("Documents")) }),
            ("person.crop.circle", NSFullUserName(), { [weak self] in self?.open(folder: home) }),
        ]
        for (i, item) in railItems.enumerated() {
            let b = RailButton(frame: NSRect(x: 0, y: CGFloat(i) * rail, width: rail, height: rail), symbol: item.0, label: item.1)
            b.onClick = { _ in item.2() }
            if i == 0 { b.isPowerButton = true }
            content.addSubview(b)
        }

        // Busca
        search.frame = NSRect(x: rail + pad, y: h - pad - 32, width: w - rail - pad * 2, height: 32)
        search.placeholderString = "Buscar aplicativos"
        search.font = W10.Font.md
        search.delegate = self
        search.focusRingType = .none
        search.appearance = NSAppearance(named: .darkAqua)
        search.target = self; search.action = #selector(searchChanged)
        search.sendsSearchStringImmediately = true
        search.sendsWholeSearchString = false
        content.addSubview(search)

        // Lista
        let scroll = NSScrollView(frame: NSRect(x: rail, y: 0, width: w - rail, height: h - pad * 2 - 32))
        scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        scroll.appearance = NSAppearance(named: .darkAqua)
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c"))
        col.width = scroll.bounds.width - 16
        table.addTableColumn(col)
        table.headerView = nil
        table.backgroundColor = .clear
        table.rowHeight = W10.Size.startRowHeight
        table.intercellSpacing = .zero
        table.selectionHighlightStyle = .none
        table.dataSource = self; table.delegate = self
        table.target = self; table.action = #selector(rowClicked)
        table.allowsEmptySelection = true
        let rowMenu = NSMenu(); rowMenu.delegate = self
        table.menu = rowMenu
        scroll.documentView = table
        content.addSubview(scroll)

        empty.frame = NSRect(x: rail, y: h / 2, width: w - rail, height: 24)
        empty.isHidden = true
        content.addSubview(empty)

        reload(query: "")
        StartIndex.shared.refreshIfStale { [weak self] in self?.reload(query: self?.search.stringValue ?? "") }
        NotificationCenter.default.addObserver(self, selector: #selector(indexChanged), name: StartIndex.changed, object: nil)
    }

    @objc private func indexChanged() { reload(query: search.stringValue) }

    override func show(anchoredTo anchor: NSRect, onScreen screen: NSScreen, alignLeft: Bool = false) {
        search.stringValue = ""
        reload(query: "")
        super.show(anchoredTo: anchor, onScreen: screen, alignLeft: true)
        window.makeFirstResponder(search)
    }

    private func reload(query: String) {
        let items = StartIndex.shared.search(query)
        var out: [Row] = []
        if query.isEmpty {
            var last = ""
            for it in items {
                if it.sectionLetter != last { last = it.sectionLetter; out.append(.header(last)) }
                out.append(.app(it))
            }
        } else {
            out = items.map { .app($0) }
        }
        rows = out
        empty.isHidden = !items.isEmpty
        table.reloadData()
        if !query.isEmpty, let first = rows.firstIndex(where: { if case .app = $0 { return true } else { return false } }) {
            table.selectRowIndexes([first], byExtendingSelection: false)
            table.scrollRowToVisible(first)
        }
    }

    @objc private func searchChanged() { reload(query: search.stringValue) }
    func controlTextDidChange(_ obj: Notification) { reload(query: search.stringValue) }

    // MARK: Tabela
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if case .header = rows[row] { return 28 }
        return W10.Size.startRowHeight
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { StartRowView() }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if case .app = rows[row] { return true }
        return false
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let v = NSView()
        switch rows[row] {
        case .header(let letter):
            let l = makeLabel(letter, font: W10.Font.lg, color: W10.Color.accentLight)
            l.frame = NSRect(x: W10.Space.lg, y: 0, width: 60, height: 28)
            v.addSubview(l)
        case .app(let item):
            let icon = NSImageView(frame: NSRect(x: W10.Space.lg, y: 6, width: 24, height: 24))
            icon.image = NSWorkspace.shared.icon(forFile: item.url.path)
            icon.imageScaling = .scaleProportionallyUpOrDown
            v.addSubview(icon)
            let l = makeLabel(item.name, font: W10.Font.base)
            l.frame = NSRect(x: W10.Space.lg + 24 + W10.Space.md, y: 9, width: 260, height: 18)
            v.addSubview(l)
        }
        return v
    }

    @objc private func rowClicked() { openRow(table.clickedRow) }

    // MARK: Clique direito numa linha de app
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let r = table.clickedRow
        guard r >= 0, r < rows.count, case .app(let item) = rows[r] else { return }
        let bid = item.bundleID ?? Bundle(url: item.url)?.bundleIdentifier
        func add(_ title: String, _ action: @escaping () -> Void) {
            let mi = NSMenuItem(title: title, action: #selector(rowMenuAction(_:)), keyEquivalent: "")
            mi.target = self; mi.representedObject = RowAction(action); menu.addItem(mi)
        }
        add("Abrir") { [weak self] in self?.openRow(r) }
        if let bid = bid {
            if PinStore.shared.isPinned(bid) {
                add("Remover da Barra de Tarefas") { PinStore.shared.unpin(bundleID: bid) }
            } else {
                add("Adicionar à Barra de Tarefas") { PinStore.shared.pin(bundleID: bid, url: item.url) }
            }
        }
        menu.addItem(.separator())
        add("Mostrar no Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
    }

    final class RowAction { let run: () -> Void; init(_ r: @escaping () -> Void) { run = r } }
    @objc private func rowMenuAction(_ sender: NSMenuItem) { (sender.representedObject as? RowAction)?.run() }

    private func openRow(_ r: Int) {
        guard r >= 0, r < rows.count, case .app(let item) = rows[r] else { return }
        close()
        NSWorkspace.shared.openApplication(at: item.url, configuration: NSWorkspace.OpenConfiguration()) { _, err in
            if err != nil { Log.warn("falha ao abrir app pelo Iniciar") }
        }
    }

    // MARK: Teclado no campo de busca
    func control(_ control: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        switch sel {
        case #selector(NSResponder.moveDown(_:)): move(1); return true
        case #selector(NSResponder.moveUp(_:)): move(-1); return true
        case #selector(NSResponder.insertNewline(_:)):
            let r = table.selectedRow >= 0 ? table.selectedRow : (rows.firstIndex { if case .app = $0 { return true } else { return false } } ?? -1)
            openRow(r); return true
        case #selector(NSResponder.cancelOperation(_:)): close(); return true
        default: return false
        }
    }

    private func move(_ delta: Int) {
        var r = table.selectedRow
        repeat { r += delta } while r >= 0 && r < rows.count && !tableView(table, shouldSelectRow: r)
        guard r >= 0, r < rows.count else { return }
        table.selectRowIndexes([r], byExtendingSelection: false)
        table.scrollRowToVisible(r)
    }

    // MARK: Ações do trilho
    private func open(folder: URL) { close(); NSWorkspace.shared.open(folder) }

    private func powerMenu() {
        let m = NSMenu()
        let items: [(String, PowerActions.Kind)] = [("Suspender", .sleep), ("Bloquear", .lock), ("Encerrar sessão…", .logOut),
                                                    ("Reiniciar…", .restart), ("Desligar…", .shutDown)]
        for (i, item) in items.enumerated() {
            let mi = NSMenuItem(title: item.0, action: #selector(powerItem(_:)), keyEquivalent: "")
            mi.target = self; mi.tag = i
            m.addItem(mi)
        }
        m.popUp(positioning: nil, at: NSPoint(x: W10.Size.startRailWidth, y: W10.Size.startRailWidth), in: content)
    }

    @objc private func powerItem(_ sender: NSMenuItem) {
        let kinds: [PowerActions.Kind] = [.sleep, .lock, .logOut, .restart, .shutDown]
        close()
        PowerActions.perform(kinds[sender.tag])
    }
}

/// Linha da lista do Iniciar com destaque de seleção/hover no estilo da skin.
final class StartRowView: NSTableRowView {
    private var hovered = false { didSet { needsDisplay = true } }
    private var tracking: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = tracking { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(t); tracking = t
    }
    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false }
    override func drawSelection(in dirtyRect: NSRect) { W10.Overlay.active.setFill(); bounds.fill() }
    override func drawBackground(in dirtyRect: NSRect) {
        if hovered && !isSelected { W10.Overlay.hover.setFill(); bounds.fill() }
    }
}

/// Botão do trilho esquerdo do Iniciar (ícone SF Symbol via NSImageView com tint).
final class RailButton: BarControl {
    var isPowerButton = false
    private let imageView = NSImageView()
    init(frame: NSRect, symbol: String, label: String) {
        super.init(frame: frame)
        setAccessibilityLabel(label); toolTip = label
        imageView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)?
            .withSymbolConfiguration(.init(pointSize: 16, weight: .regular))
        imageView.contentTintColor = W10.Color.text
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.frame = NSRect(x: (frame.width - 20) / 2, y: (frame.height - 20) / 2, width: 20, height: 20)
        addSubview(imageView)
    }
    required init?(coder: NSCoder) { return nil }
    override func draw(_ dirtyRect: NSRect) { drawBackground() }
}
