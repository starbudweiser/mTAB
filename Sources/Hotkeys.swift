// Raccourcis globaux : tap d'événements (Accessibilité). Gère l'ouverture, la navigation, la recherche et le relâchement.
import AppKit
import CoreGraphics

@MainActor
final class Hotkeys {
    static let shared = Hotkeys()
    var paused = false           // vrai pendant l'enregistrement d'un raccourci
    private var tap: CFMachPort?
    private var retry: Timer?

    /// Installe le tap ; tant que l'autorisation Accessibilité manque, réessaie toutes les 2 s.
    func start() {
        if install() { return }
        retry?.invalidate()
        retry = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
            MainActor.assumeIsolated { if self?.install() == true { t.invalidate() } }
        }
    }

    private func install() -> Bool {
        if tap != nil { return true }
        guard AXIsProcessTrusted() else { return false }
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask,
                                        callback: hotkeyCallback, userInfo: nil) else { return false }
        tap = t
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        return true
    }

    func reenable() { if let t = tap { CGEvent.tapEnable(tap: t, enable: true) } }

    /// Renvoie vrai si l'événement est consommé.
    func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if paused { return false }
        let flags = event.flags.rawValue & modMask
        let key = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let sw = Switcher.shared
        switch type {
        case .keyDown:
            let p = Prefs.shared.d
            if sw.isOpen, let s = sw.shortcut {
                let k = p.keys
                let m = sw.model
                // arrêt immédiat des touches propres au mode recherche
                if key == k.cancel { sw.escape(); return true }
                if key == k.select || key == 76 { sw.commit(); return true }
                do {
                    switch key {
                    case 123: sw.move(-1); return true
                    case 124: sw.move(1); return true
                    case 126: sw.moveRow(-1); return true
                    case 125: sw.moveRow(1); return true
                    default: break
                    }
                }
                if key == s.key && flags & s.mods == s.mods {
                    sw.move(flags & 0x20000 != 0 && s.mods & 0x20000 == 0 ? -1 : 1); return true
                }
                if m.searching {
                    if key == 51 { m.query = String(m.query.dropLast()); m.clampSelection(); sw.updatePreview(); return true }
                    if flags & (0x40000 | 0x100000) == 0 || flags & s.mods == flags, let text = typed(event) {
                        m.query += text; m.selected = 0; m.clampSelection(); sw.updatePreview()
                    }
                    return true
                }
                if p.search, key == k.search { m.searching = true; return true }
                if let w = m.current {
                    if key == k.close { sw.act("close", w); return true }
                    if key == k.minimize { sw.act("min", w); return true }
                    if key == k.fullscreen { sw.act("full", w); return true }
                    if key == k.quit { sw.quitApp(); return true }
                    if key == k.hide { sw.hideApp(); return true }
                }
                return true
            }
            // une app d'exception peut garder ses propres raccourcis (machines virtuelles, bureaux à distance…)
            if let ex = Prefs.shared.exception(NSWorkspace.shared.frontmostApplication?.bundleIdentifier), ex.ignore == .whenFront { return false }
            for s in p.shortcuts where s.key == key {
                let base = flags & ~UInt64(0x20000)
                if flags == s.mods || (s.mods & 0x20000 == 0 && base == s.mods && flags & 0x20000 != 0) {
                    sw.open(s, reverse: flags & 0x20000 != 0 && s.mods & 0x20000 == 0)
                    return true
                }
            }
            return false
        case .keyUp:
            if sw.isOpen { return true }
            return false
        case .flagsChanged:
            if sw.isOpen, let s = sw.shortcut, flags & s.mods != s.mods {
                if !sw.keepOpen { sw.commit() } else { sw.released = true }
            }
            return false
        default: return false
        }
    }

    /// Caractère tapé, sans l'effet des modificateurs (⌥a donne « a », pas « å »).
    private func typed(_ event: CGEvent) -> String? {
        guard let copy = event.copy() else { return nil }
        copy.flags = []
        var n = 0
        var buf = [UniChar](repeating: 0, count: 4)
        copy.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &n, unicodeString: &buf)
        guard n > 0 else { return nil }
        let s = String(utf16CodeUnits: buf, count: n)
        guard let c = s.unicodeScalars.first, c.value >= 32, c.value != 127 else { return nil }
        return s
    }
}

private func hotkeyCallback(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent, _ info: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        MainActor.assumeIsolated { Hotkeys.shared.reenable() }
        return Unmanaged.passUnretained(event)
    }
    let consumed = MainActor.assumeIsolated { Hotkeys.shared.handle(type, event) }
    return consumed ? nil : Unmanaged.passUnretained(event)
}
