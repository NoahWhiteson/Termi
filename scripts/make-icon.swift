import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let representation = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
    let bounds = NSRect(x: 48, y: 48, width: 928, height: 928)
    let shape = NSBezierPath(roundedRect: bounds, xRadius: 218, yRadius: 218)
    let shadow = NSShadow(); shadow.shadowColor = .black.withAlphaComponent(0.3); shadow.shadowBlurRadius = 28; shadow.shadowOffset = NSSize(width: 0, height: -12); shadow.set()
    NSGradient(starting: NSColor(srgbRed: 0.31, green: 0.30, blue: 0.28, alpha: 1), ending: NSColor(srgbRed: 0.12, green: 0.12, blue: 0.11, alpha: 1))!.draw(in: shape, angle: -90)
    NSShadow().set()
    NSColor.white.withAlphaComponent(0.12).setStroke(); shape.lineWidth = 3; shape.stroke()
    let path = NSBezierPath(); path.lineWidth = 50; path.lineCapStyle = .round; path.lineJoinStyle = .round
    path.move(to: NSPoint(x: 278, y: 651)); path.line(to: NSPoint(x: 445, y: 512)); path.line(to: NSPoint(x: 278, y: 373))
    NSColor(srgbRed: 0.90, green: 0.89, blue: 0.86, alpha: 1).setStroke(); path.stroke()
    let underline = NSBezierPath(); underline.lineWidth = 45; underline.lineCapStyle = .round
    underline.move(to: NSPoint(x: 534, y: 373)); underline.line(to: NSPoint(x: 720, y: 373)); underline.stroke()
    NSGraphicsContext.restoreGraphicsState()
    let data = representation.representation(using: .png, properties: [:])!
    let names: [Int: [String]] = [16: ["icon_16x16"], 32: ["icon_16x16@2x", "icon_32x32"], 64: ["icon_32x32@2x"], 128: ["icon_128x128"], 256: ["icon_128x128@2x", "icon_256x256"], 512: ["icon_256x256@2x", "icon_512x512"], 1024: ["icon_512x512@2x"]]
    for name in names[size]! { try data.write(to: directory.appendingPathComponent(name + ".png")) }
}
