import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Ações sobre janelas e apps de terceiros.
enum AXController {
    /// Traz o app para a frente. No macOS 14+ a ativação é "cooperativa": primeiro nos ativamos (o clique do
    /// usuário na barra nos dá esse direito) e cedemos a ativação ao app; depois reforçamos com AXFrontmost.
    static func bringToFront(_ app: NSRunningApplication, allWindows: Bool) {
        app.unhide()
        var done = false
        if #available(macOS 14.0, *) {
            NSApp.activate()
            var opts: NSApplication.ActivationOptions = []
            if allWindows { opts.insert(.activateAllWindows) }
            done = app.activate(from: NSRunningApplication.current, options: opts)
        }
        if !done {
            var opts: NSApplication.ActivationOptions = [.activateIgnoringOtherApps]
            if allWindows { opts.insert(.activateAllWindows) }
            done = app.activate(options: opts)
        }
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appEl, 0.3)
        AXUIElementSetAttributeValue(appEl, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        if !done { Log.warn("ativação recusada pelo sistema para um app") }
    }

    @discardableResult
    static func activate(_ w: WindowInfo, app: NSRunningApplication?) -> Bool {
        if w.isMinimized {
            AXUIElementSetAttributeValue(w.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        if let app = app { bringToFront(app, allWindows: false) }
        let ok = raise(w.element)
        // Alguns apps só obedecem ao AXRaise depois de terem sido ativados: repete um instante depois.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { _ = raise(w.element) }
        return ok
    }

    @discardableResult
    private static func raise(_ el: AXUIElement) -> Bool {
        let ok = AXUIElementPerformAction(el, kAXRaiseAction as CFString) == .success
        AXUIElementSetAttributeValue(el, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(el, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        return ok
    }

    /// Ativa o app inteiro (todas as janelas), com a janela focada/mais recente por cima.
    static func activate(app: NSRunningApplication, preferring windows: [WindowInfo] = []) {
        bringToFront(app, allWindows: true)
        let top = windows.first { $0.isFocused && !$0.isMinimized } ?? windows.first { !$0.isMinimized } ?? windows.first
        if let w = top {
            if w.isMinimized { AXUIElementSetAttributeValue(w.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse) }
            raise(w.element)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { _ = raise(w.element) }
        }
    }

    static func minimize(_ w: WindowInfo) {
        AXUIElementSetAttributeValue(w.element, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    }

    static func minimizeAll(_ windows: [WindowInfo]) {
        windows.forEach { minimize($0) }
    }

    @discardableResult
    static func close(_ w: WindowInfo) -> Bool {
        var raw: AnyObject?
        guard AXUIElementCopyAttributeValue(w.element, kAXCloseButtonAttribute as CFString, &raw) == .success,
              let btn = raw else { return false }
        return AXUIElementPerformAction(btn as! AXUIElement, kAXPressAction as CFString) == .success
    }

    /// Envia ⌘N ao app (nova janela) — comportamento do Shift+clique / clique do meio do Win10.
    static func newWindow(app: NSRunningApplication) {
        bringToFront(app, allWindows: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            postKey(keyCode: CGKeyCode(kVK_ANSI_N), flags: .maskCommand, toPid: app.processIdentifier)
        }
    }

    static func postKey(keyCode: CGKeyCode, flags: CGEventFlags, toPid pid: pid_t? = nil) {
        guard let src = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false) else { return }
        down.flags = flags
        up.flags = flags
        if let pid = pid {
            down.postToPid(pid); up.postToPid(pid)
        } else {
            down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap)
        }
    }

    static func openMissionControl() {
        // Ctrl+↑ é o atalho padrão do Mission Control.
        postKey(keyCode: CGKeyCode(kVK_UpArrow), flags: .maskControl)
    }

    static func lockScreen() {
        // Ctrl+⌘+Q bloqueia a tela (padrão do macOS desde 10.13).
        postKey(keyCode: CGKeyCode(kVK_ANSI_Q), flags: [.maskControl, .maskCommand])
    }
}
