import AppKit

/// Uma barra por tela: janela, layout, cliques, flyouts, menus de contexto e auto-ocultar.
final class BarController: NSObject, AppButtonDelegate, BarViewDelegate {
    let screen: NSScreen
    let window: BarWindow
    let view: BarView

    private var settings: Settings { SettingsStore.shared.s }
    private var barHeight: CGFloat { settings.barSize.height }

    // Flyouts
    private static var current: Flyout?
    private static var currentOwner: BarController?
    private var flyoutEntryID: String?
    private var flyoutIsHover = false
    private var hoverTimer: Timer?
    private var hoverWatch: Timer?
    private var outsideSince: Date?
    private var startMenu: StartMenu?

    // Auto-ocultar
    private var hidden = false
    private var hidePoll: Timer?
    private var leaveSince: Date?
    private var suppressed = false   // app em tela cheia

    init(screen: NSScreen) {
        self.screen = screen
        window = BarWindow(screen: screen)
        view = BarView(frame: .zero)
        super.init()
        view.delegate = self
        view.buttonDelegate = self
        window.contentView = view
        place(animated: false)
        window.orderFrontRegardless()

        NotificationCenter.default.addObserver(self, selector: #selector(appsChanged), name: AppTracker.changed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: SettingsStore.changed, object: nil)
        let wnc = NSWorkspace.shared.notificationCenter
        wnc.addObserver(self, selector: #selector(checkFullScreen), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        wnc.addObserver(self, selector: #selector(checkFullScreen), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        wnc.addObserver(self, selector: #selector(appActivated), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        appsChanged()
        settingsChanged()
    }

    func tearDown() {
        hidePoll?.invalidate(); hoverTimer?.invalidate(); hoverWatch?.invalidate()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        window.orderOut(nil)
    }

    // MARK: Posição
    private var shownFrame: NSRect {
        NSRect(x: screen.frame.minX, y: screen.frame.minY, width: screen.frame.width, height: barHeight)
    }
    private var hiddenFrame: NSRect {
        var f = shownFrame; f.origin.y -= barHeight - W10.Size.hiddenSliver; return f
    }

    private func place(animated: Bool) {
        let target = hidden ? hiddenFrame : shownFrame
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = W10.Motion.autohide
                ctx.timingFunction = W10.Motion.timing
                window.animator().setFrame(target, display: true)
            }
        } else {
            window.setFrame(target, display: true)
        }
    }

    @objc private func appsChanged() {
        view.apply(entries: AppTracker.shared.entries)
        // Se o flyout aberto pertence a um app que mudou de janelas, atualiza.
        if let id = flyoutEntryID, let fl = BarController.current as? ThumbnailFlyout, fl.entryID == id,
           let e = AppTracker.shared.entry(id: id), e.windows.count != fl.windowCount {
            openThumbnailFlyout(for: e, hover: flyoutIsHover)
        }
    }

    @objc private func settingsChanged() {
        place(animated: false)
        view.needsDisplay = true
        view.apply(entries: AppTracker.shared.entries)
        if settings.autoHide {
            if hidePoll == nil {
                hidePoll = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.pollAutoHide() }
            }
        } else {
            hidePoll?.invalidate(); hidePoll = nil
            if hidden { hidden = false; place(animated: true) }
        }
    }

    @objc private func appActivated() { DesktopToggle.shared.noteAppActivated() }

    // MARK: Tela cheia
    @objc private func checkFullScreen() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            let front = NSWorkspace.shared.frontmostApplication
            let full = front.map { WindowService.focusedWindowIsFullScreen(pid: $0.processIdentifier) } ?? false
            if full != self.suppressed {
                self.suppressed = full
                if full { self.window.orderOut(nil); self.closeFlyout() } else { self.window.orderFrontRegardless() }
            }
        }
    }

    // MARK: Auto-ocultar
    private func pollAutoHide() {
        guard settings.autoHide, !suppressed else { return }
        let m = NSEvent.mouseLocation
        let inScreenX = m.x >= screen.frame.minX && m.x <= screen.frame.maxX
        if hidden {
            if inScreenX && m.y <= screen.frame.minY + 1 { hidden = false; place(animated: true); leaveSince = nil }
        } else {
            let over = window.frame.insetBy(dx: 0, dy: -2).contains(m)
            let flyoutOpen = BarController.current?.isVisible == true && BarController.currentOwner === self
            if over || flyoutOpen { leaveSince = nil; return }
            if leaveSince == nil { leaveSince = Date() }
            if Date().timeIntervalSince(leaveSince!) >= W10.Motion.autohideDelay { hidden = true; place(animated: true) }
        }
    }

    // MARK: Flyouts
    private func closeFlyout() {
        BarController.current?.close()
        BarController.current = nil; BarController.currentOwner = nil
        flyoutEntryID = nil; flyoutIsHover = false
        hoverWatch?.invalidate(); hoverWatch = nil
        view.buttons.forEach { $0.flyoutOpen = false }
        view.startButton.isOpen = false; view.clock.isOpen = false
    }

    private func present(_ f: Flyout, anchor: NSView, alignLeft: Bool = false) {
        closeFlyout()
        BarController.current = f; BarController.currentOwner = self
        f.onClose = { [weak self] in
            guard let self = self, BarController.current === f else { return }
            BarController.current = nil; BarController.currentOwner = nil
            self.flyoutEntryID = nil
            self.view.buttons.forEach { $0.flyoutOpen = false }
            self.view.startButton.isOpen = false; self.view.clock.isOpen = false
        }
        let rectInWindow = anchor.convert(anchor.bounds, to: nil)
        let rectOnScreen = window.convertToScreen(rectInWindow)
        f.show(anchoredTo: rectOnScreen, onScreen: screen, alignLeft: alignLeft)
    }

    private func openThumbnailFlyout(for e: AppEntry, hover: Bool) {
        guard !e.windows.isEmpty else { return }
        let f = ThumbnailFlyout(entry: e)
        f.onActivate = { [weak self] w in self?.closeFlyout(); AXController.activate(w, app: e.app) }
        f.onCloseWindow = { [weak self] w in
            AXController.close([w], of: e.app)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { AppTracker.shared.scheduleRefresh() }
            if e.windows.count <= 1 { self?.closeFlyout() }
        }
        guard let btn = view.buttons.first(where: { $0.model.entry.id == e.id && $0.model.window == nil }) else { return }
        present(f, anchor: btn)
        flyoutEntryID = e.id
        flyoutIsHover = hover
        btn.flyoutOpen = true
        if hover { startHoverWatch(button: btn) }
    }

    /// Fecha o flyout de hover quando o mouse fica fora do botão e do painel por um instante.
    private func startHoverWatch(button: AppButton) {
        hoverWatch?.invalidate()
        outsideSince = nil
        hoverWatch = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self, weak button] _ in
            guard let self = self, let f = BarController.current, self.flyoutIsHover else { self?.hoverWatch?.invalidate(); return }
            let m = NSEvent.mouseLocation
            let btnRect = button.map { self.window.convertToScreen($0.convert($0.bounds, to: nil)) } ?? .zero
            let inside = f.frame.insetBy(dx: -4, dy: -4).contains(m) || btnRect.contains(m)
            if inside { self.outsideSince = nil; return }
            if self.outsideSince == nil { self.outsideSince = Date() }
            if Date().timeIntervalSince(self.outsideSince!) > 0.35 { self.closeFlyout() }
        }
    }

    // MARK: AppButtonDelegate
    func appButton(_ b: AppButton, clickedWith event: NSEvent) {
        let m = b.model, e = m.entry
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if mods.contains(.command) { if let u = e.url { NSWorkspace.shared.activateFileViewerSelecting([u]) }; return }
        if mods.contains(.shift) { if let app = e.app { AXController.newWindow(app: app) } else { launch(e) }; return }
        if mods.contains(.option) { if let app = e.app { _ = app.isHidden ? app.unhide() : app.hide() }; return }

        if let w = m.window {   // botão de janela (modo "clássico"): traz essa janela para a frente
            if m.isActive && !w.isMinimized && settings.clickActiveMinimizes { AXController.minimize(w) }
            else { AXController.activate(w, app: e.app) }
            return
        }
        guard let app = e.app else { launch(e); return }
        closeFlyout()
        switch e.windows.count {
        case 0: AXController.activate(app: app)
        case 1:
            let w = e.windows[0]
            if e.isActive && !w.isMinimized && !e.isHidden && settings.clickActiveMinimizes { AXController.minimize(w) }
            else { AXController.activate(w, app: app) }
        default:
            // Clique sempre traz o app inteiro para a frente, com a última janela usada por cima.
            // A lista de miniaturas fica só no "passar o mouse".
            AXController.activate(app: app, preferring: e.windows)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { AppTracker.shared.scheduleRefresh() }
    }

    private func launch(_ e: AppEntry) {
        guard let url = e.url else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, err in
            if err != nil { Log.warn("falha ao abrir app fixado") }
        }
    }

    func appButton(_ b: AppButton, middleClickedWith event: NSEvent) {
        let e = b.model.entry
        if let w = b.model.window { AXController.close([w], of: e.app); return }
        if let app = e.app { AXController.newWindow(app: app) } else { launch(e) }
    }

    func appButton(_ b: AppButton, rightClickedWith event: NSEvent) {
        closeFlyout()
        let e = b.model.entry
        let menu = NSMenu()
        func add(_ title: String, _ action: @escaping () -> Void) {
            let item = NSMenuItem(title: title, action: #selector(runMenuAction(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = MenuAction(action)
            menu.addItem(item)
        }
        let header = NSMenuItem(title: e.name, action: nil, keyEquivalent: ""); header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())
        if let app = e.app { add("Nova janela") { AXController.newWindow(app: app) } }
        else { add("Abrir") { [weak self] in self?.launch(e) } }
        if let bid = e.bundleID, let url = e.url {
            if e.isPinned { add("Remover da Barra de Tarefas") { PinStore.shared.unpin(bundleID: bid) } }
            else { add("Adicionar à Barra de Tarefas") { PinStore.shared.pin(bundleID: bid, url: url) } }
        }
        if let u = e.url { add("Mostrar no Finder") { NSWorkspace.shared.activateFileViewerSelecting([u]) } }
        if let app = e.app {
            menu.addItem(.separator())
            add(app.isHidden ? "Mostrar" : "Ocultar") { _ = app.isHidden ? app.unhide() : app.hide() }
            menu.addItem(.separator())
            // Ordem pedida: Forçar encerrar, depois Fechar janela(s) e Sair
            add("Forçar encerrar") { [weak self] in self?.confirmForceQuit(app, name: e.name) }
            if let w = b.model.window {
                add("Fechar janela") { AXController.close([w], of: app) }
            } else if e.windows.count == 1 {
                add("Fechar janela") { AXController.close([e.windows[0]], of: app) }
            } else if e.windows.count > 1 {
                add("Fechar todas as janelas (\(e.windows.count))") { AXController.close(e.windows, of: app) }
            }
            if e.bundleID == "com.apple.finder" { add("Relançar o Finder") { app.terminate() } }
            else { add("Sair") { AXController.quit(app) } }
        }
        let p = b.convert(b.bounds, to: nil)
        menu.popUp(positioning: nil, at: NSPoint(x: p.minX, y: p.maxY), in: view)
    }

    private func confirmForceQuit(_ app: NSRunningApplication, name: String) {
        let a = NSAlert()
        a.messageText = "Forçar encerrar \(name)?"
        a.informativeText = "Alterações não salvas serão perdidas."
        a.addButton(withTitle: "Forçar encerrar"); a.addButton(withTitle: "Cancelar")
        NSApp.activate()
        if a.runModal() == .alertFirstButtonReturn { app.forceTerminate() }
    }

    final class MenuAction { let run: () -> Void; init(_ r: @escaping () -> Void) { run = r } }
    @objc private func runMenuAction(_ sender: NSMenuItem) {
        (sender.representedObject as? MenuAction)?.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { AppTracker.shared.scheduleRefresh() }
    }

    func appButtonHoverBegan(_ b: AppButton) {
        hoverTimer?.invalidate()
        let e = b.model.entry
        guard b.model.window == nil, !e.windows.isEmpty else { return }
        // Já há um flyout de hover aberto: troca na hora (comportamento do Win10).
        if flyoutIsHover, BarController.current != nil, flyoutEntryID != e.id {
            openThumbnailFlyout(for: e, hover: true); return
        }
        guard BarController.current == nil else { return }
        let delay = TimeInterval(settings.previewDelayMs) / 1000
        hoverTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self, weak b] _ in
            guard let self = self, let b = b, b.hovered, BarController.current == nil,
                  let fresh = AppTracker.shared.entry(id: e.id) else { return }
            self.openThumbnailFlyout(for: fresh, hover: true)
        }
    }

    func appButtonHoverEnded(_ b: AppButton) { hoverTimer?.invalidate() }

    func appButtonDragBegan(_ b: AppButton) { closeFlyout(); hoverTimer?.invalidate(); view.beginDrag(b) }
    func appButton(_ b: AppButton, dragMovedTo x: CGFloat) { view.dragMoved(b, x: x) }
    func appButtonDragEnded(_ b: AppButton) { view.endDrag(b) }

    // MARK: BarViewDelegate
    func barViewStartClicked(_ v: BarView, button: StartButton) { toggleStart() }

    func toggleStart() {
        if let s = startMenu, s.isVisible { closeFlyout(); return }
        let s = StartMenu()
        s.onOpenSettings = { (NSApp.delegate as? AppDelegate)?.showSettings() }
        startMenu = s
        present(s, anchor: view.startButton, alignLeft: true)
        view.startButton.isOpen = true
    }

    func barViewClockClicked(_ v: BarView, button: ClockView) {
        if BarController.current is ClockFlyout { closeFlyout(); return }
        present(ClockFlyout(), anchor: button)
        button.isOpen = true
    }

    func barViewShowDesktopClicked(_ v: BarView) { closeFlyout(); DesktopToggle.shared.toggle() }
    func barViewBackgroundClicked(_ v: BarView) { closeFlyout(); DesktopToggle.shared.toggle() }

    func barView(_ v: BarView, backgroundRightClicked event: NSEvent) {
        closeFlyout()
        let menu = NSMenu()
        func add(_ title: String, checked: Bool = false, _ action: @escaping () -> Void) {
            let item = NSMenuItem(title: title, action: #selector(runMenuAction(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = MenuAction(action); item.state = checked ? .on : .off
            menu.addItem(item)
        }
        add("Mostrar área de trabalho") { DesktopToggle.shared.toggle() }
        add("Mission Control") { AXController.openMissionControl() }
        menu.addItem(.separator())
        add("Ocultar automaticamente a barra", checked: settings.autoHide) { SettingsStore.shared.settings.autoHide.toggle() }
        add("Manter janelas acima da barra", checked: settings.keepWindowsAboveBar) { SettingsStore.shared.settings.keepWindowsAboveBar.toggle() }
        add("Encerrar o app ao fechar a última janela", checked: settings.quitOnLastWindowClose) { SettingsStore.shared.settings.quitOnLastWindowClose.toggle() }
        add("Ajustar janelas à barra agora") { WindowHerder.shared.herdAll(expandFullHeight: true) }
        menu.addItem(.separator())
        // Estilo dos botões (3 opções, como "Combinar botões da barra de tarefas" do Win10)
        let styleMenu = NSMenu()
        for mode in CombineMode.allCases {
            let it = NSMenuItem(title: mode.label, action: #selector(runMenuAction(_:)), keyEquivalent: "")
            it.target = self
            it.state = (settings.combineButtons == mode && !(mode == .always && settings.showLabels)) ? .on : .off
            it.representedObject = MenuAction { SettingsStore.shared.settings.combineButtons = mode; SettingsStore.shared.settings.showLabels = false }
            styleMenu.addItem(it)
            if mode == .always {
                let named = NSMenuItem(title: "Ícones com nome do app (combinar)", action: #selector(runMenuAction(_:)), keyEquivalent: "")
                named.target = self
                named.state = (settings.combineButtons == .always && settings.showLabels) ? .on : .off
                named.representedObject = MenuAction { SettingsStore.shared.settings.combineButtons = .always; SettingsStore.shared.settings.showLabels = true }
                styleMenu.addItem(named)
            }
        }
        let styleItem = NSMenuItem(title: "Estilo dos botões", action: nil, keyEquivalent: "")
        styleItem.submenu = styleMenu
        menu.addItem(styleItem)
        // Altura da barra
        let sizeMenu = NSMenu()
        for size in BarSize.allCases {
            let it = NSMenuItem(title: size.label, action: #selector(runMenuAction(_:)), keyEquivalent: "")
            it.target = self
            it.state = settings.barSize == size ? .on : .off
            it.representedObject = MenuAction { SettingsStore.shared.settings.barSize = size }
            sizeMenu.addItem(it)
        }
        let sizeItem = NSMenuItem(title: "Altura da barra", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)
        menu.addItem(.separator())
        add("Ajustes…") { (NSApp.delegate as? AppDelegate)?.showSettings() }
        add("Sair do WinBar") { NSApp.terminate(nil) }
        let p = view.convert(event.locationInWindow, from: nil)
        menu.popUp(positioning: nil, at: p, in: view)
    }

    func barViewDidRelayout(_ v: BarView) {}

    // MARK: Atalhos
    func activateButton(index: Int) {
        guard index >= 0, index < view.buttons.count else { return }
        let b = view.buttons[index]
        let m = b.model
        if let w = m.window { AXController.activate(w, app: m.entry.app); return }
        if let app = m.entry.app {
            if let w = m.entry.windows.first { AXController.activate(w, app: app) } else { AXController.activate(app: app) }
        } else { launch(m.entry) }
    }
}
