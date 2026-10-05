import AppKit
import Foundation
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
func icon(size: Int, at path: String) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let factor = CGFloat(size) / 192
    let transform = NSAffineTransform(); transform.scale(by: factor); transform.concat()
    NSColor(calibratedRed: 0.133, green: 0.369, blue: 0.314, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 192, height: 192)).fill()
    NSColor(calibratedRed: 0.925, green: 0.949, blue: 0.890, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 39, y: 32, width: 114, height: 124), xRadius: 17, yRadius: 17).fill()
    NSColor(calibratedRed: 0.133, green: 0.369, blue: 0.314, alpha: 1).setStroke()
    let check = NSBezierPath(); check.move(to: NSPoint(x: 65, y: 93)); check.line(to: NSPoint(x: 87, y: 71)); check.line(to: NSPoint(x: 130, y: 119)); check.lineWidth = 13; check.lineCapStyle = .round; check.lineJoinStyle = .round; check.stroke()
    NSColor(calibratedRed: 0.667, green: 0.765, blue: 0.604, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 70, y: 145, width: 52, height: 20), xRadius: 8, yRadius: 8).fill()
    NSGraphicsContext.restoreGraphicsState()
    let url = root.appendingPathComponent(path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}
try icon(size: 180, at: "web/apple-touch-icon.png")
try icon(size: 1024, at: "ios/SubmitChecker/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
