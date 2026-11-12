// Vue du sélecteur (Socle : aplats, filets 1 px, aucune ombre ni flou).
import SwiftUI

struct SwitcherView: View {
    @ObservedObject var m: SwitcherModel

    var body: some View {
        let f = m.filtered
        let mt = m.metrics
        ZStack {
            Color.clear.contentShape(Rectangle()).onTapGesture { Switcher.shared.cancel() }
            VStack(spacing: Socle.M.space3) {
                if m.searchEnabled { searchBar }
                if f.isEmpty {
                    Text(L(m.query.isEmpty ? "sw.empty" : "sw.noMatch")).socle(Socle.T.bodyLg)
                        .foregroundStyle(Socle.C.textMuted).frame(width: 260, height: 80)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            grid(f, mt).frame(width: mt.totalW)
                        }
                        .frame(width: mt.totalW, height: min(mt.totalH, mt.availH))
                        .onChange(of: m.selected) { _, s in if f.indices.contains(s) { proxy.scrollTo(f[s].id) } }
                    }
                    if m.style == .icons, let w = m.current {
                        VStack(spacing: 4) {
                            Text(w.label).socle(Socle.T.title).foregroundStyle(Socle.C.textStrong).lineLimit(1)
                            Text(w.appName).socle(Socle.T.meta).foregroundStyle(Socle.C.textMuted)
                        }.frame(width: mt.totalW)
                    }
                }
            }
            .padding(Socle.M.space6)
            .background(Socle.C.bg, in: RoundedRectangle(cornerRadius: Socle.M.radiusXl))
            .overlay(RoundedRectangle(cornerRadius: Socle.M.radiusXl).stroke(Socle.C.border, lineWidth: 1))
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Socle.C.textSubtle)
            Text(m.searching ? (m.query.isEmpty ? L("sw.search.type") : m.query + "▏") : L("sw.search.hint", KeyNames.name(Prefs.shared.d.keys.search)))
                .socle(Socle.T.bodyLg)
                .foregroundStyle(m.searching && !m.query.isEmpty ? Socle.C.accentText : Socle.C.textSubtle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Socle.M.space3).frame(height: Socle.M.sizeControlLg)
        .frame(maxWidth: 420).background(Socle.C.bgSunken)
    }

    @ViewBuilder private func grid(_ f: [WinInfo], _ mt: Metrics) -> some View {
        let cols = Array(repeating: GridItem(.fixed(mt.cellW), spacing: mt.gap), count: mt.cols)
        LazyVGrid(columns: cols, spacing: mt.gap) {
            ForEach(Array(f.enumerated()), id: \.element.id) { i, w in
                Group {
                    switch m.style {
                    case .thumbs: ThumbCell(m: m, w: w, index: i, size: mt)
                    case .icons: IconCell(m: m, w: w, index: i, size: mt)
                    case .titles: TitleRow(m: m, w: w, index: i, size: mt)
                    }
                }
                .id(w.id)
            }
        }
    }
}

/// Sélection au survol seulement si la souris a vraiment bougé depuis l'ouverture.
@MainActor private func hoverSelect(_ m: SwitcherModel, _ i: Int, _ inside: Bool) {
    guard inside else { return }
    let p = NSEvent.mouseLocation
    if abs(p.x - m.mouseOrigin.x) + abs(p.y - m.mouseOrigin.y) > 3 { m.selected = i }
}

struct Badges: View {
    let w: WinInfo
    @ObservedObject var m: SwitcherModel
    var body: some View {
        HStack(spacing: 4) {
            if w.minimized { pill(L("badge.min"), Socle.C.textMuted) }
            if w.hidden { pill(L("badge.hidden"), Socle.C.textMuted) }
            if w.fullscreen { pill(L("badge.full"), Socle.C.textMuted) }
            if !w.onCurrentSpace { pill(w.spaceNumber.map { L("badge.space", $0) } ?? "Space", Socle.C.accentText) }
        }
    }
    private func pill(_ t: String, _ c: Color) -> some View {
        Text(t).socle(Socle.T.caption).foregroundStyle(c).padding(.horizontal, 5).padding(.vertical, 2)
            .background(Socle.C.control, in: RoundedRectangle(cornerRadius: 3))
    }
}

struct HoverActions: View {
    let w: WinInfo
    var body: some View {
        HStack(spacing: 4) {
            btn("xmark", "act.close", "close")
            btn("minus", "act.minimize", "min")
            btn("arrow.up.left.and.arrow.down.right", "act.fullscreen", "full")
        }
    }
    private func btn(_ icon: String, _ label: String, _ act: String) -> some View {
        Button { Switcher.shared.act(act, w) } label: {
            Image(systemName: icon).font(.system(size: 9, weight: .bold)).frame(width: 20, height: 20)
                .background(Socle.C.controlStrong, in: RoundedRectangle(cornerRadius: Socle.M.radius))
                .foregroundStyle(Socle.C.textStrong)
        }
        .buttonStyle(.plain).disabled(w.ax == nil).opacity(w.ax == nil ? 0.4 : 1)
        .accessibilityLabel(L(label))
    }
}

struct ThumbCell: View {
    @ObservedObject var m: SwitcherModel
    let w: WinInfo; let index: Int; let size: Metrics
    @State private var hover = false
    var body: some View {
        let sel = index == m.selected
        let inner = size.cellW - 24
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(nsImage: w.icon).resizable().frame(width: 24, height: 24)
                Text(w.label).socle(Socle.T.title).lineLimit(1).foregroundStyle(sel ? Socle.C.textStrong : Socle.C.text)
                Spacer(minLength: 0)
                if hover { HoverActions(w: w) }
            }.frame(height: 28)
            ZStack {
                Socle.C.bgSunken
                if let img = m.thumbs[w.id] {
                    Image(nsImage: img).resizable().scaledToFit()
                } else {
                    Image(nsImage: w.icon).resizable().scaledToFit().frame(width: min(88, inner * 0.4))
                }
                VStack { Spacer(); HStack { Badges(w: w, m: m); Spacer() } }.padding(6)
            }
            .frame(width: inner, height: inner * 0.625)
            .clipShape(RoundedRectangle(cornerRadius: Socle.M.radiusLg))
        }
        .padding(12)
        .frame(width: size.cellW, height: size.cellH, alignment: .top)
        .background(sel ? Socle.C.surfaceSelected : (hover ? Socle.C.surfaceHover : Color.clear), in: RoundedRectangle(cornerRadius: Socle.M.radiusLg + 4))
        .overlay(RoundedRectangle(cornerRadius: Socle.M.radiusLg + 4).stroke(sel ? Socle.C.accent : Color.clear, lineWidth: 2))
        .contentShape(Rectangle())
        .onHover { hover = $0; hoverSelect(m, index, $0) }
        .onTapGesture { m.selected = index; Switcher.shared.commit() }
        .accessibilityElement(children: .combine).accessibilityLabel("\(w.appName), \(w.label)")
        .accessibilityAddTraits(.isButton)
    }
}

struct IconCell: View {
    @ObservedObject var m: SwitcherModel
    let w: WinInfo; let index: Int; let size: Metrics
    @State private var hover = false
    var body: some View {
        let sel = index == m.selected
        ZStack(alignment: .topTrailing) {
            Image(nsImage: w.icon).resizable().scaledToFit().padding(size.cellW * 0.12)
                .frame(width: size.cellW, height: size.cellH)
                .opacity(w.minimized || w.hidden ? 0.55 : 1)
            if hover { HoverActions(w: w).padding(4) }
            if !w.onCurrentSpace { VStack { Spacer(); Badges(w: w, m: m) }.frame(width: size.cellW, height: size.cellH).padding(.bottom, 4) }
        }
        .background(sel ? Socle.C.surfaceSelected : (hover ? Socle.C.surfaceHover : Color.clear), in: RoundedRectangle(cornerRadius: Socle.M.radius))
        .overlay(RoundedRectangle(cornerRadius: Socle.M.radius).stroke(sel ? Socle.C.accent : Color.clear, lineWidth: 2))
        .contentShape(Rectangle())
        .onHover { hover = $0; hoverSelect(m, index, $0) }
        .onTapGesture { m.selected = index; Switcher.shared.commit() }
        .accessibilityElement(children: .combine).accessibilityLabel("\(w.appName), \(w.label)")
        .accessibilityAddTraits(.isButton)
    }
}

struct TitleRow: View {
    @ObservedObject var m: SwitcherModel
    let w: WinInfo; let index: Int; let size: Metrics
    @State private var hover = false
    var body: some View {
        let sel = index == m.selected
        HStack(spacing: 10) {
            Image(nsImage: w.icon).resizable().frame(width: 24, height: 24)
            Text(w.label).socle(Socle.T.bodyLg).lineLimit(1).foregroundStyle(sel ? Socle.C.textStrong : Socle.C.text)
            Text(w.appName).socle(Socle.T.meta).foregroundStyle(Socle.C.textSubtle).lineLimit(1)
            Spacer(minLength: 8)
            Badges(w: w, m: m)
            if hover { HoverActions(w: w) }
        }
        .padding(.horizontal, 10)
        .frame(width: size.cellW, height: size.cellH)
        .background(sel ? Socle.C.surfaceSelected : (hover ? Socle.C.surfaceHover : Color.clear), in: RoundedRectangle(cornerRadius: Socle.M.radius))
        .overlay(RoundedRectangle(cornerRadius: Socle.M.radius).stroke(sel ? Socle.C.accent : Color.clear, lineWidth: 2))
        .contentShape(Rectangle())
        .onHover { hover = $0; hoverSelect(m, index, $0) }
        .onTapGesture { m.selected = index; Switcher.shared.commit() }
        .accessibilityElement(children: .combine).accessibilityLabel("\(w.appName), \(w.label)")
        .accessibilityAddTraits(.isButton)
    }
}
