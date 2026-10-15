import AppKit

/// Flyout do relógio: hora grande, data por extenso e calendário do mês com navegação.
final class ClockFlyout: Flyout {
    private var month: Date
    private let grid = NSView()
    private let monthLabel = makeLabel("", font: W10.Font.base)
    private let cal = Calendar.current

    init() {
        month = Date()
        let cell = W10.Size.calendarCell
        let w = W10.Size.calendarWidth
        let gridH = cell * 7 + 24
        super.init(size: NSSize(width: w, height: 96 + gridH + W10.Size.flyoutPadding * 2))
        let pad = W10.Size.flyoutPadding
        let top = content.bounds.height

        let time = DateFormatter(); time.timeStyle = .short; time.dateStyle = .none
        let date = DateFormatter(); date.dateStyle = .full; date.timeStyle = .none
        let timeLabel = makeLabel(time.string(from: Date()), font: W10.Font.xl)
        timeLabel.frame = NSRect(x: pad * 2, y: top - pad - 40, width: w - pad * 4, height: 36)
        content.addSubview(timeLabel)
        let dateLabel = makeLabel(date.string(from: Date()), font: W10.Font.base, color: W10.Color.accentLight)
        dateLabel.frame = NSRect(x: pad * 2, y: top - pad - 64, width: w - pad * 4, height: 20)
        content.addSubview(dateLabel)
        let sep = NSView(frame: NSRect(x: pad * 2, y: top - 96, width: w - pad * 4, height: 1))
        sep.wantsLayer = true; sep.layer?.backgroundColor = W10.Color.border.cgColor
        content.addSubview(sep)

        // Cabeçalho do mês com setas
        monthLabel.frame = NSRect(x: pad * 2, y: top - 96 - 28, width: w - pad * 4 - 64, height: 22)
        content.addSubview(monthLabel)
        let up = arrowButton("chevron.up", x: w - pad * 2 - 56, y: top - 96 - 27, action: #selector(prevMonth))
        let down = arrowButton("chevron.down", x: w - pad * 2 - 28, y: top - 96 - 27, action: #selector(nextMonth))
        content.addSubview(up); content.addSubview(down)

        grid.frame = NSRect(x: (w - cell * 7) / 2, y: pad, width: cell * 7, height: cell * 7)
        content.addSubview(grid)
        render()
    }

    private func arrowButton(_ symbol: String, x: CGFloat, y: CGFloat, action: Selector) -> NSButton {
        let b = NSButton(frame: NSRect(x: x, y: y, width: 24, height: 24))
        b.bezelStyle = .inline; b.isBordered = false
        b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        b.contentTintColor = W10.Color.text
        b.target = self; b.action = action
        return b
    }

    @objc private func prevMonth() { month = cal.date(byAdding: .month, value: -1, to: month) ?? month; render() }
    @objc private func nextMonth() { month = cal.date(byAdding: .month, value: 1, to: month) ?? month; render() }

    private func render() {
        grid.subviews.forEach { $0.removeFromSuperview() }
        let cell = W10.Size.calendarCell
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        monthLabel.stringValue = f.string(from: month).capitalized

        // Linha de dias da semana
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let first = cal.firstWeekday - 1
        for i in 0..<7 {
            let l = makeLabel(symbols[(first + i) % 7], font: W10.Font.xs, color: W10.Color.textMuted, align: .center)
            l.frame = NSRect(x: CGFloat(i) * cell, y: cell * 6, width: cell, height: cell)
            grid.addSubview(l)
        }
        guard let range = cal.range(of: .day, in: .month, for: month),
              let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: month)) else { return }
        let offset = (cal.component(.weekday, from: firstOfMonth) - cal.firstWeekday + 7) % 7
        let today = cal.startOfDay(for: Date())
        var slot = 0
        // dias do mês anterior (apagados)
        if offset > 0, let prev = cal.date(byAdding: .month, value: -1, to: firstOfMonth),
           let prevRange = cal.range(of: .day, in: .month, for: prev) {
            for d in (prevRange.count - offset + 1)...prevRange.count { place(day: d, slot: slot, muted: true, isToday: false); slot += 1 }
        }
        for d in range {
            let date = cal.date(byAdding: .day, value: d - 1, to: firstOfMonth)!
            place(day: d, slot: slot, muted: false, isToday: cal.startOfDay(for: date) == today); slot += 1
        }
        var next = 1
        while slot < 42 { place(day: next, slot: slot, muted: true, isToday: false); slot += 1; next += 1 }
    }

    private func place(day: Int, slot: Int, muted: Bool, isToday: Bool) {
        let cell = W10.Size.calendarCell
        let row = slot / 7, col = slot % 7
        let frame = NSRect(x: CGFloat(col) * cell, y: cell * CGFloat(5 - row), width: cell, height: cell)
        let v = DayCell(frame: frame, day: day, muted: muted, isToday: isToday)
        grid.addSubview(v)
    }
}

private final class DayCell: NSView {
    let day: Int, muted: Bool, isToday: Bool
    init(frame: NSRect, day: Int, muted: Bool, isToday: Bool) {
        self.day = day; self.muted = muted; self.isToday = isToday
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { return nil }
    override func draw(_ dirtyRect: NSRect) {
        if isToday {
            W10.Color.accent.setFill()
            NSBezierPath(ovalIn: bounds.insetBy(dx: 4, dy: 4)).fill()
        }
        let para = NSMutableParagraphStyle(); para.alignment = .center
        let color = isToday ? W10.Color.onAccent : (muted ? W10.Color.textMuted : W10.Color.text)
        ("\(day)" as NSString).draw(in: NSRect(x: 0, y: (bounds.height - 16) / 2, width: bounds.width, height: 16),
                                    withAttributes: [.font: W10.Font.sm, .foregroundColor: color, .paragraphStyle: para])
    }
}
