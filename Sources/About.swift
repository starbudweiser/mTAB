// Fenêtre « À propos » (modèle Socle / mDESK).
import AppKit

@MainActor
enum About {
    private static var window: NSWindow?
    private static let sideMargin: CGFloat = 28
    private static let textWidth: CGFloat = 300

    static func show() {
        if window == nil { window = makeWindow() }
        if let host = NSApp.windows.first(where: { $0 !== window && $0.isVisible && $0.canBecomeMain }), let w = window {
            let f = host.frame
            w.setFrameOrigin(NSPoint(x: f.midX - w.frame.width / 2, y: f.midY - w.frame.height / 2))
        } else { window?.socleCenter() }
        window?.present()
    }

    private static func label(_ text: String, size: CGFloat = 12, bold: Bool = false, secondary: Bool = false) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        let font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        let p = NSMutableParagraphStyle(); p.alignment = .center
        field.attributedStringValue = Brand.colored(NSAttributedString(string: text, attributes: [
            .font: font, .paragraphStyle: p,
            .foregroundColor: secondary ? NSColor.secondaryLabelColor : NSColor.labelColor]))
        field.alignment = .center
        field.preferredMaxLayoutWidth = textWidth
        field.isSelectable = false
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(lessThanOrEqualToConstant: textWidth).isActive = true
        return field
    }

    private static func makeWindow() -> NSWindow {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 84).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 84).isActive = true
        let views: [NSView] = [
            icon,
            label(Brand.name, size: 17, bold: true),
            label(L("about.version", version, build), secondary: true),
            label(L("about.tagline")),
            label(L("about.authors"), bold: true),
            label(L("about.license")),
            label(L("about.disclaimer"), secondary: true),
            label(L("about.credit"), secondary: true),
        ]
        let stack = NSStackView(views: views)
        stack.orientation = .vertical; stack.alignment = .centerX; stack.spacing = 12
        stack.setCustomSpacing(6, after: views[1]); stack.setCustomSpacing(18, after: views[2])
        stack.edgeInsets = NSEdgeInsets(top: 28, left: sideMargin, bottom: 28, right: sideMargin)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: textWidth + 2 * sideMargin).isActive = true
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = L("about.menu")
        window.isReleasedWhenClosed = false
        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor), stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor), stack.bottomAnchor.constraint(equalTo: content.bottomAnchor)])
        window.contentView = content
        content.layoutSubtreeIfNeeded(); content.layoutSubtreeIfNeeded()
        window.setContentSize(content.fittingSize)
        return window
    }
}
