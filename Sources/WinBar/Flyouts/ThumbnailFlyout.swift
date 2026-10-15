import AppKit

/// Card de uma janela: cabeçalho (ícone + título + ✕) e miniatura.
final class ThumbnailCard: NSView {
    let info: WindowInfo
    let entry: AppEntry
    var onActivate: (() -> Void)?
    var onClose: (() -> Void)?
    private let imageView = NSImageView()
    private let closeButton = NSButton()
    private var hovered = false { didSet { needsDisplay = true; closeButton.isHidden = !hovered } }
    private var tracking: NSTrackingArea?

    init(window: WindowInfo, entry: AppEntry) {
        self.info = window; self.entry = entry
        super.init(frame: NSRect(x: 0, y: 0, width: W10.Size.thumbWidth, height: W10.Size.thumbHeight + W10.Size.thumbHeader))
        wantsLayer = true
        setAccessibilityRole(.button)
        setAccessibilityLabel(info.title)

        let icon = NSImageView(frame: NSRect(x: W10.Space.md, y: bounds.height - W10.Size.thumbHeader + 8, width: 16, height: 16))
        icon.image = AppTracker.shared.icon(for: entry)
        icon.imageScaling = .scaleProportionallyUpOrDown
        addSubview(icon)

        let title = makeLabel(info.title)
        title.frame = NSRect(x: 30, y: bounds.height - W10.Size.thumbHeader + 7, width: bounds.width - 30 - 32, height: 18)
        addSubview(title)

        closeButton.frame = NSRect(x: bounds.width - 28, y: bounds.height - W10.Size.thumbHeader + 6, width: 20, height: 20)
        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Fechar janela")
        closeButton.contentTintColor = W10.Color.text
        closeButton.target = self; closeButton.action = #selector(closeTapped)
        closeButton.isHidden = true
        addSubview(closeButton)

        imageView.frame = NSRect(x: W10.Space.sm, y: W10.Space.sm, width: bounds.width - W10.Space.sm * 2, height: W10.Size.thumbHeight - W10.Space.sm)
        imageView.imageScaling = .scaleProportionallyDown
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = W10.Color.surfaceRaised.cgColor
        addSubview(imageView)
        setPlaceholder()
    }
    required init?(coder: NSCoder) { return nil }

    private func setPlaceholder() {
        let icon = AppTracker.shared.icon(for: entry).copy() as! NSImage
        icon.size = NSSize(width: 48, height: 48)
        imageView.image = icon
        imageView.imageScaling = .scaleNone
    }

    func setPreview(_ img: CGImage?) {
        guard let img = img else { return }
        imageView.image = NSImage(cgImage: img, size: NSSize(width: img.width / 2, height: img.height / 2))
        imageView.imageScaling = .scaleProportionallyDown
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = tracking { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(t); tracking = t
    }
    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false }
    override func mouseUp(with event: NSEvent) {
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        if event.modifierFlags.contains(.shift) { onClose?() } else { onActivate?() }
    }
    override func otherMouseUp(with event: NSEvent) { if event.buttonNumber == 2 { onClose?() } }
    @objc private func closeTapped() { onClose?() }

    override func draw(_ dirtyRect: NSRect) {
        if hovered { W10.Overlay.hover.setFill(); bounds.fill() }
        if info.isFocused && entry.isActive {
            W10.Color.accentLight.setStroke()
            let p = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)); p.lineWidth = 1; p.stroke()
        }
    }
}

/// Flyout com as janelas de um app (modo combinado) — hover ou clique no botão.
final class ThumbnailFlyout: Flyout {
    let entryID: String
    let windowCount: Int
    var onActivate: ((WindowInfo) -> Void)?
    var onCloseWindow: ((WindowInfo) -> Void)?

    init(entry: AppEntry) {
        entryID = entry.id
        windowCount = entry.windows.count
        let windows = entry.windows
        let listMode = windows.count > 12
        let maxVisible = 6
        let cardW = W10.Size.thumbWidth, cardH = W10.Size.thumbHeight + W10.Size.thumbHeader
        let pad = W10.Size.flyoutPadding, gap = W10.Size.flyoutGap
        let size: NSSize
        if listMode {
            size = NSSize(width: 320, height: min(CGFloat(windows.count), 14) * 28 + pad * 2)
        } else {
            let n = CGFloat(min(windows.count, maxVisible))
            size = NSSize(width: n * cardW + (n - 1) * gap + pad * 2, height: cardH + pad * 2)
        }
        super.init(size: size)

        if listMode {
            let scroll = NSScrollView(frame: content.bounds.insetBy(dx: pad, dy: pad))
            scroll.drawsBackground = false; scroll.hasVerticalScroller = true
            let doc = NSView(frame: NSRect(x: 0, y: 0, width: scroll.bounds.width, height: CGFloat(windows.count) * 28))
            for (i, w) in windows.enumerated() {
                let row = BarControl(frame: NSRect(x: 0, y: doc.bounds.height - CGFloat(i + 1) * 28, width: doc.bounds.width, height: 28))
                let l = makeLabel(w.title); l.frame = row.bounds.insetBy(dx: W10.Space.md, dy: 5); row.addSubview(l)
                row.onClick = { [weak self] _ in self?.onActivate?(w) }
                doc.addSubview(row)
            }
            scroll.documentView = doc
            content.addSubview(scroll)
        } else {
            let scroll = NSScrollView(frame: content.bounds)
            scroll.drawsBackground = false; scroll.hasHorizontalScroller = windows.count > maxVisible; scroll.hasVerticalScroller = false
            let doc = NSView(frame: NSRect(x: 0, y: 0, width: CGFloat(windows.count) * (cardW + gap) - gap + pad * 2, height: size.height))
            for (i, w) in windows.enumerated() {
                let card = ThumbnailCard(window: w, entry: entry)
                card.frame.origin = NSPoint(x: pad + CGFloat(i) * (cardW + gap), y: pad)
                card.onActivate = { [weak self] in self?.onActivate?(w) }
                card.onClose = { [weak self] in self?.onCloseWindow?(w) }
                doc.addSubview(card)
                if let id = w.cgID, !w.isMinimized {
                    PreviewService.shared.capture(id, maxSize: NSSize(width: cardW - 8, height: W10.Size.thumbHeight - 4)) { [weak card] img in
                        card?.setPreview(img)
                    }
                }
            }
            scroll.documentView = doc
            content.addSubview(scroll)
        }
    }
}
