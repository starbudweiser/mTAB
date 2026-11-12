// Point d'entrée : application de barre de menus (ou Dock), mode ligne de commande, menus.
import AppKit
import SwiftUI

@MainActor
final class Presence: NSObject {
    static let shared = Presence()
    private var item: NSStatusItem?

    func apply() {
        let mode = Prefs.shared.d.presence
        let wanted: NSApplication.ActivationPolicy = mode == .menubar ? .accessory : .regular
        if NSApp.activationPolicy() != wanted { NSApp.setActivationPolicy(wanted) }
        if mode == .dock { removeItem() } else { installItem() }
    }

    private func installItem() {
        if item == nil { item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength) }
        guard let b = item?.button else { return }
        b.image = Presence.barIcon(); b.imagePosition = .imageOnly; b.toolTip = L("bar.tip")
        item?.menu = nil // jamais item.menu : le menu est ouvert sous l'icône par nos soins (plusieurs écrans)
        b.target = self; b.action = #selector(clicked)
        b.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// Silhouette monochrome (image « modèle » : suit le thème clair ou sombre de la barre) : deux fenêtres superposées.
    static func barIcon() -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke(); NSColor.black.setFill()
            let back = NSBezierPath(roundedRect: NSRect(x: 1.75, y: 6.25, width: 10.5, height: 9.5), xRadius: 2.2, yRadius: 2.2)
            back.lineWidth = 1.5; back.stroke()
            let front = NSBezierPath(roundedRect: NSRect(x: 6, y: 2, width: 10.5, height: 9.5), xRadius: 2.2, yRadius: 2.2)
            front.fill()
            return true
        }
        img.isTemplate = true
        return img
    }

    private func removeItem() {
        if let i = item { NSStatusBar.system.removeStatusItem(i); item = nil }
    }

    @objc private func clicked() {
        guard let b = item?.button else { return }
        let menu = NSMenu()
        menu.addItem(withTitle: L("menu.settings"), action: #selector(settings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: L("menu.about"), action: #selector(about), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L("menu.quit"), action: #selector(quit), keyEquivalent: "q").target = self
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: b.isFlipped ? b.bounds.maxY + 4 : -4), in: b)
    }
    @objc func settings() { SettingsWindow.show() }
    @objc func about() { About.show() }
    @objc func quit() { NSApp.terminate(nil) }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var swipeMonitor: Any?
    private var termSource: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ n: Notification) {
        // une seule instance : un second lancement (service + ouverture manuelle) rouvre les réglages de la première
        if let bid = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bid).contains(where: { $0 != .current }) {
            DistributedNotificationCenter.default().post(name: .init("fr.stephan.mtab.showSettings"), object: bid)
            exit(0)
        }
        DistributedNotificationCenter.default().addObserver(forName: .init("fr.stephan.mtab.showSettings"), object: Bundle.main.bundleIdentifier, queue: .main) { _ in
            MainActor.assumeIsolated { SettingsWindow.show() }
        }
        // SIGTERM (arrêt du service) : rendre les raccourcis du système avant de quitter
        signal(SIGTERM, SIG_IGN)
        let term = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        term.setEventHandler { SystemShortcuts.restoreAll(); exit(0) }
        term.resume(); termSource = term
        buildMenu()
        Prefs.shared.d = Prefs.shared.d // applique thème et présence
        Hotkeys.shared.start()
        swipeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .swipe) { e in
            MainActor.assumeIsolated { if Prefs.shared.d.swipe { Switcher.shared.swipe(e.deltaX) } }
        }
        // Silencieux : la fenêtre de réglages ne s'ouvre seule qu'au tout premier lancement ou avec --settings.
        let first = !UserDefaults.standard.bool(forKey: "mtab.launched")
        UserDefaults.standard.set(true, forKey: "mtab.launched")
        if first || CommandLine.arguments.contains("--settings") { SettingsWindow.show() }
        if let i = CommandLine.arguments.firstIndex(of: "--demo-switcher") {
            let style = CommandLine.arguments.indices.contains(i + 1) ? Style(rawValue: CommandLine.arguments[i + 1]) ?? .thumbs : .thumbs
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { Demo.showSwitcher(style) }
        }
        // préchauffe le cache d'aperçus, sans bloquer le démarrage
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            Task { @MainActor in
                if AXIsProcessTrusted() { await Thumbs.shared.refresh(WindowList.fetch(nil).map(\.id), into: nil) }
            }
        }
    }

    func applicationWillTerminate(_ n: Notification) { SystemShortcuts.restoreAll() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindow.show(); return true
    }

    private func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let app = NSMenu()
        app.addItem(withTitle: L("menu.about"), action: #selector(Presence.about), keyEquivalent: "").target = Presence.shared
        app.addItem(withTitle: L("menu.settings"), action: #selector(Presence.settings), keyEquivalent: ",").target = Presence.shared
        app.addItem(.separator())
        app.addItem(withTitle: L("menu.quit"), action: #selector(Presence.quit), keyEquivalent: "q").target = Presence.shared
        appItem.submenu = app
        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: L("menu.edit"))
        edit.addItem(withTitle: L("menu.copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: L("menu.paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: L("menu.selectAll"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        NSApp.mainMenu = main
    }
}

@main
struct MTABMain {
    static func main() {
        if CLI.handle(Array(CommandLine.arguments.dropFirst())) { return }
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            Socle.brand("mTAB", color: Brand.swiftUIColor)
            app.run()
            _ = delegate
        }
    }
}
