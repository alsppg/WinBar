import AppKit
import ApplicationServices

struct WindowInfo: Identifiable {
    let id: String            // "\(pid):\(index)" — estável durante a sessão enquanto a janela existir
    let cgID: CGWindowID?
    let pid: pid_t
    let title: String
    let frame: CGRect          // coordenadas CG (origem no topo-esquerda da tela principal)
    let isMinimized: Bool
    let isFullScreen: Bool
    let isFocused: Bool
    let element: AXUIElement
}

struct AppEntry: Identifiable {
    let id: String             // bundleID ou "pid:<n>"
    let bundleID: String?
    let name: String
    let url: URL?
    let app: NSRunningApplication?
    let isPinned: Bool
    let windows: [WindowInfo]
    let isActive: Bool
    let isHidden: Bool
    let isLaunching: Bool

    var isRunning: Bool { app != nil && !(app?.isTerminated ?? true) }
    var pid: pid_t? { app?.processIdentifier }
}

struct PinnedItem: Codable, Identifiable, Equatable {
    var id: String             // bundleID
    var path: String
    var name: String?
    var order: Int
}
