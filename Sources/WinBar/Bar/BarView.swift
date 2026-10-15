import AppKit

protocol BarViewDelegate: AnyObject {
    func barViewStartClicked(_ v: BarView, button: StartButton)
    func barViewClockClicked(_ v: BarView, button: ClockView)
    func barViewShowDesktopClicked(_ v: BarView)
    func barView(_ v: BarView, backgroundRightClicked event: NSEvent)
    func barViewBackgroundClicked(_ v: BarView)
    func barViewDidRelayout(_ v: BarView)
}

/// Conteúdo da barra: [Start][botões de apps][relógio][mostrar área de trabalho].
final class BarView: NSView {
    weak var delegate: BarViewDelegate?
    weak var buttonDelegate: AppButtonDelegate?

    let startButton = StartButton(frame: .zero)
    let clock = ClockView(frame: .zero)
    let showDesktop = ShowDesktopSliver(frame: .zero)
    let spaces = SpacesButton(frame: .zero)
    private(set) var buttons: [AppButton] = []
    private var buttonsByKey: [String: AppButton] = [:]

    private var settings: Settings { SettingsStore.shared.s }
    private var draggingButton: AppButton?
    private var dragOrder: [String] = []      // ordem de ids de app durante o arrasto
    private var dropHighlight = false { didSet { needsDisplay = true } }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        setAccessibilityRole(.toolbar)
        setAccessibilityLabel("Barra de tarefas")
        addSubview(startButton); addSubview(clock); addSubview(showDesktop); addSubview(spaces)
        startButton.onClick = { [weak self] _ in guard let s = self else { return }; s.delegate?.barViewStartClicked(s, button: s.startButton) }
        clock.onClick = { [weak self] _ in guard let s = self else { return }; s.delegate?.barViewClockClicked(s, button: s.clock) }
        showDesktop.onClick = { [weak self] _ in guard let s = self else { return }; s.delegate?.barViewShowDesktopClicked(s) }
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { return nil }

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func rightMouseDown(with event: NSEvent) { delegate?.barView(self, backgroundRightClicked: event) }
    override func mouseDown(with event: NSEvent) { /* fundo: espera o mouseUp */ }
    override func mouseUp(with event: NSEvent) {
        // Só chega aqui quando o clique não caiu em nenhum botão: área vazia da barra.
        if bounds.contains(convert(event.locationInWindow, from: nil)) { delegate?.barViewBackgroundClicked(self) }
    }

    // MARK: Cursor sempre padrão sobre a barra (a zona de redimensionar das janelas acima invade os primeiros px)
    private var cursorTracking: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = cursorTracking { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds, options: [.cursorUpdate, .mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(t); cursorTracking = t
    }
    override func cursorUpdate(with event: NSEvent) { NSCursor.arrow.set() }
    override func mouseMoved(with event: NSEvent) { NSCursor.arrow.set() }
    override func mouseEntered(with event: NSEvent) { NSCursor.arrow.set(); startCursorGuard() }
    override func mouseExited(with event: NSEvent) { stopCursorGuard() }

    /// Enquanto o ponteiro está sobre a barra, reimpõe a seta a cada 80 ms (vence qualquer app que troque o cursor).
    private var cursorGuard: Timer?
    private func startCursorGuard() {
        cursorGuard?.invalidate()
        cursorGuard = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] t in
            guard let self = self, let win = self.window else { t.invalidate(); return }
            if win.frame.contains(NSEvent.mouseLocation) { NSCursor.arrow.set() } else { t.invalidate(); self.cursorGuard = nil }
        }
    }
    private func stopCursorGuard() { cursorGuard?.invalidate(); cursorGuard = nil }

    // MARK: Modelos → botões
    func apply(entries: [AppEntry]) {
        guard draggingButton == nil else { return }   // durante o arrasto, a ordem visual manda
        let s = settings
        let models = BarView.models(for: entries, mode: s.combineButtons, showLabels: s.showLabels, available: appsAreaWidth, size: s.barSize)
        var newButtons: [AppButton] = []
        var newByKey: [String: AppButton] = [:]
        for m in models {
            let b = buttonsByKey[m.key] ?? AppButton(model: m)
            b.model = m
            b.delegate = buttonDelegate
            b.useAccent = s.useAccentColor
            b.size = s.barSize
            if b.superview == nil { addSubview(b) }
            newButtons.append(b); newByKey[m.key] = b
        }
        for (k, b) in buttonsByKey where newByKey[k] == nil { b.removeFromSuperview() }
        buttons = newButtons; buttonsByKey = newByKey
        relayout()
    }

    /// Converte entradas em modelos de botão conforme o modo de combinação e o espaço disponível.
    static func models(for entries: [AppEntry], mode: CombineMode, showLabels: Bool, available: CGFloat, size: BarSize) -> [ButtonModel] {
        func perWindow() -> [ButtonModel] {
            entries.flatMap { e -> [ButtonModel] in
                // Fixado fechado = só ícone (colado ao Iniciar, como no Windows); app aberto sem janela = nome do app
                e.windows.isEmpty ? [ButtonModel(entry: e, window: nil, showLabel: e.isRunning)]
                                  : e.windows.map { ButtonModel(entry: e, window: $0, showLabel: true) }
            }
        }
        func perApp(labels: Bool) -> [ButtonModel] { entries.map { ButtonModel(entry: $0, window: nil, showLabel: labels && $0.isRunning) } }
        switch mode {
        case .always: return perApp(labels: showLabels)
        case .never: return perWindow()
        case .whenFull:
            let pw = perWindow()
            if BarView.minimumWidth(for: pw, size: size) <= available { return pw }
            let pa = perApp(labels: true)
            if BarView.minimumWidth(for: pa, size: size) <= available { return pa }
            return perApp(labels: false)
        }
    }

    private static func minimumWidth(for models: [ButtonModel], size: BarSize) -> CGFloat {
        models.reduce(0) { $0 + ($1.showLabel ? size.labelMin : size.buttonWidth) }
    }

    // MARK: Layout
    var appsAreaWidth: CGFloat { max(bounds.width - settings.barSize.startWidth - trayWidth, 0) }

    private var trayWidth: CGFloat {
        var w: CGFloat = W10.Size.trayPadding
        if settings.showClock { w += clock.preferredWidth }
        if settings.showSpaces { w += spaces.preferredWidth }
        if settings.showDesktopButton { w += W10.Size.showDesktopWidth }
        return w
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        relayout()
    }

    func relayout() {
        let h = bounds.height
        let size = settings.barSize
        startButton.frame = NSRect(x: 0, y: 0, width: size.startWidth, height: h)

        // Bandeja (direita → esquerda)
        var right = bounds.width
        showDesktop.isHidden = !settings.showDesktopButton
        if settings.showDesktopButton {
            right -= W10.Size.showDesktopWidth
            showDesktop.frame = NSRect(x: right, y: 0, width: W10.Size.showDesktopWidth, height: h)
        }
        clock.isHidden = !settings.showClock
        if settings.showClock {
            let cw = clock.preferredWidth
            right -= cw
            clock.frame = NSRect(x: right, y: 0, width: cw, height: h)
        }
        spaces.isHidden = !settings.showSpaces
        if settings.showSpaces {
            let sw = spaces.preferredWidth
            right -= sw
            spaces.frame = NSRect(x: right, y: 0, width: sw, height: h)
        }
        right -= W10.Size.trayPadding

        // Botões de apps
        let available = max(right - size.startWidth, 0)
        let widths = BarView.widths(for: buttons.map { $0.model }, available: available, size: size)
        var x = size.startWidth
        let dragged = draggingButton
        for (i, b) in buttons.enumerated() {
            let w = widths[i]
            if b === dragged { x += w; continue }      // o arrastado é posicionado pelo mouse
            b.frame = NSRect(x: x, y: 0, width: w, height: h)
            x += w
        }
        delegate?.barViewDidRelayout(self)
    }

    /// Larguras por botão: rótulos entre min e max; se não cabe, encolhe uniformemente até o mínimo absoluto.
    static func widths(for models: [ButtonModel], available: CGFloat, size: BarSize) -> [CGFloat] {
        let iconW = size.buttonWidth
        let font = NSFont.systemFont(ofSize: size.fontSize)
        var ideal: [CGFloat] = models.map { m in
            guard m.showLabel else { return iconW }
            let tw = (m.label as NSString).size(withAttributes: [.font: font]).width
            let want = W10.Space.md + size.icon + W10.Size.labelGap + ceil(tw) + W10.Space.md
            return min(max(want, size.labelMin), size.labelMax)
        }
        let total = ideal.reduce(0, +)
        guard total > available, total > 0 else { return ideal }
        // 1) encolhe rótulos até o mínimo
        let labeledIdx = models.indices.filter { models[$0].showLabel }
        let fixed = models.indices.filter { !models[$0].showLabel }.reduce(0) { $0 + ideal[$1] }
        if !labeledIdx.isEmpty {
            let roomForLabels = max(available - fixed, 0)
            let minLabels = CGFloat(labeledIdx.count) * size.labelMin
            if roomForLabels >= minLabels {
                let currentLabels = labeledIdx.reduce(0) { $0 + ideal[$1] }
                let factor = roomForLabels / currentLabels
                for i in labeledIdx { ideal[i] = max(ideal[i] * factor, size.labelMin) }
                return ideal
            }
        }
        // 2) encolhe tudo uniformemente até o mínimo absoluto
        let factor = available / total
        return ideal.map { max($0 * factor, W10.Size.buttonMinWhenFull) }
    }

    // MARK: Arrasto para reordenar
    func beginDrag(_ b: AppButton) {
        draggingButton = b
        dragOrder = orderedAppIDs()
        b.layer?.zPosition = 10   // fica por cima dos vizinhos sem sair da hierarquia (manter o tracking do mouse)
    }

    func dragMoved(_ b: AppButton, x: CGFloat) {
        guard draggingButton === b else { return }
        b.frame.origin.x = x - b.frame.width / 2
        // Índice alvo pelo centro do botão arrastado comparado aos centros dos demais (agrupado por app)
        let appID = b.model.entry.id
        var ids = dragOrder.filter { $0 != appID }
        let others = buttons.filter { $0 !== b && $0.model.entry.id != appID }
        var insertAt = ids.count
        for (i, id) in ids.enumerated() {
            guard let first = others.first(where: { $0.model.entry.id == id }) else { continue }
            if x < first.frame.midX { insertAt = i; break }
        }
        ids.insert(appID, at: insertAt)
        if ids != dragOrder {
            dragOrder = ids
            resortButtons(by: ids)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = W10.Motion.hover
                relayout()
            }
        }
    }

    func endDrag(_ b: AppButton) {
        guard draggingButton === b else { return }
        draggingButton = nil
        b.layer?.zPosition = 0
        AppTracker.shared.commitOrder(dragOrder)
        relayout()
    }

    private func orderedAppIDs() -> [String] {
        var seen = Set<String>(); var out: [String] = []
        for b in buttons where !seen.contains(b.model.entry.id) { seen.insert(b.model.entry.id); out.append(b.model.entry.id) }
        return out
    }

    private func resortButtons(by ids: [String]) {
        let idx = Dictionary(ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        buttons.sort { (idx[$0.model.entry.id] ?? 0, $0.model.key) < (idx[$1.model.entry.id] ?? 0, $1.model.key) }
    }

    // MARK: Soltar .app do Finder = fixar
    private func appURLs(from info: NSDraggingInfo) -> [URL] {
        let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                      options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return urls.filter { $0.pathExtension == "app" }
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let ok = !appURLs(from: sender).isEmpty
        dropHighlight = ok
        return ok ? .link : []
    }
    override func draggingExited(_ sender: NSDraggingInfo?) { dropHighlight = false }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        dropHighlight = false
        var any = false
        for url in appURLs(from: sender) {
            if let bid = Bundle(url: url)?.bundleIdentifier { PinStore.shared.pin(bundleID: bid, url: url); any = true }
        }
        return any
    }

    // MARK: Fundo
    override func draw(_ dirtyRect: NSRect) {
        let s = settings
        W10.barColor(useAccent: s.useAccentColor, transparent: s.transparency).setFill()
        bounds.fill()
        W10.Overlay.topEdge.setFill()
        NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1).fill()
        if dropHighlight { W10.Overlay.hover.setFill(); bounds.fill() }
    }
}
