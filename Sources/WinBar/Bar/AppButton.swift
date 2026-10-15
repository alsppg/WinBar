import AppKit

/// Modelo de um botão da barra: um app (combinado) ou uma janela específica (modo "nunca combinar").
struct ButtonModel {
    let entry: AppEntry
    let window: WindowInfo?     // nil = botão do app
    let showLabel: Bool

    var key: String { window.map { "\(entry.id)|\($0.id)" } ?? entry.id }
    var label: String { window?.title ?? entry.name }
    var isActive: Bool {
        if let w = window { return entry.isActive && w.isFocused }
        return entry.isActive
    }
    var isRunning: Bool { entry.isRunning }
    var windowCount: Int { window == nil ? entry.windows.count : 1 }
}

protocol AppButtonDelegate: AnyObject {
    func appButton(_ b: AppButton, clickedWith event: NSEvent)
    func appButton(_ b: AppButton, rightClickedWith event: NSEvent)
    func appButton(_ b: AppButton, middleClickedWith event: NSEvent)
    func appButtonHoverBegan(_ b: AppButton)
    func appButtonHoverEnded(_ b: AppButton)
    func appButtonDragBegan(_ b: AppButton)
    func appButton(_ b: AppButton, dragMovedTo xInSuperview: CGFloat)
    func appButtonDragEnded(_ b: AppButton)
}

final class AppButton: NSView {
    var model: ButtonModel { didSet { updateAccessibility(); needsDisplay = true } }
    weak var delegate: AppButtonDelegate?
    var useAccent = false { didSet { needsDisplay = true } }
    var size: BarSize = .normal { didSet { needsDisplay = true } }
    var flyoutOpen = false { didSet { needsDisplay = true } }

    private(set) var hovered = false { didSet { needsDisplay = true } }
    private var pressed = false { didSet { needsDisplay = true } }
    private(set) var dragging = false { didSet { needsDisplay = true } }
    private var mouseDownPoint: NSPoint = .zero
    private var tracking: NSTrackingArea?

    init(model: ButtonModel) {
        self.model = model
        super.init(frame: .zero)
        wantsLayer = true
        updateAccessibility()
    }
    required init?(coder: NSCoder) { return nil }

    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func updateAccessibility() {
        setAccessibilityRole(.button)
        let count = model.windowCount
        let state = model.isActive ? "ativo" : (model.isRunning ? "em execução" : "fechado")
        setAccessibilityLabel("\(model.label), \(count) janela\(count == 1 ? "" : "s"), \(state)")
        toolTip = model.label
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = tracking { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .cursorUpdate, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(t)
        tracking = t
    }
    override func cursorUpdate(with event: NSEvent) { NSCursor.arrow.set() }

    override func mouseEntered(with event: NSEvent) { hovered = true; delegate?.appButtonHoverBegan(self) }
    override func mouseExited(with event: NSEvent) { hovered = false; pressed = false; delegate?.appButtonHoverEnded(self) }

    override func mouseDown(with event: NSEvent) {
        pressed = true
        mouseDownPoint = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        let dx = abs(event.locationInWindow.x - mouseDownPoint.x)
        if !dragging && dx > 6 {
            dragging = true
            pressed = false
            delegate?.appButtonDragBegan(self)
        }
        if dragging, let sv = superview {
            delegate?.appButton(self, dragMovedTo: sv.convert(event.locationInWindow, from: nil).x)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if dragging {
            dragging = false
            delegate?.appButtonDragEnded(self)
            return
        }
        let inside = bounds.contains(convert(event.locationInWindow, from: nil))
        pressed = false
        if inside { delegate?.appButton(self, clickedWith: event) }
    }

    override func rightMouseDown(with event: NSEvent) { delegate?.appButton(self, rightClickedWith: event) }
    override func otherMouseUp(with event: NSEvent) {
        if event.buttonNumber == 2 { delegate?.appButton(self, middleClickedWith: event) }
    }

    // MARK: Desenho
    override func draw(_ dirtyRect: NSRect) {
        let b = bounds
        // Fundo (hover / ativo / pressionado)
        var fill: NSColor? = nil
        if pressed { fill = W10.Overlay.pressed }
        else if model.isActive && (hovered || flyoutOpen) { fill = W10.Overlay.activeHover }
        else if model.isActive { fill = W10.Overlay.active }
        else if hovered || flyoutOpen { fill = W10.Overlay.hover }
        if let f = fill { f.setFill(); b.fill() }

        // Ícone
        let iconSize = size.icon
        let icon = AppTracker.shared.icon(for: model.entry)
        let alpha: CGFloat = (model.entry.isLaunching || dragging) ? 0.55 : (model.entry.isHidden && model.isRunning ? 0.7 : 1.0)
        let iconX: CGFloat = model.showLabel ? W10.Space.md : (b.width - iconSize) / 2
        let iconRect = NSRect(x: iconX, y: (b.height - iconSize) / 2 + 1, width: iconSize, height: iconSize)
        icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: alpha, respectFlipped: true, hints: [.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)])

        // Rótulo
        if model.showLabel {
            let para = NSMutableParagraphStyle()
            para.lineBreakMode = .byTruncatingTail
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size.fontSize), .foregroundColor: W10.Color.text, .paragraphStyle: para]
            let textX = iconRect.maxX + W10.Size.labelGap
            let lineH = size.fontSize + 5
            let textRect = NSRect(x: textX, y: (b.height - lineH) / 2 + 1, width: b.width - textX - W10.Space.md, height: lineH)
            (model.label as NSString).draw(in: textRect, withAttributes: attrs)
        }

        // Indicador "em execução" / ativo + segmentos de pilha
        if model.isRunning {
            let color = W10.indicatorColor(useAccent: useAccent)
            let h = W10.Size.indicatorHeight
            let inset: CGFloat = model.isActive ? 0 : W10.Size.indicatorInsetRunning
            let stackCount = model.window == nil ? min(max(model.windowCount - 1, 0), 2) : 0
            let stackWidth = CGFloat(stackCount) * (W10.Size.stackSegmentWidth + W10.Size.stackSegmentGap)
            color.withAlphaComponent(model.isActive ? 1.0 : 0.7).setFill()
            NSRect(x: inset, y: 0, width: b.width - inset * 2 - stackWidth, height: h).fill()
            var x = b.width - inset - stackWidth + W10.Size.stackSegmentGap
            for _ in 0..<stackCount {
                NSRect(x: x, y: 0, width: W10.Size.stackSegmentWidth, height: h).fill()
                x += W10.Size.stackSegmentWidth + W10.Size.stackSegmentGap
            }
            if stackCount > 0 {
                W10.Overlay.stackEdge.setFill()
                NSRect(x: b.width - 1, y: 0, width: 1, height: b.height).fill()
            }
        }
    }
}
