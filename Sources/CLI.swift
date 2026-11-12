// Ligne de commande : « mTAB --list » (JSON), « mTAB --focus <id> ».
import AppKit

enum CLI {
    /// Renvoie vrai si un argument de ligne de commande a été traité (l'appli ne démarre alors pas).
    static func handle(_ args: [String]) -> Bool {
        guard let first = args.first else { return false }
        switch first {
        case "--list":
            let wins = MainActor.assumeIsolated { WindowList.fetch(nil) }
            let rows: [[String: Any]] = wins.map { ["id": Int($0.id), "app": $0.appName, "title": $0.title, "pid": Int($0.pid),
                                                    "minimized": $0.minimized, "hidden": $0.hidden, "space": $0.spaceNumber ?? 0] }
            if let d = try? JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys]) {
                FileHandle.standardOutput.write(d); print()
            }
            return true
        case "--focus":
            guard args.count > 1, let id = UInt32(args[1]) else { fputs("usage : mtab --focus <id>\n", stderr); exit(2) }
            let ok: Bool = MainActor.assumeIsolated {
                guard let w = WindowList.fetch(nil).first(where: { $0.id == id }) else { return false }
                WinActions.focus(w); return true
            }
            if !ok { fputs("fenêtre \(id) introuvable\n", stderr); exit(1) }
            return true
        case "--help", "-h":
            print("mtab --list           liste les fenêtres (JSON)\nmtab --focus <id>     active une fenêtre\nmtab --settings       ouvre les réglages (au lancement de l'appli)")
            return true
        default: return false
        }
    }
}
