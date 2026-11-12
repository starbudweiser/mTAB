import AppKit
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let bg = NSBezierPath(roundedRect: NSRect(x: 40, y: 40, width: 944, height: 944), xRadius: 210, yRadius: 210)
NSColor(srgbRed: 0.118, green: 0.118, blue: 0.118, alpha: 1).setFill(); bg.fill()
let cyan = NSColor(srgbRed: 0.22, green: 0.74, blue: 0.97, alpha: 1)
func win(_ r: NSRect, _ c: NSColor, fill: Bool) {
    let p = NSBezierPath(roundedRect: r, xRadius: 48, yRadius: 48)
    if fill { NSColor(srgbRed: 0.118, green: 0.118, blue: 0.118, alpha: 1).setFill(); p.fill() }
    p.lineWidth = 44; c.setStroke(); p.stroke()
    let bar = NSBezierPath(); bar.move(to: NSPoint(x: r.minX + 24, y: r.maxY - 90)); bar.line(to: NSPoint(x: r.maxX - 24, y: r.maxY - 90))
    bar.lineWidth = 36; c.setStroke(); bar.stroke()
}
win(NSRect(x: 190, y: 330, width: 500, height: 400), NSColor(white: 0.55, alpha: 1), fill: false)
win(NSRect(x: 330, y: 260, width: 500, height: 400), cyan, fill: true)
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
