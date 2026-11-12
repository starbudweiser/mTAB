// Nom de l'appli (règle Socle « Nom de l'appli ») : lettre minuscule « m » colorée partout dans l'interface (hors menus).
import AppKit
import SwiftUI

enum Brand {
    static let name = "mTAB"
    /// Couleur du logo (cyan Socle), assombrie en thème clair pour rester lisible.
    static let color = NSColor(name: nil) { a in
        a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0x38 / 255, green: 0xbd / 255, blue: 0xf8 / 255, alpha: 1)
            : NSColor(srgbRed: 0x03 / 255, green: 0x69 / 255, blue: 0xa1 / 255, alpha: 1)
    }
    static func lowercaseRanges(in text: String) -> [NSRange] {
        let ns = text as NSString
        var out: [NSRange] = []
        var from = 0
        while from < ns.length {
            let r = ns.range(of: name, options: .literal, range: NSRange(location: from, length: ns.length - from))
            if r.location == NSNotFound { break }
            from = r.location + r.length
            if r.location > 0, isWord(ns.character(at: r.location - 1), "./@-_") { continue }
            if from < ns.length, isWord(ns.character(at: from), "-_") { continue }
            out.append(NSRange(location: r.location, length: 1)) // le « m »
        }
        return out
    }
    private static func isWord(_ u: unichar, _ extra: String) -> Bool {
        guard let s = Unicode.Scalar(u) else { return false }
        return CharacterSet.alphanumerics.contains(s) || extra.unicodeScalars.contains(s)
    }
    static func colored(_ base: NSAttributedString) -> NSAttributedString {
        let out = NSMutableAttributedString(attributedString: base)
        for r in lowercaseRanges(in: base.string) { out.addAttribute(.foregroundColor, value: color, range: r) }
        return out
    }
    static var swiftUIColor: Color { Color(nsColor: color) }
}
