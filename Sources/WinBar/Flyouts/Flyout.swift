import AppKit

/// Base dos painéis que "saem" da barra: fundo escuro translúcido, fecha ao clicar fora ou com Esc.
class Flyout: NSObject {
    let window: FlyoutWindow
    let content: NSView
    var onClose: (() -> Void)?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(size: NSSize, wantsKey: Bool = false) {
        window = FlyoutWindow(size: size)
        window.wantsKey = wantsKey
        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.appearance = NSAppearance(named: .darkAqua)
        let tint = NSView(frame: effect.bounds)
        tint.wantsLayer = true
        tint.layer?.backgroundColor = W10.Color.surface.withAlphaComponent(W10.Overlay.flyoutAlpha).cgColor
        tint.autoresizingMask = [.width, .height]
        effect.addSubview(tint)
        content = NSView(frame: effect.bounds)
        content.autoresizingMask = [.width, .height]
        effect.addSubview(content)
        window.contentView = effect
        super.init()
    }

    /// Mostra o painel colado ao topo da barra, centralizado horizontalmente no retângulo de ancoragem (coords de tela).
    func show(anchoredTo anchor: NSRect, onScreen screen: NSScreen, alignLeft: Bool = false) {
        let size = window.frame.size
        var x = alignLeft ? anchor.minX : anchor.midX - size.width / 2
        x = max(screen.frame.minX, min(x, screen.frame.maxX - size.width))
        let y = anchor.maxY
        window.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        window.alphaValue = 0
        window.orderFrontRegardless()
        if window.wantsKey { window.makeKey() }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = W10.Motion.flyout
            window.animator().alphaValue = 1
        }
        installMonitors()
    }

    private func installMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.close()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] ev in
            guard let self = self else { return ev }
            if ev.type == .keyDown && ev.keyCode == 53 { self.close(); return nil }   // Esc
            if ev.type != .keyDown, ev.window !== self.window, !(ev.window is BarWindow) { self.close() }
            return ev
        }
    }

    func close() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        guard window.isVisible else { return }
        window.orderOut(nil)
        onClose?()
    }

    var isVisible: Bool { window.isVisible }
    var frame: NSRect { window.frame }
}

/// Rótulo simples com a tipografia da skin.
func makeLabel(_ text: String, font: NSFont = W10.Font.sm, color: NSColor = W10.Color.text, align: NSTextAlignment = .left) -> NSTextField {
    let l = NSTextField(labelWithString: text)
    l.font = font; l.textColor = color; l.alignment = align
    l.lineBreakMode = .byTruncatingTail
    l.backgroundColor = .clear; l.isBezeled = false; l.isEditable = false
    return l
}
