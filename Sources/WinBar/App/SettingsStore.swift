import Foundation
import Combine

enum CombineMode: String, Codable, CaseIterable, Identifiable {
    case always, whenFull, never
    var id: String { rawValue }
    var label: String {
        switch self {
        case .always: return "Só ícones (combinar janelas do mesmo app)"
        case .whenFull: return "Combinar só quando a barra encher"
        case .never: return "Clássico: um botão largo por janela, com título"
        }
    }
}

/// Tamanho da barra; todas as medidas derivam daqui (altura, ícone, largura dos botões).
enum BarSize: String, Codable, CaseIterable, Identifiable {
    case small, normal, large, huge
    var id: String { rawValue }
    var label: String {
        switch self {
        case .small: return "Pequena (30 pt)"
        case .normal: return "Normal (40 pt)"
        case .large: return "Grande (48 pt)"
        case .huge: return "Enorme (56 pt)"
        }
    }
    var height: CGFloat     { switch self { case .small: return 30; case .normal: return 40; case .large: return 48; case .huge: return 56 } }
    var icon: CGFloat       { switch self { case .small: return 16; case .normal: return 24; case .large: return 28; case .huge: return 32 } }
    var buttonWidth: CGFloat { switch self { case .small: return 44; case .normal: return 60; case .large: return 68; case .huge: return 76 } }
    var startWidth: CGFloat { switch self { case .small: return 40; case .normal: return 48; case .large: return 56; case .huge: return 64 } }
    var labelMin: CGFloat   { switch self { case .small: return 80; case .normal: return 90; case .large: return 100; case .huge: return 110 } }
    var labelMax: CGFloat   { switch self { case .small: return 150; case .normal: return 160; case .large: return 180; case .huge: return 200 } }
    var fontSize: CGFloat   { switch self { case .small: return 11; case .normal: return 12; case .large: return 13; case .huge: return 14 } }
}

struct HotKeySpec: Codable, Equatable {
    var keyCode: UInt32
    var control: Bool
    var option: Bool
    var shift: Bool
    var command: Bool
    static let ctrlEsc = HotKeySpec(keyCode: 53, control: true, option: false, shift: false, command: false)
}

struct Settings: Codable, Equatable {
    var autoHide = false
    var useAccentColor = false
    var transparency = true
    var combineButtons: CombineMode = .always
    var showLabels = false
    var barSize: BarSize = .normal
    var keepWindowsAboveBar = true
    /// Clique no botão da janela ativa minimiza (Windows); qualquer outra vem para a frente.
    var activeClickMinimizes = true
    /// Semântica do Windows: app sem janela não fica rodando. Fechar a última janela pela barra encerra o app
    /// na hora; a última janela fechada por qualquer outro meio encerra o app após uma carência (AppTracker).
    var quitOnLastWindowClose = true
    /// Exceções do item acima (bundle IDs que podem ficar abertos sem janela, ex.: player de música).
    var keepRunningBundleIDs: [String] = []
    var excludeNoWindowApps = true
    var showClock = true
    var showDesktopButton = true
    var showSpaces = true
    var previewDelayMs = 400
    var startHotkey: HotKeySpec? = .ctrlEsc
    var launchAtLogin = true      // LaunchAgent do usuário; ver LoginItem
    var allScreens = true
    var excludedBundleIDs: [String] = []
    var manualOrder: [String] = []   // bundleIDs na ordem escolhida por arrasto
    var onboardingDone = false

    init() {}

    // Decodificação tolerante: chave ausente (ajuste novo ou removido) assume o padrão.
    private enum K: String, CodingKey {
        case autoHide, useAccentColor, transparency, combineButtons, showLabels, barSize, keepWindowsAboveBar, activeClickMinimizes,
             quitOnLastWindowClose, keepRunningBundleIDs, excludeNoWindowApps, showClock, showDesktopButton, showSpaces,
             previewDelayMs, startHotkey, launchAtLogin, allScreens, excludedBundleIDs, manualOrder, onboardingDone
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        let d = Settings()
        autoHide = try c.decodeIfPresent(Bool.self, forKey: .autoHide) ?? d.autoHide
        useAccentColor = try c.decodeIfPresent(Bool.self, forKey: .useAccentColor) ?? d.useAccentColor
        transparency = try c.decodeIfPresent(Bool.self, forKey: .transparency) ?? d.transparency
        combineButtons = try c.decodeIfPresent(CombineMode.self, forKey: .combineButtons) ?? d.combineButtons
        showLabels = try c.decodeIfPresent(Bool.self, forKey: .showLabels) ?? d.showLabels
        barSize = try c.decodeIfPresent(BarSize.self, forKey: .barSize) ?? d.barSize
        keepWindowsAboveBar = try c.decodeIfPresent(Bool.self, forKey: .keepWindowsAboveBar) ?? d.keepWindowsAboveBar
        activeClickMinimizes = try c.decodeIfPresent(Bool.self, forKey: .activeClickMinimizes) ?? d.activeClickMinimizes
        quitOnLastWindowClose = try c.decodeIfPresent(Bool.self, forKey: .quitOnLastWindowClose) ?? d.quitOnLastWindowClose
        keepRunningBundleIDs = try c.decodeIfPresent([String].self, forKey: .keepRunningBundleIDs) ?? d.keepRunningBundleIDs
        excludeNoWindowApps = try c.decodeIfPresent(Bool.self, forKey: .excludeNoWindowApps) ?? d.excludeNoWindowApps
        showClock = try c.decodeIfPresent(Bool.self, forKey: .showClock) ?? d.showClock
        showDesktopButton = try c.decodeIfPresent(Bool.self, forKey: .showDesktopButton) ?? d.showDesktopButton
        showSpaces = try c.decodeIfPresent(Bool.self, forKey: .showSpaces) ?? d.showSpaces
        previewDelayMs = try c.decodeIfPresent(Int.self, forKey: .previewDelayMs) ?? d.previewDelayMs
        startHotkey = try c.decodeIfPresent(HotKeySpec.self, forKey: .startHotkey) ?? d.startHotkey
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? d.launchAtLogin
        allScreens = try c.decodeIfPresent(Bool.self, forKey: .allScreens) ?? d.allScreens
        excludedBundleIDs = try c.decodeIfPresent([String].self, forKey: .excludedBundleIDs) ?? d.excludedBundleIDs
        manualOrder = try c.decodeIfPresent([String].self, forKey: .manualOrder) ?? d.manualOrder
        onboardingDone = try c.decodeIfPresent(Bool.self, forKey: .onboardingDone) ?? d.onboardingDone
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        try c.encode(autoHide, forKey: .autoHide)
        try c.encode(useAccentColor, forKey: .useAccentColor)
        try c.encode(transparency, forKey: .transparency)
        try c.encode(combineButtons, forKey: .combineButtons)
        try c.encode(showLabels, forKey: .showLabels)
        try c.encode(barSize, forKey: .barSize)
        try c.encode(keepWindowsAboveBar, forKey: .keepWindowsAboveBar)
        try c.encode(activeClickMinimizes, forKey: .activeClickMinimizes)
        try c.encode(quitOnLastWindowClose, forKey: .quitOnLastWindowClose)
        try c.encode(keepRunningBundleIDs, forKey: .keepRunningBundleIDs)
        try c.encode(excludeNoWindowApps, forKey: .excludeNoWindowApps)
        try c.encode(showClock, forKey: .showClock)
        try c.encode(showDesktopButton, forKey: .showDesktopButton)
        try c.encode(showSpaces, forKey: .showSpaces)
        try c.encode(previewDelayMs, forKey: .previewDelayMs)
        try c.encodeIfPresent(startHotkey, forKey: .startHotkey)
        try c.encode(launchAtLogin, forKey: .launchAtLogin)
        try c.encode(allScreens, forKey: .allScreens)
        try c.encode(excludedBundleIDs, forKey: .excludedBundleIDs)
        try c.encode(manualOrder, forKey: .manualOrder)
        try c.encode(onboardingDone, forKey: .onboardingDone)
    }

    /// Apps que o WinBar pode encerrar quando ficam sem janela.
    func mayQuit(bundleID: String?) -> Bool {
        guard quitOnLastWindowClose, bundleID != "com.apple.finder" else { return false }
        return !(bundleID.map { keepRunningBundleIDs.contains($0) } ?? false)
    }
}

/// Única fonte de verdade das preferências. Persistido em UserDefaults como JSON.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    static let changed = Notification.Name("WinBar.settings.changed")
    private static let key = "settings.v1"

    @Published var settings: Settings {
        didSet {
            guard settings != oldValue else { return }
            save()
            NotificationCenter.default.post(name: SettingsStore.changed, object: nil)
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: SettingsStore.key),
           let decoded = try? JSONDecoder().decode(Settings.self, from: data) {
            settings = decoded
        } else {
            settings = Settings()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: SettingsStore.key)
        }
    }

    var s: Settings { settings }
}
