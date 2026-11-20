// Renders the CleanM app icon (a leaf on a green squircle) and packs it into an .icns file.
// Usage: swift tools/make-icon.swift [output.icns] [preview.png]
import AppKit

let args = CommandLine.arguments
let output = args.count > 1 ? args[1] : "Resources/AppIcon.icns"
let preview = args.count > 2 ? args[2] : "Resources/AppIcon.png"

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let px = Int(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let gc = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gc
    let ctx = gc.cgContext
    let s = size / 1024 // design on a 1024 canvas
    ctx.scaleBy(x: s, y: s)

    // Squircle background (macOS icon grid: 824pt body, centred, ~185pt corner radius).
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0, 0, 0, 0.35))
    ctx.addPath(squircle)
    ctx.setFillColor(color(0.05, 0.25, 0.14))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    let space = CGColorSpaceCreateDeviceRGB()
    let bg = CGGradient(colorsSpace: space,
                        colors: [color(0.10, 0.42, 0.24), color(0.04, 0.20, 0.13)] as CFArray,
                        locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 200, y: 924), end: CGPoint(x: 824, y: 100), options: [])
    // Soft glow behind the leaf.
    let glow = CGGradient(colorsSpace: space,
                          colors: [color(0.75, 0.95, 0.45, 0.45), color(0.75, 0.95, 0.45, 0)] as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 540), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 540), endRadius: 380, options: [])
    ctx.restoreGState()

    // Leaf, tilted 40°, pointing to the upper right.
    ctx.saveGState()
    ctx.translateBy(x: 512, y: 500)
    ctx.rotate(by: -.pi * 40 / 180)

    let leaf = CGMutablePath()
    let tip = CGPoint(x: 0, y: 330)
    let base = CGPoint(x: 0, y: -250)
    leaf.move(to: base)
    leaf.addCurve(to: tip, control1: CGPoint(x: -330, y: -170), control2: CGPoint(x: -170, y: 230))
    leaf.addCurve(to: base, control1: CGPoint(x: 170, y: 230), control2: CGPoint(x: 330, y: -170))
    leaf.closeSubpath()

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0, 0.08, 0.03, 0.45))
    ctx.addPath(leaf)
    ctx.setFillColor(color(0.55, 0.85, 0.40))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(leaf)
    ctx.clip()
    let leafGradient = CGGradient(colorsSpace: space,
                                  colors: [color(0.82, 0.96, 0.50), color(0.36, 0.76, 0.42), color(0.16, 0.56, 0.38)] as CFArray,
                                  locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(leafGradient, start: CGPoint(x: -220, y: 260), end: CGPoint(x: 220, y: -220), options: [])
    ctx.restoreGState()

    // Stem.
    ctx.setLineCap(.round)
    ctx.setStrokeColor(color(0.36, 0.70, 0.36))
    ctx.setLineWidth(22)
    let stem = CGMutablePath()
    stem.move(to: CGPoint(x: 0, y: -240))
    stem.addQuadCurve(to: CGPoint(x: -18, y: -330), control: CGPoint(x: 0, y: -300))
    ctx.addPath(stem)
    ctx.strokePath()

    // Midrib and veins, clipped to the leaf.
    ctx.saveGState()
    ctx.addPath(leaf)
    ctx.clip()
    ctx.setStrokeColor(color(0.95, 1.0, 0.88, 0.85))
    ctx.setLineWidth(16)
    let rib = CGMutablePath()
    rib.move(to: CGPoint(x: 0, y: -250))
    rib.addQuadCurve(to: CGPoint(x: 0, y: 300), control: CGPoint(x: -14, y: 30))
    ctx.addPath(rib)
    ctx.strokePath()

    ctx.setLineWidth(10)
    ctx.setStrokeColor(color(0.95, 1.0, 0.88, 0.55))
    for (y, len) in [(-150.0, 150.0), (-50.0, 150.0), (50.0, 130.0), (140.0, 95.0)] {
        for side in [-1.0, 1.0] {
            let vein = CGMutablePath()
            vein.move(to: CGPoint(x: -4, y: y))
            vein.addQuadCurve(to: CGPoint(x: side * len, y: y + len * 0.7),
                              control: CGPoint(x: side * len * 0.55, y: y + len * 0.12))
            ctx.addPath(vein)
        }
    }
    ctx.strokePath()
    ctx.restoreGState()
    ctx.restoreGState()

    // Subtle top highlight on the squircle.
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    let shine = CGGradient(colorsSpace: space,
                           colors: [color(1, 1, 1, 0.14), color(1, 1, 1, 0)] as CFArray,
                           locations: [0, 1])!
    ctx.drawLinearGradient(shine, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 600), options: [])
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("CleanM-\(UUID().uuidString).iconset")
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let rep = drawIcon(size: CGFloat(base * scale))
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try rep.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
try drawIcon(size: 1024).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: preview))

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", output]
try task.run()
task.waitUntilExit()
try? fm.removeItem(at: iconset)
guard task.terminationStatus == 0 else { fatalError("iconutil failed") }
print("✓ Wrote \(output) and \(preview)")
