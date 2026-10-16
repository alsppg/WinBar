import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var bars: [BarController] = []
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Instância única: o LaunchAgent, um "open" e um Item de Início antigo podem coincidir no login.
        // A recém-chegada sai com código 0 (o launchd não a reabre) e a que já estava fica.
        let myPID = ProcessInfo.processInfo.processIdentifier
        if let bid = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bid).contains(where: { $0.processIdentifier != myPID }) {
            Log.info("outra instância do WinBar já está aberta; esta sai")
            exit(0)
        }
        Log.info("WinBar iniciou" + (LoginItem.launchedByLaunchd ? " (pelo launchd)" : ""))
        _ = SettingsStore.shared
        _ = PinStore.shared
        LoginItem.ensure(enabled: SettingsStore.shared.s.launchAtLogin)
        LoginItem.removeLegacyRegistration()
        _ = AppTracker.shared
        StartIndex.shared.refreshIfStale()

        installStatusItem()
        rebuildBars()
        registerHotKeys()

        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: SettingsStore.changed, object: nil)

        if !PermissionGate.accessibility || !SettingsStore.shared.s.onboardingDone {
            showOnboarding()
        }
        lastBarSize = SettingsStore.shared.s.barSize
        updateHerder()
    }

    private var lastBarSize: BarSize = .normal
    private func updateHerder() {
        let s = SettingsStore.shared.s
        WindowHerder.shared.setEnabled(s.keepWindowsAboveBar && PermissionGate.accessibility)
        if s.barSize != lastBarSize {
            lastBarSize = s.barSize
            if s.keepWindowsAboveBar { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { WindowHerder.shared.herdAll(expandFullHeight: true) } }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyCenter.shared.unregisterAll()
        if DesktopToggle.shared.showingDesktop { DesktopToggle.shared.toggle() }
        Log.info("WinBar encerrou")
    }

    // MARK: Barras
    @objc private func screensChanged() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.rebuildBars() }
    }

    @objc private func settingsChanged() {
        let want = SettingsStore.shared.s.allScreens ? NSScreen.screens.count : 1
        if want != bars.count { rebuildBars() }
        updateHerder()
    }

    private func rebuildBars() {
        bars.forEach { $0.tearDown() }
        let screens = SettingsStore.shared.s.allScreens ? NSScreen.screens : Array(NSScreen.screens.prefix(1))
        bars = screens.map { BarController(screen: $0) }
    }

    private var mainBar: BarController? {
        let mouse = NSEvent.mouseLocation
        return bars.first { $0.screen.frame.contains(mouse) } ?? bars.first
    }

    // MARK: Atalhos globais
    private func registerHotKeys() {
        HotKeyCenter.shared.unregisterAll()
        if let hk = SettingsStore.shared.s.startHotkey {
            HotKeyCenter.shared.register(hk) { [weak self] in self?.mainBar?.toggleStart() }
        }
        // Control+Option+D → mostrar área de trabalho (como Win+D)
        HotKeyCenter.shared.register(HotKeySpec(keyCode: 2, control: true, option: true, shift: false, command: false)) {
            DesktopToggle.shared.toggle()
        }
        // Control+Option+1…9 → botão N (keycodes das teclas 1..9 no layout ANSI)
        let keyCodes: [UInt32] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
        for (i, kc) in keyCodes.enumerated() {
            HotKeyCenter.shared.register(HotKeySpec(keyCode: kc, control: true, option: true, shift: false, command: false)) { [weak self] in
                self?.mainBar?.activateButton(index: i)
            }
        }
    }

    // MARK: Item na barra de menus (saída de emergência se a barra estiver oculta)
    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.bottomthird.inset.filled", accessibilityDescription: "WinBar")
        let menu = NSMenu()
        menu.addItem(withTitle: "Ajustes…", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Relançar", action: #selector(relaunch), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Sair do WinBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func relaunch() { PermissionGate.relaunch() }

    // MARK: Janelas auxiliares
    @objc func showSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = "Ajustes do WinBar"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func showOnboarding() {
        if onboardingWindow == nil {
            let host = NSHostingController(rootView: OnboardingView { [weak self] in
                SettingsStore.shared.settings.onboardingDone = true
                self?.onboardingWindow?.close()
            })
            let w = NSWindow(contentViewController: host)
            w.title = "WinBar — primeiros passos"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            onboardingWindow = w
        }
        NSApp.activate()
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }
}
