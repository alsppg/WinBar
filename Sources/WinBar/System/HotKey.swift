import AppKit
import Carbon.HIToolbox

/// Atalhos globais via Carbon (RegisterEventHotKey) — sem dependências externas.
final class HotKeyCenter {
    static let shared = HotKeyCenter()
    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var nextID: UInt32 = 1
    private var installed = false

    private init() {}

    private func installHandlerIfNeeded() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, eventRef, _ -> OSStatus in
            guard let event = eventRef else { return noErr }
            var hk = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            if status == noErr { HotKeyCenter.shared.handlers[hk.id]?() }
            return noErr
        }, 1, &spec, nil, nil)
    }

    @discardableResult
    func register(_ spec: HotKeySpec, handler: @escaping () -> Void) -> UInt32 {
        installHandlerIfNeeded()
        var mods: UInt32 = 0
        if spec.control { mods |= UInt32(controlKey) }
        if spec.option { mods |= UInt32(optionKey) }
        if spec.shift { mods |= UInt32(shiftKey) }
        if spec.command { mods |= UInt32(cmdKey) }
        let id = nextID; nextID += 1
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: OSType(0x54424152) /* 'TBAR' */, id: id)
        let status = RegisterEventHotKey(spec.keyCode, mods, hkID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref = ref {
            refs[id] = ref
            handlers[id] = handler
        } else {
            Log.warn("hotkey não registrada (status \(status))")
        }
        return id
    }

    func unregisterAll() {
        refs.values.forEach { UnregisterEventHotKey($0) }
        refs.removeAll(); handlers.removeAll()
    }
}
