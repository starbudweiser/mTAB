// Le sélecteur : modèle, panneau flottant, aperçu en taille réelle, validation / annulation.
import AppKit
import SwiftUI

struct Metrics {
    var cols = 1, cellW: CGFloat = 200, cellH: CGFloat = 150
    var gap: CGFloat = 12
    var totalW: CGFloat = 200, totalH: CGFloat = 150, availH: CGFloat = 600

    static func compute(n: Int, screen: CGSize, style: Style, size: SizeChoice) -> Metrics {
        let auto = size == .auto
        let f: CGFloat = size == .small ? 0.75 : size == .large ? 1.4 : 1
        var m = Metrics()
        let n = max(n, 1)
        // échelle selon la résolution de l'écran hôte (référence : 1512 pt de large) ; la disposition favorise l'horizontale
        let k = max(0.8, min(2.2, screen.width / 1512))
        let availW = screen.width * 0.94 - 40, availH = screen.height * 0.78 - 90
        m.availH = availH
        switch style {
        case .titles:
            m.cols = 1; m.cellW = min(620 * k, availW); m.cellH = 40; m.gap = 2
        case .icons:
            let s: CGFloat = auto ? max(76 * k, min(132 * k, availW / CGFloat(n) - 8)) : 112 * k * f
            m.cellW = s; m.cellH = s + 8
            m.cols = max(1, min(n, Int((availW + m.gap) / (s + m.gap))))
        case .thumbs:
            let maxW = 300 * k
            if auto {
                // le plus de colonnes possible tant que les vignettes gardent leur taille maximale ; sinon la plus grande taille qui tient
                var best: (w: CGFloat, c: Int)? = nil
                for c in 1...n {
                    let rows = (n + c - 1) / c
                    let w = min(maxW, (availW - CGFloat(c - 1) * m.gap) / CGFloat(c))
                    let h = w * 0.625 + 45
                    guard CGFloat(rows) * h + CGFloat(rows - 1) * m.gap <= availH else { continue }
                    if best == nil || w >= best!.w - 0.5 { best = (w, c) }
                }
                if let b = best { m.cellW = b.w; m.cols = b.c }
                else { m.cellW = 150 * k; m.cols = max(1, Int((availW + m.gap) / (m.cellW + m.gap))) }
            } else {
                m.cellW = 220 * k * f; m.cols = max(1, min(n, Int((availW + m.gap) / (m.cellW + m.gap))))
            }
            m.cellH = m.cellW * 0.625 + 45
        }
        let rows = (n + m.cols - 1) / m.cols
        m.totalW = CGFloat(m.cols) * m.cellW + CGFloat(m.cols - 1) * m.gap
        m.totalH = CGFloat(rows) * m.cellH + CGFloat(rows - 1) * m.gap
        return m
    }
}

@MainActor
final class SwitcherModel: ObservableObject {
    @Published var all: [WinInfo] = []
    @Published var query = ""
    @Published var selected = 0
    @Published var thumbs: [CGWindowID: NSImage] = [:]
    @Published var style: Style = .thumbs
    @Published var size: SizeChoice = .auto
    @Published var searchEnabled = true
    @Published var searching = false
    var screen = CGSize(width: 1440, height: 900)
    var mouseOrigin = NSEvent.mouseLocation

    var filtered: [WinInfo] {
        guard !query.isEmpty else { return all }
        let q = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        return all.filter {
            $0.title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).contains(q)
                || $0.appName.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).contains(q)
        }
    }
    var metrics: Metrics { Metrics.compute(n: filtered.count, screen: screen, style: style, size: size) }
    var current: WinInfo? { let f = filtered; return f.indices.contains(selected) ? f[selected] : nil }

    func clampSelection() { selected = max(0, min(selected, filtered.count - 1)) }
    func remove(_ id: CGWindowID) { all.removeAll { $0.id == id }; clampSelection() }
}

final class SwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class Switcher {
    static let shared = Switcher()
    let model = SwitcherModel()
    private(set) var isOpen = false
    private(set) var shortcut: Shortcut?
    var released = false
    var previewOn = true
    var keepOpen = false
    private var panel: SwitcherPanel?
    private var previewPanel: NSPanel?
    private var previewView: NSImageView?
    private var showTask: DispatchWorkItem?
    private var swipeCommit: Timer?

    func open(_ s: Shortcut, reverse: Bool) { present(WindowList.fetch(s), s, reverse: reverse) }

    /// Affiche le sélecteur pour une liste de fenêtres ; `demo` : aperçus fournis, aucune capture ni réglage lu au clavier.
    func present(_ wins: [WinInfo], _ s: Shortcut, reverse: Bool, demoThumbs: [CGWindowID: NSImage]? = nil) {
        let mouse = NSEvent.mouseLocation
        let primaryH = NSScreen.screens[0].frame.height
        let mouseScreen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.screens[0]
        // écran de la fenêtre active (sinon celui du pointeur)
        var screen = mouseScreen
        if let f = wins.first?.frame, let sc = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: f.midX, y: primaryH - f.midY)) }) { screen = sc }
        let p = Prefs.shared.d
        model.all = wins; model.query = ""; model.thumbs = demoThumbs ?? Thumbs.shared.cache.filter { c in wins.contains { $0.id == c.key } }
        model.style = p.style; model.size = p.size; model.searchEnabled = p.search; model.searching = false
        previewOn = p.preview; keepOpen = p.release == .keepOpen
        model.screen = screen.frame.size; model.mouseOrigin = mouse
        model.selected = wins.count > 1 ? (reverse ? wins.count - 1 : 1) : 0
        shortcut = s; isOpen = true; released = false

        if panel == nil {
            let pn = SwitcherPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            pn.isOpaque = false; pn.backgroundColor = .clear; pn.hasShadow = false
            pn.level = .popUpMenu; pn.hidesOnDeactivate = false
            pn.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            pn.contentView = NSHostingView(rootView: SwitcherView(m: model))
            panel = pn
        }
        panel?.setFrame(screen.frame, display: false)
        // affichage après 120 ms : une frappe rapide change de fenêtre sans voir le sélecteur
        showTask?.cancel()
        let t = DispatchWorkItem { [weak self] in
            guard let self, self.isOpen else { return }
            self.panel?.orderFrontRegardless()
            self.updatePreview()
            if demoThumbs == nil { Task { await Thumbs.shared.refresh(self.model.all.map(\.id), into: self.model) ; self.updatePreview() } }
        }
        showTask = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: t)
    }

    func move(_ d: Int) {
        let n = model.filtered.count
        guard n > 0 else { return }
        model.selected = ((model.selected + d) % n + n) % n
        updatePreview()
    }

    func moveRow(_ d: Int) {
        let n = model.filtered.count, c = model.metrics.cols
        guard n > 0 else { return }
        let t = model.selected + d * c
        if t >= 0, t < n { model.selected = t; updatePreview() }
    }

    func commit() {
        let w = model.current
        close()
        if let w { WinActions.focus(w) }
    }

    func cancel() { close() }

    /// Échap : sort d'abord de la recherche, puis ferme.
    func escape() {
        if model.searching { model.searching = false; model.query = ""; model.clampSelection(); updatePreview() } else { cancel() }
    }

    func quitApp() {
        guard let w = model.current else { return }
        w.app.terminate()
        model.all.removeAll { $0.pid == w.pid }; model.clampSelection(); updatePreview()
    }

    func hideApp() {
        guard let w = model.current else { return }
        if w.app.isHidden { w.app.unhide() } else { w.app.hide() }
        for i in model.all.indices where model.all[i].pid == w.pid { model.all[i].hidden = !w.app.isHidden }
        updatePreview()
    }

    private func close() {
        showTask?.cancel(); swipeCommit?.invalidate()
        isOpen = false; shortcut = nil
        panel?.orderOut(nil); previewPanel?.orderOut(nil)
    }

    func act(_ action: String, _ w: WinInfo) {
        switch action {
        case "close": if WinActions.close(w) { model.remove(w.id) }
        case "min": if WinActions.minimize(w), let i = model.all.firstIndex(where: { $0.id == w.id }) { model.all[i].minimized.toggle() }
        case "full": if WinActions.fullscreen(w) { close() }
        default: break
        }
        updatePreview()
    }

    /// Aperçu de la fenêtre sélectionnée en taille réelle, à sa place.
    func updatePreview() {
        guard isOpen, previewOn, let w = model.current, w.onCurrentSpace, !w.minimized, !w.hidden,
              let img = model.thumbs[w.id] ?? Thumbs.shared.cache[w.id],
              let primaryH = NSScreen.screens.first?.frame.height else { previewPanel?.orderOut(nil); return }
        let r = NSRect(x: w.frame.minX, y: primaryH - w.frame.maxY, width: w.frame.width, height: w.frame.height)
        if previewPanel == nil {
            let pn = NSPanel(contentRect: r, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            pn.isOpaque = false; pn.backgroundColor = .clear; pn.hasShadow = false
            pn.level = .statusBar; pn.ignoresMouseEvents = true
            pn.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            let v = NSImageView(frame: NSRect(origin: .zero, size: r.size))
            v.imageScaling = .scaleAxesIndependently; v.wantsLayer = true
            v.layer?.borderWidth = 2; v.layer?.borderColor = NSColor(srgbRed: 0.22, green: 0.74, blue: 0.97, alpha: 1).cgColor
            v.autoresizingMask = [.width, .height]
            pn.contentView = v
            previewPanel = pn; previewView = v
        }
        previewView?.image = img
        previewPanel?.setFrame(r, display: true)
        previewPanel?.orderFrontRegardless()
        panel?.orderFrontRegardless() // le sélecteur reste au-dessus de l'aperçu
    }

    /// Balayage à trois doigts : fait défiler les fenêtres et valide 0,8 s après le dernier geste.
    func swipe(_ dx: CGFloat) {
        if !isOpen, let s = Prefs.shared.d.shortcuts.first { open(s, reverse: false); model.selected = 0 }
        guard isOpen else { return }
        move(dx < 0 ? 1 : -1)
        swipeCommit?.invalidate()
        swipeCommit = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { _ in MainActor.assumeIsolated { Switcher.shared.commit() } }
    }
}
