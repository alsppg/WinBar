import AppKit

/// Janela da barra: sem borda, nível do Dock, em todos os Spaces, nunca vira key (não rouba foco).
final class BarWindow: NSPanel {
    init(screen: NSScreen) {
        // init(...screen:) é de conveniência; subclasse precisa chamar o designado. A posição real vem do BarController.
        super.init(contentRect: NSRect(x: screen.frame.minX, y: screen.frame.minY, width: 100, height: 40),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        animationBehavior = .none
        becomesKeyOnlyIfNeeded = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Painel para flyouts: acima da barra, não ativa o app; pode virar key quando precisa de teclado (Start).
final class FlyoutWindow: NSPanel {
    var wantsKey = false

    init(size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { wantsKey }
    override var canBecomeMain: Bool { false }
}
