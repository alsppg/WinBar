import AppKit
import ApplicationServices

/// Enumera janelas de outros apps via Accessibility (fonte primária) e CGWindowList (IDs para preview).
enum WindowService {
    // _AXUIElementGetWindow é privado mas amplamente usado; carregado por dlsym com fallback por geometria.
    private typealias GetWindowFn = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    private static let getWindowFn: GetWindowFn? = {
        guard let handle = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_NOW),
              let sym = dlsym(handle, "_AXUIElementGetWindow") else { return nil }
        return unsafeBitCast(sym, to: GetWindowFn.self)
    }()

    static func windows(for app: NSRunningApplication) -> [WindowInfo] {
        let pid = app.processIdentifier
        let appEl = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appEl, 0.3)

        var raw: AnyObject?
        guard AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &raw) == .success,
              let axWindows = raw as? [AXUIElement], !axWindows.isEmpty else { return [] }

        var focusedRaw: AnyObject?
        AXUIElementCopyAttributeValue(appEl, kAXFocusedWindowAttribute as CFString, &focusedRaw)
        let focused = focusedRaw.map { $0 as! AXUIElement }

        let cgList = cgWindows(pid: pid)
        var out: [WindowInfo] = []
        for (i, w) in axWindows.enumerated() {
            let subrole = stringAttr(w, kAXSubroleAttribute) ?? ""
            guard subrole == kAXStandardWindowSubrole || subrole == kAXDialogSubrole else { continue }
            let title = stringAttr(w, kAXTitleAttribute) ?? ""
            let minimized = boolAttr(w, kAXMinimizedAttribute)
            let fullScreen = boolAttr(w, "AXFullScreen")
            let frame = frameAttr(w)
            // Ignora janelas minúsculas (paletas, auxiliares) a não ser que minimizadas.
            if !minimized && (frame.width < 60 || frame.height < 40) { continue }

            var cgID: CGWindowID? = nil
            if let fn = getWindowFn {
                var id: CGWindowID = 0
                if fn(w, &id) == .success, id != 0 { cgID = id }
            }
            if cgID == nil {
                cgID = cgList.first { cg in
                    abs(cg.bounds.origin.x - frame.origin.x) < 2 && abs(cg.bounds.origin.y - frame.origin.y) < 2 &&
                    abs(cg.bounds.width - frame.width) < 2 && abs(cg.bounds.height - frame.height) < 2
                }?.id
            }
            let isFocused = focused.map { CFEqual($0, w) } ?? false
            out.append(WindowInfo(id: "\(pid):\(i)", cgID: cgID, pid: pid,
                                  title: title.isEmpty ? app.localizedName ?? "" : title,
                                  frame: frame, isMinimized: minimized, isFullScreen: fullScreen,
                                  isFocused: isFocused, element: w))
        }
        return out
    }

    /// Verdadeiro se a janela focada do app está em tela cheia.
    static func focusedWindowIsFullScreen(pid: pid_t) -> Bool {
        let appEl = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appEl, 0.2)
        var raw: AnyObject?
        guard AXUIElementCopyAttributeValue(appEl, kAXFocusedWindowAttribute as CFString, &raw) == .success,
              let w = raw else { return false }
        return boolAttr(w as! AXUIElement, "AXFullScreen")
    }

    // MARK: CGWindowList
    private struct CGWin { let id: CGWindowID; let bounds: CGRect; let onScreen: Bool }

    private static func cgWindows(pid: pid_t) -> [CGWin] {
        guard let list = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { d in
            guard (d[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (d[kCGWindowLayer as String] as? Int) == 0,
                  let num = d[kCGWindowNumber as String] as? CGWindowID,
                  let b = d[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: b as CFDictionary) else { return nil }
            return CGWin(id: num, bounds: rect, onScreen: (d[kCGWindowIsOnscreen as String] as? Bool) ?? false)
        }
    }

    // MARK: AX helpers
    static func stringAttr(_ el: AXUIElement, _ attr: String) -> String? {
        var raw: AnyObject?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &raw) == .success else { return nil }
        return raw as? String
    }

    static func boolAttr(_ el: AXUIElement, _ attr: String) -> Bool {
        var raw: AnyObject?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &raw) == .success else { return false }
        return (raw as? Bool) ?? false
    }

    static func frameAttr(_ el: AXUIElement) -> CGRect {
        var posRaw: AnyObject?, sizeRaw: AnyObject?
        var p = CGPoint.zero, s = CGSize.zero
        if AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &posRaw) == .success, let v = posRaw {
            AXValueGetValue(v as! AXValue, .cgPoint, &p)
        }
        if AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &sizeRaw) == .success, let v = sizeRaw {
            AXValueGetValue(v as! AXValue, .cgSize, &s)
        }
        return CGRect(origin: p, size: s)
    }
}
