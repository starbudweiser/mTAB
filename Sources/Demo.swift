// Mode démonstration (captures pour le site) : sélecteur avec des fenêtres fictives, sans rien lire du système.
//   mTAB --demo-switcher thumbs|icons|titles
import AppKit
import SwiftUI

@MainActor
enum Demo {
    // Noms et titres fictifs, dans les 4 langues [fr, en, es, it].
    private static let texts: [[[String]]] = [
        [["Carnet", "Notes", "Notas", "Note"], ["Plan de tournage", "Shooting plan", "Plan de rodaje", "Piano di riprese"]],
        [["Éditeur", "Editor", "Editor", "Editor"], ["rapport-trimestriel.md", "quarterly-report.md", "informe-trimestral.md", "rapporto-trimestrale.md"]],
        [["Navigateur", "Browser", "Navegador", "Browser"], ["Docs — Mise en route", "Docs — Quick start", "Docs — Primeros pasos", "Docs — Introduzione"]],
        [["Terminal", "Terminal", "Terminal", "Terminale"], ["build — réussi", "build — passed", "build — superado", "build — superato"]],
        [["Photos", "Photos", "Fotos", "Foto"], ["Vacances en Bretagne", "Summer in Brittany", "Vacaciones en Bretaña", "Vacanze in Bretagna"]],
        [["Messages", "Messages", "Mensajes", "Messaggi"], ["Équipe projet", "Project team", "Equipo del proyecto", "Team di progetto"]],
    ]
    private static let looks: [(String, NSColor)] = [
        ("note.text", NSColor(srgbRed: 0.98, green: 0.75, blue: 0.14, alpha: 1)),
        ("doc.plaintext", NSColor(srgbRed: 0.22, green: 0.74, blue: 0.97, alpha: 1)),
        ("globe", NSColor(srgbRed: 0.29, green: 0.87, blue: 0.5, alpha: 1)),
        ("terminal", NSColor(srgbRed: 0.6, green: 0.6, blue: 0.65, alpha: 1)),
        ("photo", NSColor(srgbRed: 0.97, green: 0.44, blue: 0.44, alpha: 1)),
        ("bubble.left.fill", NSColor(srgbRed: 0.49, green: 0.83, blue: 0.99, alpha: 1)),
    ]
    private static var items: [(String, String, String, NSColor)] {
        texts.indices.map { (texts[$0][0][Lang.index], texts[$0][1][Lang.index], looks[$0].0, looks[$0].1) }
    }

    private static func icon(_ symbol: String, _ color: NSColor) -> NSImage {
        let img = NSImage(size: NSSize(width: 128, height: 128), flipped: false) { r in
            color.setFill(); NSBezierPath(roundedRect: r, xRadius: 28, yRadius: 28).fill()
            if let s = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 64, weight: .semibold)) {
                let t = s.tinted(.white); let w = t.size.width, h = t.size.height
                t.draw(in: NSRect(x: (128 - w) / 2, y: (128 - h) / 2, width: w, height: h))
            }
            return true
        }
        return img
    }

    private static func thumb(_ color: NSColor, _ seed: Int) -> NSImage {
        NSImage(size: NSSize(width: 640, height: 400), flipped: false) { r in
            NSColor(white: 0.97, alpha: 1).setFill(); r.fill()
            NSColor(white: 0.88, alpha: 1).setFill(); NSRect(x: 0, y: 372, width: 640, height: 28).fill()
            for (i, c) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
                c.setFill(); NSBezierPath(ovalIn: NSRect(x: 12 + i * 20, y: 380, width: 12, height: 12)).fill()
            }
            color.withAlphaComponent(0.85).setFill(); NSRect(x: 24, y: 250, width: 592, height: 96).fill()
            NSColor(white: 0.8, alpha: 1).setFill()
            for row in 0..<5 {
                let cut: Int = (row * 83 + seed * 47) % 260
                let width: CGFloat = CGFloat(592 - cut)
                let y: CGFloat = CGFloat(214 - row * 34)
                NSRect(x: 24, y: y, width: width, height: 14).fill()
            }
            return true
        }
    }

    static func showSwitcher(_ style: Style) {
        var wins: [WinInfo] = []; var thumbs: [CGWindowID: NSImage] = [:]
        for (i, it) in items.enumerated() {
            var w = WinInfo(id: CGWindowID(9000 + i), pid: 1, app: NSRunningApplication.current, appName: it.0, title: it.1, frame: .zero)
            w.iconOverride = icon(it.2, it.3)
            w.minimized = i == 3; w.onCurrentSpace = i != 5; w.spaceNumber = i == 5 ? 2 : nil
            wins.append(w); thumbs[w.id] = thumb(it.3, i)
        }
        Prefs.shared.d.style = style; Prefs.shared.d.preview = false
        Switcher.shared.present(wins, Shortcut(mods: 0x100000, key: 48), reverse: false, demoThumbs: thumbs)
        Switcher.shared.model.screen = CGSize(width: 1200, height: 820)   // taille d’écran de référence pour les captures
        Switcher.shared.model.selected = 1
    }
}

private extension NSImage {
    func tinted(_ color: NSColor) -> NSImage {
        let img = copy() as! NSImage; img.lockFocus()
        color.set(); NSRect(origin: .zero, size: img.size).fill(using: .sourceAtop); img.unlockFocus(); return img
    }
}
