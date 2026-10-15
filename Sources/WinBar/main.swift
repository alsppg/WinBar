import AppKit

// Ponto de entrada. O app é um agente (sem ícone no Dock): LSUIElement no Info.plist + política .accessory.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
