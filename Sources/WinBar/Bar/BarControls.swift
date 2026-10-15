import AppKit

/// Botão genérico da barra com overlay de hover/pressed e callback.
class BarControl: NSView {
    var onClick: ((NSEvent) -> Void)?
    var onRightClick: ((NSEvent) -> Void)?
    var isOpen = false { didSet { needsDisplay = true } }
    var hoverColor: NSColor = W10.Overlay.hover
    private(set) var hovered = false { didSet { needsDisplay = true } }
    private var pressed = false { didSet { needsDisplay = true } }
    private var tracking: NSTrackingArea?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        setAccessibilityRole(.button)
    }
    required init?(coder: NSCoder) { return nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = tracking { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .cursorUpdate, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(t); tracking = t
    }
    override func cursorUpdate(with event: NSEvent) { NSCursor.arrow.set() }
    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false; pressed = false }
    override func mouseDown(with event: NSEvent) { pressed = true }
    override func mouseUp(with event: NSEvent) {
        pressed = false
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick?(event) }
    }
    override func rightMouseDown(with event: NSEvent) { onRightClick?(event) }

    func drawBackground() {
        if pressed { W10.Overlay.pressed.setFill(); bounds.fill() }
        else if isOpen { W10.Overlay.active.setFill(); bounds.fill() }
        else if hovered { hoverColor.setFill(); bounds.fill() }
    }
}

/// Botão Start: glifo próprio — grade 3×3 de pontos (ícone genérico de "apps", não é logotipo de ninguém).
final class StartButton: BarControl {
    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityLabel("Iniciar")
        toolTip = "Iniciar"
    }
    required init?(coder: NSCoder) { return nil }

    override func draw(_ dirtyRect: NSRect) {
        drawBackground()
        let dot: CGFloat = 4, gap: CGFloat = 3
        let total = dot * 3 + gap * 2
        let x0 = (bounds.width - total) / 2, y0 = (bounds.height - total) / 2
        (isOpen ? W10.Color.accentLight : W10.Color.text).setFill()
        for i in 0..<3 { for j in 0..<3 {
            NSBezierPath(roundedRect: NSRect(x: x0 + CGFloat(i) * (dot + gap), y: y0 + CGFloat(j) * (dot + gap), width: dot, height: dot),
                         xRadius: 1, yRadius: 1).fill()
        } }
    }
}

/// Relógio em duas linhas (hora / data) no formato do sistema.
final class ClockView: BarControl {
    private var timer: Timer?
    private let timeFormatter: DateFormatter = { let f = DateFormatter(); f.dateStyle = .none; f.timeStyle = .short; return f }()
    private let dateFormatter: DateFormatter = { let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .none; return f }()
    private let longFormatter: DateFormatter = { let f = DateFormatter(); f.dateStyle = .full; f.timeStyle = .short; return f }()

    override init(frame: NSRect) {
        super.init(frame: frame)
        scheduleTick()
        tick()
    }
    required init?(coder: NSCoder) { return nil }

    private func scheduleTick() {
        // Alinha ao próximo minuto para não acordar a cada segundo.
        let now = Date()
        let next = ceil(now.timeIntervalSince1970 / 60) * 60 + 0.05
        timer?.invalidate()
        timer = Timer(fireAt: Date(timeIntervalSince1970: next), interval: 60, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .common)
    }

    @objc private func tick() {
        let now = Date()
        toolTip = longFormatter.string(from: now)
        setAccessibilityLabel("Relógio, \(longFormatter.string(from: now))")
        needsDisplay = true
    }

    var preferredWidth: CGFloat {
        let now = Date()
        let w = max((timeFormatter.string(from: now) as NSString).size(withAttributes: [.font: W10.Font.sm]).width,
                    (dateFormatter.string(from: now) as NSString).size(withAttributes: [.font: W10.Font.sm]).width)
        return max(W10.Size.clockMinWidth, ceil(w) + W10.Space.md * 2)
    }

    override func draw(_ dirtyRect: NSRect) {
        drawBackground()
        let now = Date()
        let para = NSMutableParagraphStyle(); para.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [.font: W10.Font.sm, .foregroundColor: W10.Color.text, .paragraphStyle: para]
        let lineH: CGFloat = 16
        let mid = bounds.midY
        (timeFormatter.string(from: now) as NSString).draw(in: NSRect(x: 0, y: mid, width: bounds.width, height: lineH), withAttributes: attrs)
        (dateFormatter.string(from: now) as NSString).draw(in: NSRect(x: 0, y: mid - lineH, width: bounds.width, height: lineH), withAttributes: attrs)
    }
}

/// Tira "Mostrar área de trabalho" no canto direito.
final class ShowDesktopSliver: BarControl {
    override init(frame: NSRect) {
        super.init(frame: frame)
        hoverColor = W10.Overlay.showDesktopHover
        setAccessibilityLabel("Mostrar área de trabalho")
        toolTip = "Mostrar área de trabalho"
    }
    required init?(coder: NSCoder) { return nil }

    override func draw(_ dirtyRect: NSRect) {
        drawBackground()
        W10.Color.border.setFill()
        NSRect(x: 0, y: W10.Space.sm, width: 1, height: bounds.height - W10.Space.sm * 2).fill()
    }
}

/// Alterna "mostrar área de trabalho": oculta todos os apps (imperativo) e lembra o que restaurar.
final class DesktopToggle {
    static let shared = DesktopToggle()
    private var hiddenPIDs: [pid_t] = []
    private var minimized: [WindowInfo] = []     // janelas de apps que ignoraram o hide()
    private var previousActive: pid_t?
    private var ignoreActivationsUntil = Date.distantPast
    private(set) var showingDesktop = false

    func toggle() {
        ignoreActivationsUntil = Date().addingTimeInterval(1.5)   // ocultar/restaurar dispara ativações do sistema
        if showingDesktop { restore() } else { showDesktop() }
    }

    private func showDesktop() {
        let me = ProcessInfo.processInfo.processIdentifier
        previousActive = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isHidden && $0.processIdentifier != me }
        hiddenPIDs = apps.map { $0.processIdentifier }
        minimized.removeAll()
        // O WinBar vira o app ativo ANTES de ocultar os outros: senão, ao ocultar o último visível, o macOS
        // ativa (e desoculta) outro app sozinho, e uma janela volta a aparecer.
        DesktopToggle.activateSelf()
        for app in apps { _ = app.hide() }
        showingDesktop = true
        // Teimosos: quem continuar/voltar a ficar visível depois de 0,4 s é reocultado; se ainda resistir,
        // tem as janelas minimizadas via Acessibilidade.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self = self, self.showingDesktop else { return }
            DesktopToggle.activateSelf()
            for app in apps where !app.isHidden && !app.isTerminated {
                if app.hide() { continue }
                for w in WindowService.windows(for: app) where !w.isMinimized {
                    AXController.minimize(w); self.minimized.append(w)
                }
            }
        }
    }

    private func restore() {
        for w in minimized { AXUIElementSetAttributeValue(w.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse) }
        minimized.removeAll()
        for pid in hiddenPIDs { _ = NSRunningApplication(processIdentifier: pid)?.unhide() }
        hiddenPIDs.removeAll()
        showingDesktop = false
        if let pid = previousActive, let app = NSRunningApplication(processIdentifier: pid) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { AXController.bringToFront(app, allWindows: false) }
        }
        previousActive = nil
    }

    private static func activateSelf() {
        if #available(macOS 14.0, *) { NSApp.activate() } else { NSApp.activate(ignoringOtherApps: true) }
    }

    /// Ativação feita pelo usuário cancela o estado "mostrando área de trabalho" (o próximo clique oculta de novo).
    func noteAppActivated() {
        guard showingDesktop, Date() > ignoreActivationsUntil else { return }
        showingDesktop = false; hiddenPIDs.removeAll(); minimized.removeAll(); previousActive = nil
    }
}
