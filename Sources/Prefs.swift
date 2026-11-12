// Réglages (UserDefaults, JSON) : raccourcis, style, comportement, exceptions.
import AppKit
import Carbon.HIToolbox
import SwiftUI

enum Style: String, Codable, CaseIterable { case thumbs, icons, titles }
enum SizeChoice: String, Codable, CaseIterable { case small, medium, large, auto }
enum ReleaseMode: String, Codable, CaseIterable { case select, keepOpen }
enum AppsFilter: String, Codable { case all, active }
enum SpacesFilter: String, Codable { case all, current }
enum ScreensFilter: String, Codable { case all, current }
enum ShowFilter: String, Codable { case show, hide }
enum ThemeChoice: String, Codable, CaseIterable { case dark, light, system }
enum IconMode: String, Codable, CaseIterable { case dock, menubar, both }
enum HideMode: String, Codable, CaseIterable { case never, always }
enum IgnoreMode: String, Codable, CaseIterable { case never, whenFront }

let modMask: UInt64 = 0x40000 | 0x80000 | 0x20000 | 0x100000 // ⌃ ⌥ ⇧ ⌘

struct Shortcut: Codable, Identifiable, Equatable {
    var id = UUID()
    var mods: UInt64 = 0x80000        // ⌥
    var key: Int = 48                 // Tab
    var apps: AppsFilter = .all
    var spaces: SpacesFilter = .all
    var screens: ScreensFilter = .all
    var minimized: ShowFilter = .show
    var hidden: ShowFilter = .show

    var display: String {
        var s = ""
        if mods & 0x40000 != 0 { s += "⌃" }
        if mods & 0x80000 != 0 { s += "⌥" }
        if mods & 0x20000 != 0 { s += "⇧" }
        if mods & 0x100000 != 0 { s += "⌘" }
        return s + KeyNames.name(key)
    }
}

struct AppException: Codable, Identifiable, Equatable {
    var bundleId: String
    var hide: HideMode = .never
    var ignore: IgnoreMode = .never
    var id: String { bundleId }
}

/// Touches utilisées pendant que le sélecteur est ouvert (codes de touches physiques ; les défauts suivent la disposition du clavier).
struct InUseKeys: Codable, Equatable {
    var select = 36, cancel = 53
    var search = KeyNames.code(for: "s") ?? 1
    var close = KeyNames.code(for: "w") ?? 13
    var minimize = KeyNames.code(for: "m") ?? 46
    var fullscreen = KeyNames.code(for: "f") ?? 3
    var quit = KeyNames.code(for: "q") ?? 12
    var hide = KeyNames.code(for: "h") ?? 4
}

enum KeyNames {
    /// Touches qui ne dépendent pas de la disposition du clavier.
    static let special: [Int: String] = [
        48: "⇥", 49: "␣", 36: "↩", 76: "⌤", 51: "⌫", 53: "⎋", 117: "⌦", 123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]

    /// Nom de la touche physique selon la disposition active (AZERTY, QWERTZ, QWERTY…).
    static func name(_ code: Int) -> String {
        if let s = special[code] { return s }
        guard let src = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData) else { return "#\(code)" }
        let layout = unsafeBitCast(ptr, to: CFData.self)
        let data = CFDataGetBytePtr(layout)!
        var dead: UInt32 = 0
        var len = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = data.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) {
            UCKeyTranslate($0, UInt16(code), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                           OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, 4, &len, &chars)
        }
        guard status == noErr, len > 0 else { return "#\(code)" }
        return String(utf16CodeUnits: chars, count: len).uppercased()
    }

    /// Code de la touche qui produit ce caractère dans la disposition active (nil si aucune).
    static func code(for char: Character) -> Int? {
        (0..<128).first { name($0).lowercased() == String(char) && special[$0] == nil }
    }
}

struct PrefsData: Codable {
    /// Par défaut mTAB remplace le sélecteur du système : ⌘⇥ (toutes les fenêtres) et ⌘ + la touche au-dessus de Tab
    /// (fenêtres de l'app active). Cette touche est la 10 sur un clavier ISO (AZERTY…), la 50 sur ANSI.
    static func defaultShortcuts() -> [Shortcut] {
        let iso = KBGetLayoutType(Int16(LMGetKbdType())) == kKeyboardISO
        return [Shortcut(mods: 0x100000, key: 48), Shortcut(mods: 0x100000, key: iso ? 10 : 50, apps: .active)]
    }
    static func defaultExceptions() -> [AppException] {
        [AppException(bundleId: "com.apple.finder", hide: .always),
         AppException(bundleId: "com.apple.ScreenSharing", ignore: .whenFront),
         AppException(bundleId: "com.microsoft.rdc.macos", ignore: .whenFront),
         AppException(bundleId: "com.teamviewer.TeamViewer", ignore: .whenFront),
         AppException(bundleId: "org.virtualbox.app.VirtualBoxVM", ignore: .whenFront),
         AppException(bundleId: "com.parallels.desktop.console", ignore: .whenFront),
         AppException(bundleId: "com.utmapp.UTM", ignore: .whenFront),
         AppException(bundleId: "com.vmware.fusion", ignore: .whenFront)]
    }

    var shortcuts: [Shortcut] = PrefsData.defaultShortcuts()
    var style: Style = .thumbs
    var size: SizeChoice = .auto
    var release: ReleaseMode = .select
    var preview = true
    var theme: ThemeChoice = .dark
    var search = true
    var swipe = false
    var presence: IconMode = .menubar
    var exceptions: [AppException] = PrefsData.defaultExceptions()
    var keys = InUseKeys()   // touches du sélecteur ouvert (fixes)
}

@MainActor
final class Prefs: ObservableObject {
    static let shared = Prefs()
    private let key = "mtab.prefs.v2"
    @Published var d: PrefsData { didSet { save() } }

    init() {
        if let data = UserDefaults.standard.data(forKey: key), let v = try? JSONDecoder().decode(PrefsData.self, from: data) { d = v }
        else { d = PrefsData() }
    }
    private func save() {
        if let data = try? JSONEncoder().encode(d) { UserDefaults.standard.set(data, forKey: key) }
        Socle.apply(d.theme == .dark ? .dark : d.theme == .light ? .light : .system)
        Presence.shared.apply()
        SystemShortcuts.sync(d.shortcuts)
    }

    func exception(_ bundleId: String?) -> AppException? { d.exceptions.first { $0.bundleId == bundleId } }
}

/// Désactive les raccourcis du système (⌘⇥, ⌘⇧⇥, ⌘ + touche au-dessus de Tab) quand un raccourci mTAB les remplace ;
/// les réactive quand mTAB ne les utilise plus ou se ferme.
enum SystemShortcuts {
    static func sync(_ shortcuts: [Shortcut]) {
        let cmdOnly: (Shortcut) -> Bool = { $0.mods & modMask == 0x100000 || $0.mods & modMask == 0x120000 }
        let tab = shortcuts.contains { cmdOnly($0) && $0.key == 48 }
        let above = shortcuts.contains { cmdOnly($0) && ($0.key == 50 || $0.key == 10) }
        _ = CGSSetSymbolicHotKeyEnabled(1, !tab)
        _ = CGSSetSymbolicHotKeyEnabled(2, !tab)
        _ = CGSSetSymbolicHotKeyEnabled(27, !above)
    }
    static func restoreAll() {
        for k: Int32 in [1, 2, 27] { _ = CGSSetSymbolicHotKeyEnabled(k, true) }
    }
}
