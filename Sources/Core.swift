// Fenêtres : énumération (toutes les fenêtres, y compris réduites, masquées et sur d'autres Spaces) et actions.
import AppKit
import ApplicationServices
import CoreGraphics
import ScreenCaptureKit

// API privées de macOS (celles qu'utilisent aussi les sélecteurs de fenêtres existants)
@_silgen_name("_AXUIElementGetWindow") func _AXUIElementGetWindow(_ el: AXUIElement, _ wid: UnsafeMutablePointer<CGWindowID>) -> AXError
@_silgen_name("CGSMainConnectionID") func CGSMainConnectionID() -> Int32
@_silgen_name("CGSGetActiveSpace") func CGSGetActiveSpace(_ cid: Int32) -> Int
@_silgen_name("CGSCopySpacesForWindows") func CGSCopySpacesForWindows(_ cid: Int32, _ mask: Int32, _ wids: CFArray) -> Unmanaged<CFArray>?
@_silgen_name("CGSCopyManagedDisplaySpaces") func CGSCopyManagedDisplaySpaces(_ cid: Int32) -> Unmanaged<CFArray>?
@_silgen_name("CGSSetSymbolicHotKeyEnabled") func CGSSetSymbolicHotKeyEnabled(_ key: Int32, _ enabled: Bool) -> CGError
@_silgen_name("GetProcessForPID") func GetProcessForPID(_ pid: pid_t, _ psn: UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus
@_silgen_name("_SLPSSetFrontProcessWithOptions") func _SLPSSetFrontProcessWithOptions(_ psn: UnsafeMutablePointer<ProcessSerialNumber>, _ wid: CGWindowID, _ mode: UInt32) -> CGError
@_silgen_name("SLPSPostEventRecordTo") func SLPSPostEventRecordTo(_ psn: UnsafeMutablePointer<ProcessSerialNumber>, _ bytes: UnsafeMutablePointer<UInt8>) -> CGError

struct WinInfo: Identifiable {
    let id: CGWindowID
    let pid: pid_t
    let app: NSRunningApplication
    var appName: String
    var title: String
    var frame: CGRect          // coordonnées CoreGraphics (origine en haut à gauche de l'écran principal)
    var ax: AXUIElement?
    var minimized = false
    var hidden = false
    var fullscreen = false
    var spaceNumber: Int?      // numéro du Space (nil : Space plein écran ou inconnu)
    var onCurrentSpace = true
    var iconOverride: NSImage?   // démonstration : icône fictive
    var icon: NSImage { iconOverride ?? app.icon ?? NSImage(size: NSSize(width: 32, height: 32)) }
    var label: String { title.isEmpty ? appName : title }
}

func axGet<T>(_ el: AXUIElement, _ attr: String) -> T? {
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(el, attr as CFString, &v) == .success else { return nil }
    return v as? T
}

enum WindowList {
    /// Fenêtres selon les filtres d'un raccourci, dans l'ordre d'utilisation (la plus récente d'abord).
    @MainActor static func fetch(_ s: Shortcut?) -> [WinInfo] {
        let prefs = Prefs.shared.d
        let cid = CGSMainConnectionID()
        let active = CGSGetActiveSpace(cid)
        let spaceIndex = userSpaceIndex(cid)
        let myPid = ProcessInfo.processInfo.processIdentifier
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let primaryH = NSScreen.screens.first?.frame.height ?? 0
        let mouse = NSEvent.mouseLocation
        let mouseScreen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }

        guard let cg = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else { return [] }
        var apps: [pid_t: NSRunningApplication] = [:]
        for a in NSWorkspace.shared.runningApplications where a.activationPolicy == .regular { apps[a.processIdentifier] = a }

        // fenêtres connues d'Accessibilité, par app
        var axByPid: [pid_t: [CGWindowID: AXUIElement]] = [:]
        func axWindows(_ pid: pid_t) -> [CGWindowID: AXUIElement] {
            if let c = axByPid[pid] { return c }
            let el = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(el, 0.25)
            var map: [CGWindowID: AXUIElement] = [:]
            for w in axGet(el, kAXWindowsAttribute) as [AXUIElement]? ?? [] {
                var wid: CGWindowID = 0
                if _AXUIElementGetWindow(w, &wid) == .success, wid != 0 { map[wid] = w }
            }
            axByPid[pid] = map
            return map
        }

        var out: [WinInfo] = []
        for d in cg {
            guard (d[kCGWindowLayer as String] as? Int) == 0,
                  let pid = d[kCGWindowOwnerPID as String] as? pid_t, pid != myPid,
                  let app = apps[pid], let wid = d[kCGWindowNumber as String] as? CGWindowID,
                  let bd = d[kCGWindowBounds as String] as? [String: CGFloat],
                  let w = bd["Width"], let h = bd["Height"], w >= 60, h >= 40 else { continue }
            if let ex = prefs.exceptions.first(where: { $0.bundleId == app.bundleIdentifier }), ex.hide == .always { continue }
            let frame = CGRect(x: bd["X"] ?? 0, y: bd["Y"] ?? 0, width: w, height: h)
            let onscreen = (d[kCGWindowIsOnscreen as String] as? Bool) ?? false
            let spaces = (CGSCopySpacesForWindows(cid, 0x7, [wid] as CFArray)?.takeRetainedValue() as? [Int]) ?? []
            let onCurrent = spaces.isEmpty || spaces.contains(active)

            var info = WinInfo(id: wid, pid: pid, app: app, appName: app.localizedName ?? "?",
                               title: (d[kCGWindowName as String] as? String) ?? "", frame: frame)
            info.hidden = app.isHidden
            info.onCurrentSpace = onCurrent
            info.spaceNumber = spaces.compactMap { spaceIndex[$0] }.first
            if let ax = axWindows(pid)[wid] {
                let sub: String? = axGet(ax, kAXSubroleAttribute)
                guard sub == nil || sub == "AXStandardWindow" || sub == "AXDialog" else { continue }
                info.ax = ax
                if let t: String = axGet(ax, kAXTitleAttribute), !t.isEmpty { info.title = t }
                info.minimized = (axGet(ax, kAXMinimizedAttribute) as Bool?) ?? false
                info.fullscreen = (axGet(ax, "AXFullScreen") as Bool?) ?? false
            } else {
                // sans objet Accessibilité : seulement une vraie fenêtre d'un autre Space
                guard !onscreen, !onCurrent, w >= 200, h >= 120 else { continue }
            }
            if let s {
                if s.apps == .active, pid != front { continue }
                if s.spaces == .current, !info.onCurrentSpace { continue }
                if s.screens == .current, let ms = mouseScreen {
                    let c = CGPoint(x: frame.midX, y: primaryH - frame.midY)
                    if !ms.frame.contains(c) { continue }
                }
                if s.minimized == .hide, info.minimized { continue }
                if s.hidden == .hide, info.hidden { continue }
            }
            out.append(info)
        }
        return out
    }

    /// Numéro (à partir de 1) de chaque Space utilisateur, tous écrans confondus.
    private static func userSpaceIndex(_ cid: Int32) -> [Int: Int] {
        var map: [Int: Int] = [:]
        guard let displays = CGSCopyManagedDisplaySpaces(cid)?.takeRetainedValue() as? [[String: Any]] else { return map }
        var n = 0
        for disp in displays {
            for sp in disp["Spaces"] as? [[String: Any]] ?? [] {
                guard (sp["type"] as? Int) == 0, let id = sp["id64"] as? Int else { continue }
                n += 1; map[id] = n
            }
        }
        return map
    }
}

enum WinActions {
    /// Met la fenêtre au premier plan, même sur un autre Space, réduite ou dans une app masquée.
    static func focus(_ w: WinInfo) {
        if w.app.isHidden { w.app.unhide() }
        if w.minimized, let ax = w.ax { AXUIElementSetAttributeValue(ax, kAXMinimizedAttribute as CFString, kCFBooleanFalse) }
        var psn = ProcessSerialNumber()
        if GetProcessForPID(w.pid, &psn) == noErr {
            _ = _SLPSSetFrontProcessWithOptions(&psn, w.id, 0x200)
            var b = [UInt8](repeating: 0, count: 0xf8)
            b[0x04] = 0xf8; b[0x3a] = 0x10
            b[0x3c] = UInt8(w.id & 0xff); b[0x3d] = UInt8((w.id >> 8) & 0xff)
            b[0x3e] = UInt8((w.id >> 16) & 0xff); b[0x3f] = UInt8((w.id >> 24) & 0xff)
            for i in 0x20..<0x30 { b[i] = 0xff }
            b[0x08] = 0x01; _ = SLPSPostEventRecordTo(&psn, &b)
            b[0x08] = 0x02; _ = SLPSPostEventRecordTo(&psn, &b)
        } else {
            w.app.activate(options: [.activateIgnoringOtherApps])
        }
        if let ax = w.ax { AXUIElementPerformAction(ax, kAXRaiseAction as CFString) }
    }

    @discardableResult static func close(_ w: WinInfo) -> Bool {
        guard let ax = w.ax, let b: AXUIElement = axGet(ax, kAXCloseButtonAttribute) else { return false }
        return AXUIElementPerformAction(b, kAXPressAction as CFString) == .success
    }

    @discardableResult static func minimize(_ w: WinInfo) -> Bool {
        guard let ax = w.ax else { return false }
        return AXUIElementSetAttributeValue(ax, kAXMinimizedAttribute as CFString, (!w.minimized) as CFBoolean) == .success
    }

    @discardableResult static func fullscreen(_ w: WinInfo) -> Bool {
        guard let ax = w.ax else { return false }
        return AXUIElementSetAttributeValue(ax, "AXFullScreen" as CFString, (!w.fullscreen) as CFBoolean) == .success
    }
}

/// Aperçus : captures ScreenCaptureKit gardées en cache d'une ouverture à l'autre.
@MainActor
final class Thumbs {
    static let shared = Thumbs()
    private(set) var cache: [CGWindowID: NSImage] = [:]

    func refresh(_ ids: [CGWindowID], into model: SwitcherModel?) async {
        guard CGPreflightScreenCaptureAccess() else { return }
        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false) else { return }
        let byId = Dictionary(content.windows.map { ($0.windowID, $0) }, uniquingKeysWith: { a, _ in a })
        for id in ids {
            guard let w = byId[id], w.frame.width > 1, w.frame.height > 1 else { continue }
            let cfg = SCStreamConfiguration()
            let scale = min(1.0, 900 / w.frame.width)
            cfg.width = max(2, Int(w.frame.width * scale)); cfg.height = max(2, Int(w.frame.height * scale))
            cfg.showsCursor = false
            guard let img = try? await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: w), configuration: cfg) else { continue }
            let ns = NSImage(cgImage: img, size: .zero)
            cache[id] = ns
            model?.thumbs[id] = ns
        }
    }
}
