import AppKit
import Carbon.HIToolbox

/// Lê a lista de Mesas (Spaces) e a atual pelo arquivo de preferências do Dock (fonte pública),
/// e troca de Mesa pelos atalhos do sistema (Ctrl+N se o usuário os ativou; senão Ctrl+←/→ em sequência).
final class SpacesService {
    static let shared = SpacesService()
    static let changed = Notification.Name("WinBar.spaces.changed")

    private(set) var count = 1
    private(set) var current = 1
    private var switching = false

    private init() {
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(spaceChanged),
                                                          name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        refresh()
    }

    @objc private func spaceChanged() {
        // O Dock grava o plist um instante depois da troca.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.refresh() }
    }

    /// Mesas normais (type 0) do monitor principal; Spaces de apps em tela cheia não contam.
    func refresh() {
        // CFPreferences consulta o cfprefsd (sem cache local), que é quem o Dock atualiza.
        guard let cfg = CFPreferencesCopyAppValue("SpacesDisplayConfiguration" as CFString, "com.apple.spaces" as CFString) as? [String: Any],
              let mgmt = cfg["Management Data"] as? [String: Any],
              let monitors = mgmt["Monitors"] as? [[String: Any]] else { return }
        let monitor = monitors.first(where: { ($0["Current Space"] as? [String: Any]) != nil }) ?? monitors.first
        guard let mon = monitor, let spaces = mon["Spaces"] as? [[String: Any]] else { return }
        let normals = spaces.filter { (($0["type"] as? Int) ?? 0) == 0 }
        let currentUUID = (mon["Current Space"] as? [String: Any])?["uuid"] as? String
        let idx = normals.firstIndex { ($0["uuid"] as? String) == currentUUID }
        let newCount = max(normals.count, 1)
        let newCurrent = (idx ?? 0) + 1
        if newCount != count || newCurrent != current {
            count = newCount; current = newCurrent
            NotificationCenter.default.post(name: SpacesService.changed, object: nil)
        }
    }

    /// Verdadeiro se o atalho "Alternar para a Mesa N" (Ctrl+N) está ativado em Ajustes > Teclado > Atalhos.
    private func directShortcutEnabled(_ n: Int) -> Bool {
        guard n >= 1 && n <= 10,
              let hot = CFPreferencesCopyAppValue("AppleSymbolicHotKeys" as CFString, "com.apple.symbolichotkeys" as CFString) as? [String: Any],
              let entry = hot["\(117 + n)"] as? [String: Any] else { return false }
        return (entry["enabled"] as? Bool) ?? ((entry["enabled"] as? Int) == 1)
    }

    func switchTo(_ n: Int) {
        guard n >= 1, n <= count, n != current, !switching else { return }
        let digits: [Int: Int] = [1: kVK_ANSI_1, 2: kVK_ANSI_2, 3: kVK_ANSI_3, 4: kVK_ANSI_4, 5: kVK_ANSI_5,
                                  6: kVK_ANSI_6, 7: kVK_ANSI_7, 8: kVK_ANSI_8, 9: kVK_ANSI_9, 10: kVK_ANSI_0]
        if directShortcutEnabled(n), let kc = digits[n] {
            AXController.postKey(keyCode: CGKeyCode(kc), flags: .maskControl)
            return
        }
        // Sem atalho direto: anda uma Mesa por vez com Ctrl+←/→.
        let delta = n - current
        let key = CGKeyCode(delta > 0 ? kVK_RightArrow : kVK_LeftArrow)
        switching = true
        var remaining = abs(delta)
        func step() {
            guard remaining > 0 else { switching = false; return }
            remaining -= 1
            AXController.postKey(keyCode: key, flags: .maskControl)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { step() }
        }
        step()
    }

    func next() { switchTo(current < count ? current + 1 : 1) }
    func previous() { switchTo(current > 1 ? current - 1 : count) }
}

/// Botão "Mesa atual / total" à esquerda do relógio: clique = menu de Mesas; rolagem = próxima/anterior.
final class SpacesButton: BarControl {
    private let icon = NSImageView()
    private let label = makeLabel("1/1", font: W10.Font.sm, align: .left)

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityLabel("Mesas")
        icon.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "Mesas")?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .regular))
        icon.contentTintColor = W10.Color.text
        icon.imageScaling = .scaleProportionallyUpOrDown
        addSubview(icon); addSubview(label)
        NotificationCenter.default.addObserver(self, selector: #selector(update), name: SpacesService.changed, object: nil)
        onClick = { [weak self] ev in self?.showMenu(ev) }
        onRightClick = { _ in AXController.openMissionControl() }
        update()
    }
    required init?(coder: NSCoder) { return nil }

    @objc private func update() {
        let s = SpacesService.shared
        label.stringValue = "\(s.current)/\(s.count)"
        toolTip = "Mesa \(s.current) de \(s.count) — clique para trocar, botão direito = Mission Control"
        setAccessibilityValue("Mesa \(s.current) de \(s.count)")
        needsLayout = true; needsDisplay = true
    }

    var preferredWidth: CGFloat {
        let tw = (label.stringValue as NSString).size(withAttributes: [.font: W10.Font.sm]).width
        return W10.Space.md + 16 + W10.Space.sm + ceil(tw) + W10.Space.md
    }

    override func setFrameSize(_ newSize: NSSize) { super.setFrameSize(newSize); needsLayout = true }

    override func layout() {
        super.layout()
        icon.frame = NSRect(x: W10.Space.md, y: (bounds.height - 16) / 2, width: 16, height: 16)
        label.frame = NSRect(x: icon.frame.maxX + W10.Space.sm, y: (bounds.height - 16) / 2, width: bounds.width - icon.frame.maxX - W10.Space.sm, height: 16)
    }

    override func scrollWheel(with event: NSEvent) {
        guard abs(event.scrollingDeltaY) > 2 || abs(event.scrollingDeltaX) > 2 else { return }
        let d = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.scrollingDeltaX
        if d < 0 { SpacesService.shared.next() } else { SpacesService.shared.previous() }
    }

    private func showMenu(_ event: NSEvent) {
        SpacesService.shared.refresh()
        let s = SpacesService.shared
        let menu = NSMenu()
        for i in 1...s.count {
            let it = NSMenuItem(title: "Mesa \(i)", action: #selector(pick(_:)), keyEquivalent: "")
            it.target = self; it.tag = i; it.state = i == s.current ? .on : .off
            menu.addItem(it)
        }
        menu.addItem(.separator())
        let mc = NSMenuItem(title: "Mission Control", action: #selector(missionControl), keyEquivalent: "")
        mc.target = self; menu.addItem(mc)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: bounds.maxY), in: self)
    }

    @objc private func pick(_ sender: NSMenuItem) { SpacesService.shared.switchTo(sender.tag) }
    @objc private func missionControl() { AXController.openMissionControl() }

    override func draw(_ dirtyRect: NSRect) { drawBackground() }
}
