// Fenêtre de réglages : barre latérale (Apparence, Contrôles, Général, Exceptions) et modules Socle.
import AppKit
import ServiceManagement
import SwiftUI

// MARK: Composants Socle

struct SocleCheck: View {
    let label: String
    @Binding var on: Bool
    var body: some View {
        Button { on.toggle() } label: {
            HStack(alignment: .top, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3).fill(on ? Socle.C.accent : Color.clear)
                    RoundedRectangle(cornerRadius: 3).stroke(on ? Socle.C.accent : Socle.C.borderControl, lineWidth: 1.5)
                    if on { Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(Socle.C.onAccent) }
                }.frame(width: Socle.M.sizeChoice, height: Socle.M.sizeChoice)
                Text(label).socle(Socle.T.body).foregroundStyle(Socle.C.text).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(.isToggle)
    }
}

struct Card<Content: View>: View {
    let title: String; var sub: String? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: Socle.M.space3) {
            Text(title).socle(Socle.T.heading).foregroundStyle(Socle.C.textStrong)
            if let sub { Text(sub).socle(Socle.T.body).foregroundStyle(Socle.C.accentText).fixedSize(horizontal: false, vertical: true) }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Socle.M.space6)
        .background(Socle.C.surface, in: RoundedRectangle(cornerRadius: Socle.M.radiusLg))
        .socleModule()
    }
}

struct Field<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).socle(Socle.T.label).foregroundStyle(Socle.C.textMuted)
            content
        }
    }
}

/// Motif de l'icône (deux fenêtres), pour le filigrane de la barre latérale.
struct IconMotif: View {
    var body: some View {
        GeometryReader { g in
            let s = g.size.width
            ZStack {
                RoundedRectangle(cornerRadius: s * 0.05).stroke(lineWidth: s * 0.04).frame(width: s * 0.5, height: s * 0.4).offset(x: -s * 0.14, y: -s * 0.07)
                RoundedRectangle(cornerRadius: s * 0.05).stroke(lineWidth: s * 0.04).frame(width: s * 0.5, height: s * 0.4).offset(x: s * 0.1, y: s * 0.07)
            }.frame(width: s, height: s)
        }
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case look, controls, general, exceptions
    var id: String { rawValue }
    var icon: String { ["look": "paintpalette", "controls": "command", "general": "gearshape", "exceptions": "hand.raised"][rawValue]! }
    var title: String { L("tab.\(rawValue)") }
}

// MARK: Fenêtre

struct SettingsView: View {
    @ObservedObject var prefs = Prefs.shared
    @State private var tab: SettingsTab = .look
    @State private var ax = AXIsProcessTrusted()
    @State private var sc = CGPreflightScreenCaptureAccess()
    @State private var service = Service.isInstalled
    @State private var login = SMAppService.mainApp.status == .enabled
    @State private var recording: UUID?
    @State private var recordMsg = ""
    @State private var cliMsg = ""
    @State private var monitor: Any?
    private let poll = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                HStack {
                    Text(tab.title).socle(Socle.T.display).foregroundStyle(Socle.C.textStrong)
                    Spacer()
                }
                .padding(.horizontal, 28).frame(height: Socle.M.sizeBar + 12).background(Socle.C.surfaceRaised)
                ScrollView {
                    Group {
                        if tab == .look { lookLayout } else { SocleModuleGrid(minimum: 440) { content } }
                    }.padding(28)
                }
            }
        }
        .background(Socle.C.bg)
        .onReceive(poll) { _ in ax = AXIsProcessTrusted(); sc = CGPreflightScreenCaptureAccess() }
        .onDisappear { stopRecording() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 32, height: 32)
                Text(branded: "mTAB").socle(Socle.T.heading).foregroundStyle(Socle.C.textStrong)
            }.padding(.bottom, Socle.M.space4).padding(.top, Socle.M.space2)
            ForEach(SettingsTab.allCases) { t in
                Button { tab = t } label: {
                    HStack(spacing: 10) {
                        Image(systemName: t.icon).frame(width: 20)
                        Text(t.title).socle(Socle.T.label)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(tab == t ? Socle.C.accentText : Socle.C.text)
                    .padding(.horizontal, Socle.M.space3).frame(height: Socle.M.sizeControlLg)
                    .background(tab == t ? Socle.C.surfaceSelected : Color.clear, in: RoundedRectangle(cornerRadius: Socle.M.radius))
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(Socle.M.space3)
        .frame(width: 220)
        .frame(maxHeight: .infinity)
        .socleWatermark { IconMotif() }
        .background(Socle.C.surfaceRaised)
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .look: EmptyView()
        case .controls: controlsCards
        case .general: generalCards
        case .exceptions: exceptionsCards
        }
    }

    // MARK: Apparence
    private var lookLayout: some View {
        VStack(spacing: Socle.M.space4) {
            Card(title: L("style"), sub: L("sec.look.sub")) {
                HStack(spacing: Socle.M.space4) {
                    ForEach(Style.allCases, id: \.self) { s in
                        StyleCard(style: s, selected: prefs.d.style == s) { prefs.d.style = s }
                    }
                }
            }
            HStack(alignment: .top, spacing: Socle.M.space4) {
                Card(title: L("card.display")) {
                    Field(label: L("size")) {
                        SocleSegmented(options: SizeChoice.allCases, selection: prefs.d.size, label: { L("size.\($0.rawValue)") }) { prefs.d.size = $0 }
                    }
                    Field(label: L("theme")) {
                        SocleSegmented(options: ThemeChoice.allCases, selection: prefs.d.theme, label: { L("theme.\($0.rawValue)") }) { prefs.d.theme = $0 }
                    }
                    SocleCheck(label: L("look.preview"), on: $prefs.d.preview)
                }
                Card(title: L("sec.behavior")) {
                    Field(label: L("release")) {
                        SocleSegmented(options: ReleaseMode.allCases, selection: prefs.d.release,
                                       label: { $0 == .select ? L("release.switch") : L("release.open") }) { prefs.d.release = $0 }
                    }
                    SocleCheck(label: L("beh.search"), on: $prefs.d.search)
                }
            }
        }
    }

    // MARK: Contrôles
    @ViewBuilder private var controlsCards: some View {
        ForEach(Array(prefs.d.shortcuts.enumerated()), id: \.element.id) { i, s in
            shortcutRow(i, s)
        }
        if prefs.d.shortcuts.count < 9 {
            Card(title: L("sec.shortcuts"), sub: L("sec.shortcuts.sub")) {
                Button(L("sc.add")) { prefs.d.shortcuts.append(Shortcut(mods: 0x80000, key: 49)) }
                    .buttonStyle(SocleButtonStyle(.secondary))
            }
        }
        Card(title: L("card.gesture")) {
            SocleCheck(label: L("beh.swipe"), on: $prefs.d.swipe)
            Text(L("beh.swipe.note")).socle(Socle.T.meta).foregroundStyle(Socle.C.textSubtle)
        }
    }

    private func shortcutRow(_ i: Int, _ s: Shortcut) -> some View {
        let b = $prefs.d.shortcuts[i]
        return Card(title: L("sc.name", i + 1)) {
            HStack {
                Text(recording == s.id ? "…" : s.display).socle(Socle.T.mono).socleValue()
                Spacer()
                Button(recording == s.id ? L("sc.recording") : L("sc.record")) { startRecording(s.id) }
                    .buttonStyle(SocleButtonStyle(.secondary, height: Socle.M.sizeControl)).fixedSize()
                if prefs.d.shortcuts.count > 1 {
                    Button(L("sc.remove")) { prefs.d.shortcuts.removeAll { $0.id == s.id } }
                        .buttonStyle(SocleButtonStyle(.tertiary, height: Socle.M.sizeControl)).fixedSize()
                }
            }
            if recording == s.id, !recordMsg.isEmpty {
                Text(recordMsg).socle(Socle.T.meta).foregroundStyle(Socle.C.warning)
            }
            filter(L("f.apps"), s.apps, [.all, .active], { $0 == .all ? L("f.apps.all") : L("f.apps.active") }) { b.apps.wrappedValue = $0 }
            filter(L("f.spaces"), s.spaces, [.all, .current], { $0 == .all ? L("f.spaces.all") : L("f.spaces.current") }) { b.spaces.wrappedValue = $0 }
            filter(L("f.screens"), s.screens, [.all, .current], { $0 == .all ? L("f.screens.all") : L("f.screens.current") }) { b.screens.wrappedValue = $0 }
            filter(L("f.min"), s.minimized, [.show, .hide], { $0 == .show ? L("f.show") : L("f.hide") }) { b.minimized.wrappedValue = $0 }
            filter(L("f.hid"), s.hidden, [.show, .hide], { $0 == .show ? L("f.show") : L("f.hide") }) { b.hidden.wrappedValue = $0 }
        }
    }

    private func filter<V: Hashable>(_ label: String, _ value: V, _ options: [V], _ name: @escaping (V) -> String, _ set: @escaping (V) -> Void) -> some View {
        HStack {
            Text(label).socle(Socle.T.body).foregroundStyle(Socle.C.textMuted).frame(width: 150, alignment: .leading)
            SocleSegmented(options: options, selection: value, label: name, onSelect: set)
            Spacer(minLength: 0)
        }
    }

    private func startRecording(_ id: UUID) {
        stopRecording()
        recording = id; recordMsg = ""
        Hotkeys.shared.paused = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            let key = Int(e.keyCode)
            if key == 53 { stopRecording(); return nil }
            var mods: UInt64 = 0
            if e.modifierFlags.contains(.control) { mods |= 0x40000 }
            if e.modifierFlags.contains(.option) { mods |= 0x80000 }
            if e.modifierFlags.contains(.shift) { mods |= 0x20000 }
            if e.modifierFlags.contains(.command) { mods |= 0x100000 }
            if mods & (0x40000 | 0x80000 | 0x100000) == 0 { recordMsg = L("sc.needMod"); return nil }
            if let i = prefs.d.shortcuts.firstIndex(where: { $0.id == id }) { prefs.d.shortcuts[i].mods = mods; prefs.d.shortcuts[i].key = key }
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        recording = nil; recordMsg = ""
        Hotkeys.shared.paused = false
    }

    // MARK: Général
    @ViewBuilder private var generalCards: some View {
        Card(title: L("card.start")) {
            SocleCheck(label: L("beh.login"), on: Binding(get: { login }, set: { v in
                do { if v { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } } catch {}
                login = SMAppService.mainApp.status == .enabled
            })).disabled(service).opacity(service ? 0.5 : 1)
            SocleCheck(label: L("beh.service"), on: Binding(get: { service }, set: { v in
                service = v
                if v, login { try? SMAppService.mainApp.unregister(); login = false } // évite un double lancement
                Service.set(v)
            }))
            Text(L("beh.service.note")).socle(Socle.T.meta).foregroundStyle(Socle.C.textSubtle)
            Field(label: L("presence")) {
                SocleSegmented(options: IconMode.allCases, selection: prefs.d.presence, label: { L("presence.\($0.rawValue)") }) { prefs.d.presence = $0 }
            }
        }
        Card(title: L("sec.perm"), sub: L("sec.perm.sub")) {
            permRow(L("perm.ax"), L("perm.ax.why"), ax) {
                AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
                open("Privacy_Accessibility")
            }
            permRow(L("perm.sc"), L("perm.sc.why"), sc) { CGRequestScreenCaptureAccess(); open("Privacy_ScreenCapture") }
        }
        Card(title: L("upd.title")) { UpdateSection() }
        Card(title: L("sec.cli"), sub: L("sec.cli.sub")) {
            Text("mtab --list\nmtab --focus <id>").socle(Socle.T.mono).socleValue()
                .padding(Socle.M.space3).frame(maxWidth: .infinity, alignment: .leading).background(Socle.C.bgSunken)
            Button(L("cli.copy")) {
                let cmd = "sudo ln -sf \"\(Bundle.main.executablePath ?? "")\" /usr/local/bin/mtab"
                NSPasteboard.general.clearContents(); NSPasteboard.general.setString(cmd, forType: .string)
                cliMsg = L("cli.copied")
            }.buttonStyle(SocleButtonStyle(.secondary))
            if !cliMsg.isEmpty { Text(cliMsg).socle(Socle.T.meta).foregroundStyle(Socle.C.textMuted) }
        }
    }

    private func open(_ pane: String) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!)
    }

    private func permRow(_ name: String, _ why: String, _ ok: Bool, _ action: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).socle(Socle.T.title).foregroundStyle(Socle.C.textStrong)
                Text(why).socle(Socle.T.meta).foregroundStyle(Socle.C.textMuted)
            }
            Spacer()
            if ok {
                Text("✓ " + L("perm.ok")).socle(Socle.T.label).foregroundStyle(Socle.C.success)
            } else {
                Text("! " + L("perm.missing")).socle(Socle.T.label).foregroundStyle(Socle.C.warning)
                Button(L("perm.open"), action: action).buttonStyle(SocleButtonStyle(.primary, height: Socle.M.sizeControl)).fixedSize()
            }
        }
    }

    // MARK: Exceptions
    @ViewBuilder private var exceptionsCards: some View {
        Card(title: L("sec.ex"), sub: L("sec.ex.sub")) {
            if prefs.d.exceptions.isEmpty { Text(L("ex.none")).socle(Socle.T.body).foregroundStyle(Socle.C.textMuted) }
            Button(L("ex.add")) { pickApp() }.buttonStyle(SocleButtonStyle(.secondary))
        }
        ForEach(Array(prefs.d.exceptions.enumerated()), id: \.element.id) { i, ex in
            exceptionRow(i, ex)
        }
    }

    private func exceptionRow(_ i: Int, _ ex: AppException) -> some View {
        let b = $prefs.d.exceptions[i]
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: ex.bundleId)
        let name = url.map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") } ?? ex.bundleId
        return Card(title: name) {
            HStack(spacing: 10) {
                if let url { Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 24, height: 24) }
                Text(ex.bundleId).socle(Socle.T.monoSm).foregroundStyle(Socle.C.textSubtle).lineLimit(1).truncationMode(.middle)
                Spacer()
                Button(L("sc.remove")) { prefs.d.exceptions.removeAll { $0.bundleId == ex.bundleId } }
                    .buttonStyle(SocleButtonStyle(.tertiary, height: Socle.M.sizeControl)).fixedSize()
            }
            filter(L("ex.hide"), ex.hide, HideMode.allCases, { $0 == .never ? L("ex.never") : L("ex.always") }) { b.hide.wrappedValue = $0 }
            filter(L("ex.ignore"), ex.ignore, IgnoreMode.allCases, { $0 == .never ? L("ex.keep") : L("ex.whenFront") }) { b.ignore.wrappedValue = $0 }
        }
    }

    private func pickApp() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.application]; p.allowsMultipleSelection = false
        p.directoryURL = URL(fileURLWithPath: "/Applications")
        if p.runModal() == .OK, let url = p.url, let id = Bundle(url: url)?.bundleIdentifier, !prefs.d.exceptions.contains(where: { $0.bundleId == id }) {
            prefs.d.exceptions.append(AppException(bundleId: id, hide: .always))
        }
    }
}

/// Carte de style : aperçu schématique, filet d'accent quand elle est choisie.
struct StyleCard: View {
    let style: Style; let selected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Socle.C.bgSunken
                    preview
                }
                .frame(height: 124).clipShape(RoundedRectangle(cornerRadius: Socle.M.radius))
                .overlay(RoundedRectangle(cornerRadius: Socle.M.radius).stroke(selected ? Socle.C.accent : Socle.C.border, lineWidth: selected ? 2 : 1))
                Text(L("style.\(style.rawValue)")).socle(Socle.T.label).foregroundStyle(selected ? Socle.C.accentText : Socle.C.textMuted)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).frame(maxWidth: .infinity)
    }

    @ViewBuilder private var preview: some View {
        switch style {
        case .thumbs:
            HStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { i in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(Socle.C.textMuted).frame(height: 5)
                        RoundedRectangle(cornerRadius: 3).fill(i == 0 ? Socle.C.accentFill : Socle.C.controlStrong).frame(height: 38)
                    }.padding(6).background(i == 0 ? Socle.C.surfaceSelected : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                }
            }.padding(.horizontal, 12)
        case .icons:
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 6).fill(i == 1 ? Socle.C.accentFill : Socle.C.controlStrong).frame(width: 28, height: 28)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(i == 1 ? Socle.C.accent : Color.clear, lineWidth: 2))
                }
            }
        case .titles:
            VStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2).fill(Socle.C.controlStrong).frame(width: 8, height: 8)
                        RoundedRectangle(cornerRadius: 2).fill(i == 1 ? Socle.C.textStrong : Socle.C.textMuted).frame(height: 4)
                    }.padding(.horizontal, 6).frame(height: 16)
                    .background(i == 1 ? Socle.C.surfaceSelected : Color.clear, in: RoundedRectangle(cornerRadius: 3))
                }
            }.padding(.horizontal, 14)
        }
    }
}

@MainActor
enum SettingsWindow {
    private static var window: NSWindow?
    static func show() {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView())
            let w = NSWindow(contentViewController: host)
            w.title = L("set.title"); w.styleMask = [.titled, .closable, .resizable]
            w.setContentSize(NSSize(width: 1100, height: 580)); w.minSize = NSSize(width: 760, height: 520)
            w.isReleasedWhenClosed = false
            window = w
        }
        window?.socleCenter()
        if CommandLine.arguments.contains("--silent") { window?.orderFront(nil) } else { window?.present() }
    }
}
