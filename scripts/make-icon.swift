import AppKit

let size: CGFloat = 1024

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func ear(tip: NSPoint, baseLeft: NSPoint, baseRight: NSPoint, tipRadius: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: (baseLeft.x + baseRight.x) / 2, y: (baseLeft.y + baseRight.y) / 2))
    path.appendArc(from: baseRight, to: tip, radius: 30)
    path.appendArc(from: tip, to: baseLeft, radius: tipRadius)
    path.appendArc(from: baseLeft, to: baseRight, radius: 30)
    path.close()
    return path
}

func mirrored(_ path: NSBezierPath) -> NSBezierPath {
    let copy = path.copy() as! NSBezierPath
    var transform = AffineTransform(translationByX: size, byY: 0)
    transform.scale(x: -1, y: 1)
    copy.transform(using: transform)
    return copy
}

func drawIcon() {
    let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x000000, alpha: 0.18)
    shadow.shadowBlurRadius = 20
    shadow.shadowOffset = NSSize(width: 0, height: -8)
    shadow.set()
    color(0xCDD7FF).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()

    let center = NSPoint(x: 512, y: 470)
    let leftEar = ear(tip: NSPoint(x: 282, y: 870), baseLeft: NSPoint(x: 285, y: 500), baseRight: NSPoint(x: 510, y: 690), tipRadius: 52)
    let leftInner = ear(tip: NSPoint(x: 306, y: 800), baseLeft: NSPoint(x: 305, y: 600), baseRight: NSPoint(x: 455, y: 700), tipRadius: 40)

    color(0xF2A7B8).setFill()
    for earPath in [leftEar, mirrored(leftEar)] { earPath.fill() }
    color(0xFBD3DD).setFill()
    for innerPath in [leftInner, mirrored(leftInner)] { innerPath.fill() }

    color(0xF2A7B8).setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - 262, y: center.y - 262, width: 524, height: 524)).fill()

    color(0x262848).setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - 190, y: center.y - 190, width: 380, height: 380)).fill()

    color(0xFFFFFF).setFill()
    for offset in [-68, 68] as [CGFloat] {
        let eyeRect = NSRect(x: center.x + offset - 30, y: center.y - 48, width: 60, height: 96)
        NSBezierPath(roundedRect: eyeRect, xRadius: 16, yRadius: 16).fill()
    }
}

let output = CommandLine.arguments[1]
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
drawIcon()
NSGraphicsContext.restoreGraphicsState()
try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
