import AppKit
import ApplicationServices

/// Mantém as janelas dos outros apps acima da barra ("área reservada" do Win10, que o macOS não oferece a terceiros).
/// - Contínuo: observa mover/redimensionar/criar janela via AXObserver e, se a janela invadir a barra, encurta ou sobe.
/// - Manual ("ajustar agora"): além de empurrar, estica janelas de altura cheia que pararam acima da barra
///   (a faixa vazia deixada pelo Dock antigo), para terminarem exatamente no topo da barra.
final class WindowHerder {
    static let shared = WindowHerder()

    private var observers: [pid_t: AXObserver] = [:]
    private var pending: [AXUIElement] = []
    private var pendingTimer: Timer?
    private var sweepTimer: Timer?
    private var enabled = false
    private let minHeight: CGFloat = 120
    private let expandRange: CGFloat = 200   // janelas que param até 200 pt acima da barra são esticadas no ajuste manual
    /// Quanto a janela entra por baixo da barra: cobre a alça de redimensionar (~4 px dentro + 4 px fora da borda),
    /// que senão mostra a seta dupla na fronteira. A barra impõe o cursor normal sobre si.
    private let overlap: CGFloat = 6

    private init() {}

    // MARK: liga/desliga
    func setEnabled(_ on: Bool) {
        guard on != enabled else { return }
        enabled = on
        if on {
            for app in regularApps() { addObserver(for: app) }
            let nc = NSWorkspace.shared.notificationCenter
            nc.addObserver(self, selector: #selector(appLaunched(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
            nc.addObserver(self, selector: #selector(appTerminated(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
            sweepTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in self?.herdAll(expandFullHeight: false) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.herdAll(expandFullHeight: true) }
            Log.info("herder ligado")
        } else {
            NSWorkspace.shared.notificationCenter.removeObserver(self)
            sweepTimer?.invalidate(); sweepTimer = nil
            for (_, obs) in observers { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode) }
            observers.removeAll()
            Log.info("herder desligado")
        }
    }

    private func regularApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }
    }

    @objc private func appLaunched(_ n: Notification) {
        guard let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, app.activationPolicy == .regular else { return }
        // Espera o app terminar de abrir para o AX responder.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.addObserver(for: app)
            self?.herdAll(expandFullHeight: false)
        }
    }

    @objc private func appTerminated(_ n: Notification) {
        guard let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        if let obs = observers.removeValue(forKey: app.processIdentifier) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        }
    }

    // MARK: AXObserver
    private static let callback: AXObserverCallback = { _, element, _, refcon in
        guard let refcon = refcon else { return }
        let herder = Unmanaged<WindowHerder>.fromOpaque(refcon).takeUnretainedValue()
        herder.schedule(element)
    }

    private func addObserver(for app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard observers[pid] == nil else { return }
        var obs: AXObserver?
        guard AXObserverCreate(pid, WindowHerder.callback, &obs) == .success, let observer = obs else { return }
        let appEl = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in [kAXWindowMovedNotification, kAXWindowResizedNotification, kAXWindowCreatedNotification, kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification] {
            AXObserverAddNotification(observer, appEl, name as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer
    }

    /// Agrupa notificações e espera o botão do mouse ser solto (não brigar com o usuário durante um arrasto).
    private func schedule(_ element: AXUIElement) {
        guard enabled else { return }
        if !pending.contains(where: { CFEqual($0, element) }) { pending.append(element) }
        pendingTimer?.invalidate()
        pendingTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            if NSEvent.pressedMouseButtons != 0 { return }
            t.invalidate(); self.pendingTimer = nil
            let items = self.pending; self.pending.removeAll()
            for el in items { self.herd(el, expandFullHeight: false) }
        }
    }

    // MARK: Geometria
    private struct Limits { let barTopAX: CGFloat; let topLimitAX: CGFloat }

    /// Limites em coordenadas AX (origem no topo-esquerdo da tela principal) para a tela que contém o retângulo.
    private func limits(for frame: CGRect) -> Limits? {
        guard let primary = NSScreen.screens.first else { return nil }
        let h0 = primary.frame.height
        let s = SettingsStore.shared.s
        guard !s.autoHide else { return nil }   // barra oculta: as janelas podem usar a tela toda
        let centerCocoa = NSPoint(x: frame.midX, y: h0 - frame.midY)
        let screens = s.allScreens ? NSScreen.screens : Array(NSScreen.screens.prefix(1))
        guard let screen = screens.first(where: { $0.frame.contains(centerCocoa) })
            ?? screens.first(where: { $0.frame.intersects(NSRect(x: frame.minX, y: h0 - frame.maxY, width: frame.width, height: frame.height)) }) else { return nil }
        let barTopAX = h0 - (screen.frame.minY + s.barSize.height) + overlap
        let topLimitAX = h0 - screen.visibleFrame.maxY
        return Limits(barTopAX: barTopAX, topLimitAX: topLimitAX)
    }

    // MARK: Ação
    func herdAll(expandFullHeight: Bool) {
        guard enabled || expandFullHeight else { return }
        for app in regularApps() {
            let appEl = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(appEl, 0.25)
            var raw: AnyObject?
            guard AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &raw) == .success,
                  let windows = raw as? [AXUIElement] else { continue }
            for w in windows { herd(w, expandFullHeight: expandFullHeight) }
        }
    }

    private func herd(_ el: AXUIElement, expandFullHeight: Bool) {
        let subrole = WindowService.stringAttr(el, kAXSubroleAttribute) ?? ""
        guard subrole == kAXStandardWindowSubrole || subrole == kAXDialogSubrole else { return }
        guard !WindowService.boolAttr(el, kAXMinimizedAttribute), !WindowService.boolAttr(el, "AXFullScreen") else { return }
        let frame = WindowService.frameAttr(el)
        guard frame.width > 0, frame.height > 0, let lim = limits(for: frame) else { return }

        var target = frame
        if frame.maxY > lim.barTopAX + 0.5 {
            // Invadiu a barra: encurta; se ficar baixa demais, sobe a janela.
            let h = lim.barTopAX - frame.minY
            if h >= minHeight {
                target.size.height = h
            } else {
                target.origin.y = max(lim.topLimitAX, lim.barTopAX - frame.height)
                target.size.height = max(minHeight, lim.barTopAX - target.origin.y)
            }
        } else if expandFullHeight,
                  frame.minY <= lim.topLimitAX + 2,                       // encostada na barra de menus (altura cheia)
                  frame.maxY < lim.barTopAX - 1, frame.maxY >= lim.barTopAX - expandRange {
            target.size.height = lim.barTopAX - frame.minY           // estica até a barra
        }
        guard target != frame else { return }
        apply(target, to: el, original: frame)
    }

    private func apply(_ target: CGRect, to el: AXUIElement, original: CGRect) {
        if target.origin != original.origin {
            var p = target.origin
            if let v = AXValueCreate(.cgPoint, &p) { AXUIElementSetAttributeValue(el, kAXPositionAttribute as CFString, v) }
        }
        if target.size != original.size {
            var s = target.size
            if let v = AXValueCreate(.cgSize, &s) { AXUIElementSetAttributeValue(el, kAXSizeAttribute as CFString, v) }
        }
    }
}
