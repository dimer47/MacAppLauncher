// Génère Resources/AppIcon.icns : squircle dégradé, grille d'apps et loupe.
import AppKit

func render(_ size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = size / 1024
    let box = NSRect(x: 100*s, y: 100*s, width: 824*s, height: 824*s)
    let shape = NSBezierPath(roundedRect: box, xRadius: 185*s, yRadius: 185*s)

    NSGraphicsContext.current!.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowBlurRadius = 24*s; shadow.shadowOffset = NSSize(width: 0, height: -10*s)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3); shadow.set()
    NSColor.black.setFill(); shape.fill()
    NSGraphicsContext.current!.restoreGraphicsState()

    NSGradient(colors: [NSColor(red: 0.36, green: 0.42, blue: 1.0, alpha: 1),
                        NSColor(red: 0.62, green: 0.30, blue: 0.95, alpha: 1)])!.draw(in: shape, angle: -60)

    // Reflet en haut (effet verre)
    NSGraphicsContext.current!.saveGraphicsState()
    shape.addClip()
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.35), NSColor.white.withAlphaComponent(0)])!
        .draw(in: NSRect(x: box.minX, y: box.midY, width: box.width, height: box.height/2), angle: -90)
    NSGraphicsContext.current!.restoreGraphicsState()
    NSColor.white.withAlphaComponent(0.35).setStroke()
    let rim = NSBezierPath(roundedRect: box.insetBy(dx: 3*s, dy: 3*s), xRadius: 182*s, yRadius: 182*s)
    rim.lineWidth = 4*s; rim.stroke()

    // Grille 3×3 de pastilles (les apps)
    let tile: CGFloat = 120*s, gap: CGFloat = 42*s
    let gx = box.minX + 150*s, gy = box.minY + 255*s
    for r in 0..<3 { for c in 0..<3 {
        let rect = NSRect(x: gx + CGFloat(c)*(tile+gap), y: gy + CGFloat(r)*(tile+gap), width: tile, height: tile)
        NSColor.white.withAlphaComponent(0.88).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 32*s, yRadius: 32*s).fill()
    }}

    // Loupe en bas à droite
    let center = NSPoint(x: box.minX + 560*s, y: box.minY + 330*s)
    let lens = NSBezierPath(ovalIn: NSRect(x: center.x - 125*s, y: center.y - 125*s, width: 250*s, height: 250*s))
    NSColor(red: 0.20, green: 0.18, blue: 0.45, alpha: 0.55).setFill(); lens.fill()
    NSColor.white.setStroke(); lens.lineWidth = 38*s; lens.stroke()
    let handle = NSBezierPath()
    handle.move(to: NSPoint(x: center.x + 95*s, y: center.y - 95*s))
    handle.line(to: NSPoint(x: center.x + 200*s, y: center.y - 200*s))
    handle.lineWidth = 52*s; handle.lineCapStyle = .round; handle.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
for (name, px) in [("16x16",16),("16x16@2x",32),("32x32",32),("32x32@2x",64),("128x128",128),
                   ("128x128@2x",256),("256x256",256),("256x256@2x",512),("512x512",512),("512x512@2x",1024)] {
    try! render(CGFloat(px)).representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
