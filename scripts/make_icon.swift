// Draws the NailBite "Signal" app icon at 1024 px: an ink tile lit by the alert's vermilion edge glow,
// with a fingertip (white nail) rising from the bottom.
import AppKit

let S: CGFloat = 1024
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let radius: CGFloat = 185
// Run: swift make-icon.swift icon-1024.png, then resize with sips into AppIcon.appiconset.
let out = CommandLine.arguments[1]

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
func hex(_ h: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((h >> 16) & 255) / 255, green: CGFloat((h >> 8) & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: a)
}
let tile = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)

// Drop shadow, as on every macOS icon
NSGraphicsContext.saveGraphicsState()
let sh = NSShadow(); sh.shadowColor = .black.withAlphaComponent(0.32); sh.shadowBlurRadius = 24; sh.shadowOffset = NSSize(width: 0, height: -10)
sh.set(); hex(0x111112).setFill(); tile.fill()
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
tile.addClip()
NSGradient(starting: hex(0x1F1F22), ending: hex(0x0C0C0D))!.draw(in: body, angle: -90)

// Edge glow: same exponential falloff as the alert, measured from the tile's rounded edge.
let w = Int(body.width), h = Int(body.height)
var px = [UInt8](repeating: 0, count: w * h * 4)
let (vr, vg, vb): (Double, Double, Double) = (0.96, 0.27, 0.16)
for y in 0..<h { for x in 0..<w {
    let qx = abs(Double(x) + 0.5 - Double(w) / 2) - (Double(w) / 2 - Double(radius))
    let qy = abs(Double(y) + 0.5 - Double(h) / 2) - (Double(h) / 2 - Double(radius))
    let outside = hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - Double(radius)
    let d = max(0, -outside)
    let a = min(1, 0.95 * exp(-d / 9) + 0.55 * exp(-d / 38) + 0.32 * exp(-d / 120))
    let i = (y * w + x) * 4
    px[i] = UInt8(vr * a * 255); px[i + 1] = UInt8(vg * a * 255); px[i + 2] = UInt8(vb * a * 255); px[i + 3] = UInt8(a * 255)
}}
let glow = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                   provider: CGDataProvider(data: Data(px) as CFData)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
ctx.draw(glow, in: body)

// Fingertip: a finger rising from the bottom edge, its nail in white.
let fw: CGFloat = 340
let finger = NSBezierPath(roundedRect: CGRect(x: S / 2 - fw / 2, y: body.minY - 200, width: fw, height: 200 + 560), xRadius: fw / 2, yRadius: fw / 2)
NSGradient(starting: hex(0x3A3A3F), ending: hex(0x26262A))!.draw(in: finger, angle: -90)
let nw: CGFloat = 232, nh: CGFloat = 270
let nailRect = CGRect(x: S / 2 - nw / 2, y: body.minY + 560 - nh - 34, width: nw, height: nh)
let nail = NSBezierPath()
nail.move(to: CGPoint(x: nailRect.minX, y: nailRect.minY + 48))
nail.line(to: CGPoint(x: nailRect.minX, y: nailRect.maxY - nw / 2))
nail.appendArc(withCenter: CGPoint(x: nailRect.midX, y: nailRect.maxY - nw / 2), radius: nw / 2, startAngle: 180, endAngle: 0, clockwise: true)
nail.line(to: CGPoint(x: nailRect.maxX, y: nailRect.minY + 48))
nail.appendArc(from: CGPoint(x: nailRect.maxX, y: nailRect.minY), to: CGPoint(x: nailRect.maxX - 48, y: nailRect.minY), radius: 48)
nail.line(to: CGPoint(x: nailRect.minX + 48, y: nailRect.minY))
nail.appendArc(from: CGPoint(x: nailRect.minX, y: nailRect.minY), to: CGPoint(x: nailRect.minX, y: nailRect.minY + 48), radius: 48)
nail.close()
NSGradient(starting: hex(0xFFFFFF), ending: hex(0xE4E3DF))!.draw(in: nail, angle: -90)
// Lunula
NSGraphicsContext.saveGraphicsState()
nail.addClip()
hex(0xDEDBD5).setFill()
NSBezierPath(ovalIn: CGRect(x: nailRect.midX - 78, y: nailRect.minY - 52, width: 156, height: 104)).fill()
NSGraphicsContext.restoreGraphicsState()

// Hairline highlight on the tile's top edge
NSGraphicsContext.restoreGraphicsState()
hex(0xFFFFFF, 0.10).setStroke()
let edge = NSBezierPath(roundedRect: body.insetBy(dx: 1, dy: 1), xRadius: radius - 1, yRadius: radius - 1)
edge.lineWidth = 2; edge.stroke()

try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
