import AppKit

/// Tokens da skin "Windows 10 taskbar" (métricas públicas da Barra de Tarefas do Windows 10, 100 %).
/// Nenhuma cor ou medida literal deve existir fora deste arquivo.
enum W10 {
    // MARK: Cores (hex do tokens.json)
    enum Color {
        static let bg            = NSColor(hex: 0x101010)
        static let bgAccent      = NSColor(hex: 0x0072C6)
        static let surface       = NSColor(hex: 0x1F1F1F)
        static let surfaceRaised = NSColor(hex: 0x2B2B2B)
        static let border        = NSColor(hex: 0x3A3A3A)
        static let text          = NSColor(hex: 0xFFFFFF)
        static let textMuted     = NSColor(hex: 0xB3B3B3)
        static let accent        = NSColor(hex: 0x0072C6)
        static let accentLight   = NSColor(hex: 0x4CC2FF)
        static let onAccent      = NSColor(hex: 0xFFFFFF)
        static let indicator     = NSColor(hex: 0x4CC2FF)
        static let indicatorOnAccent = NSColor(hex: 0xFFFFFF)
        static let success       = NSColor(hex: 0x06B025)
        static let warning       = NSColor(hex: 0xFFB900)
    }

    // MARK: Overlays (alfa sobre o fundo)
    enum Overlay {
        static let barAlpha: CGFloat = 0.85
        static let barAlphaAccent: CGFloat = 0.90
        static let flyoutAlpha: CGFloat = 0.92
        static let hover        = NSColor.white.withAlphaComponent(0.10)
        static let pressed      = NSColor.white.withAlphaComponent(0.15)
        static let active       = NSColor.white.withAlphaComponent(0.12)
        static let activeHover  = NSColor.white.withAlphaComponent(0.18)
        static let stackEdge    = NSColor.white.withAlphaComponent(0.35)
        static let showDesktopHover = NSColor.white.withAlphaComponent(0.25)
        static let topEdge      = NSColor.white.withAlphaComponent(0.06)
    }

    // MARK: Medidas (pt)
    enum Size {
        static let barHeight: CGFloat = 40
        static let hiddenSliver: CGFloat = 2
        static let startWidth: CGFloat = 48
        static let buttonWidth: CGFloat = 60
        static let buttonMinWhenFull: CGFloat = 36
        static let icon: CGFloat = 24
        static let indicatorHeight: CGFloat = 2
        static let indicatorInsetRunning: CGFloat = 2
        static let stackSegmentWidth: CGFloat = 4
        static let stackSegmentGap: CGFloat = 2
        static let trayPadding: CGFloat = 8
        static let clockMinWidth: CGFloat = 64
        static let showDesktopWidth: CGFloat = 20
        static let thumbWidth: CGFloat = 200
        static let thumbHeight: CGFloat = 120
        static let thumbHeader: CGFloat = 32
        static let flyoutPadding: CGFloat = 8
        static let flyoutGap: CGFloat = 8
        static let startMenuWidth: CGFloat = 360
        static let startMenuHeight: CGFloat = 600
        static let startRowHeight: CGFloat = 36
        static let startRailWidth: CGFloat = 48
        static let calendarWidth: CGFloat = 320
        static let calendarCell: CGFloat = 40
        static let labelGap: CGFloat = 8
    }

    // MARK: Espaço
    enum Space {
        static let xs: CGFloat = 2
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
    }

    // MARK: Tipografia (SF do sistema no papel do Segoe UI)
    enum Font {
        static let xs = NSFont.systemFont(ofSize: 11)
        static let sm = NSFont.systemFont(ofSize: 12)
        static let base = NSFont.systemFont(ofSize: 13)
        static let md = NSFont.systemFont(ofSize: 14)
        static let lg = NSFont.systemFont(ofSize: 20, weight: .light)
        static let xl = NSFont.systemFont(ofSize: 28, weight: .light)
    }

    // MARK: Movimento (s)
    enum Motion {
        static let hover: TimeInterval = 0.10
        static let flyout: TimeInterval = 0.15
        static let autohide: TimeInterval = 0.15
        static let autohideDelay: TimeInterval = 0.40
        static let timing = CAMediaTimingFunction(controlPoints: 0.1, 0.9, 0.2, 1.0)
    }

    /// Cor de fundo da barra conforme a variante escolhida.
    static func barColor(useAccent: Bool, transparent: Bool) -> NSColor {
        let base = useAccent ? Color.bgAccent : Color.bg
        let alpha = transparent ? (useAccent ? Overlay.barAlphaAccent : Overlay.barAlpha) : 1.0
        return base.withAlphaComponent(alpha)
    }

    static func indicatorColor(useAccent: Bool) -> NSColor {
        useAccent ? Color.indicatorOnAccent : Color.indicator
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
