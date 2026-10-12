// Renders the Pharos app icon (a radar sweep over a dot grid; dots light up and
// grow as the beam passes) into an .iconset folder; `make icon` turns it into
// Resources/Pharos.icns via iconutil.
// Usage: swift Scripts/make-icon.swift <output.iconset>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let cs = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [
        CGFloat((hex >> 16) & 0xff) / 255, CGFloat((hex >> 8) & 0xff) / 255, CGFloat(hex & 0xff) / 255, a,
    ])!
}

func mix(_ a: UInt32, _ b: UInt32, _ t: CGFloat, alpha: CGFloat) -> CGColor {
    func ch(_ v: UInt32, _ s: UInt32) -> CGFloat { CGFloat((v >> s) & 0xff) / 255 }
    let c = [16, 8, 0].map { ch(a, UInt32($0)) * (1 - t) + ch(b, UInt32($0)) * t }
    return CGColor(colorSpace: cs, components: [c[0], c[1], c[2], alpha])!
}

func radial(_ ctx: CGContext, _ o: CGPoint, _ r: CGFloat, _ hex: UInt32, _ a: CGFloat) {
    let g = CGGradient(colorsSpace: cs, colors: [color(hex, a), color(hex, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(g, startCenter: o, startRadius: 0, endCenter: o, endRadius: r, options: [])
}

/// Deterministic noise so every build produces the same icon.
struct LCG {
    var s: UInt64
    mutating func next() -> CGFloat {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(s >> 33) / CGFloat(1 << 31)
    }
}

/// Draws in a 1024×1024 coordinate space; callers scale the context for smaller sizes.
func drawIcon(_ ctx: CGContext) {
    let amber: UInt32 = 0xFFC46B, gold: UInt32 = 0xC9954A, warmWhite: UInt32 = 0xFFF3DC
    // macOS icon grid: 824pt body inset 100pt, ~185pt corner radius.
    let body = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
                      cornerWidth: 185, cornerHeight: 185, transform: nil)
    let lamp = CGPoint(x: 290, y: 290)
    let deg = CGFloat.pi / 180
    let a0 = 25 * deg, a1 = 65 * deg, spread = a1 - a0, length: CGFloat = 900
    let step: CGFloat = 32

    ctx.saveGState()
    ctx.addPath(body); ctx.clip()
    let bg = CGGradient(colorsSpace: cs, colors: [color(0x101B40), color(0x03050C)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // Faint blue lattice under the dots.
    ctx.setStrokeColor(color(0x3A62B8, 0.10)); ctx.setLineWidth(1)
    for v in stride(from: CGFloat(100), through: 924, by: step) {
        ctx.move(to: CGPoint(x: v, y: 100)); ctx.addLine(to: CGPoint(x: v, y: 924))
        ctx.move(to: CGPoint(x: 100, y: v)); ctx.addLine(to: CGPoint(x: 924, y: v))
    }
    ctx.strokePath()

    // Range rings with small ticks.
    for r in stride(from: CGFloat(170), through: 900, by: 146) {
        ctx.setStrokeColor(color(amber, 0.11)); ctx.setLineWidth(2)
        ctx.addArc(center: lamp, radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: false); ctx.strokePath()
        ctx.setStrokeColor(color(amber, 0.16)); ctx.setLineWidth(2)
        for t in stride(from: CGFloat(0), to: 90, by: 7.5) {
            let a = t * deg
            ctx.move(to: CGPoint(x: lamp.x + cos(a) * (r - 6), y: lamp.y + sin(a) * (r - 6)))
            ctx.addLine(to: CGPoint(x: lamp.x + cos(a) * (r + 6), y: lamp.y + sin(a) * (r + 6)))
        }
        ctx.strokePath()
    }

    // Beam body: brightest at the leading edge, feathering out toward the trailing side.
    let wedge = CGMutablePath()
    wedge.move(to: lamp)
    wedge.addArc(center: lamp, radius: length, startAngle: a0 - 6 * deg, endAngle: a1, clockwise: false)
    wedge.closeSubpath()
    ctx.saveGState()
    ctx.addPath(wedge); ctx.clip()
    let beam = CGGradient(colorsSpace: cs, colors: [color(amber, 0), color(amber, 0.16), color(amber, 0.5)] as CFArray,
                          locations: [0, 0.55, 1])!
    let lead = CGPoint(x: lamp.x + cos(a1 + .pi / 2) * 420, y: lamp.y + sin(a1 + .pi / 2) * 420)
    let trail = CGPoint(x: lamp.x + cos(a0 - .pi / 2) * 160, y: lamp.y + sin(a0 - .pi / 2) * 160)
    ctx.drawLinearGradient(beam, start: trail, end: lead, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    // Dust in the beam.
    var rng = LCG(s: 7)
    for _ in 0..<2600 {
        let a = a0 - 6 * deg + rng.next() * (spread + 6 * deg)
        let d = 40 + rng.next() * 820
        let p = CGPoint(x: lamp.x + cos(a) * d, y: lamp.y + sin(a) * d)
        let t = (a - a0) / spread
        ctx.setFillColor(color(warmWhite, 0.04 + 0.16 * max(0, t) * rng.next()))
        let r = 0.8 + rng.next() * 1.4
        ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
    }
    ctx.restoreGState()

    // Dot grid: dim gold at rest, ignited to warm white and enlarged inside the beam.
    for y in stride(from: CGFloat(116), to: 924, by: step) {
        for x in stride(from: CGFloat(116), to: 924, by: step) {
            let p = CGPoint(x: x, y: y)
            let d = hypot(p.x - lamp.x, p.y - lamp.y)
            guard d > 40 else { continue }
            let a = atan2(p.y - lamp.y, p.x - lamp.x)
            var t = (a - (a0 - 6 * deg)) / (spread + 6 * deg)
            t = (t < 0 || t > 1.02) ? 0 : min(1, t)
            let heat = pow(t, 1.6)
            let r = 2.4 + 5.2 * heat
            if heat > 0.35 {
                radial(ctx, p, r * 4.2, amber, 0.32 * heat)
            }
            ctx.setFillColor(mix(gold, warmWhite, heat, alpha: 0.26 + 0.74 * heat))
            ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        }
    }

    // Leading edge: a wide soft glow under a razor-thin bright line.
    let edgeEnd = CGPoint(x: lamp.x + cos(a1) * length, y: lamp.y + sin(a1) * length)
    for (w, a) in [(CGFloat(26), CGFloat(0.12)), (10, 0.35), (4, 1.0)] {
        ctx.saveGState()
        ctx.move(to: lamp); ctx.addLine(to: edgeEnd)
        ctx.setLineWidth(w); ctx.setLineCap(.round); ctx.replacePathWithStrokedPath(); ctx.clip()
        radial(ctx, lamp, length, w < 5 ? 0xFFFFFF : warmWhite, a)
        ctx.restoreGState()
    }

    // Captured targets (active ports), sitting on range rings.
    for (ring, frac) in [(CGFloat(316), CGFloat(0.62)), (462, 0.86), (608, 0.38)] {
        let a = a0 + spread * frac
        let p = CGPoint(x: lamp.x + cos(a) * ring, y: lamp.y + sin(a) * ring)
        radial(ctx, p, 92, amber, 0.30)
        radial(ctx, p, 40, warmWhite, 0.75)
        ctx.setStrokeColor(color(warmWhite, 0.55)); ctx.setLineWidth(2)
        ctx.strokeEllipse(in: CGRect(x: p.x - 24, y: p.y - 24, width: 48, height: 48))
        ctx.setFillColor(color(0xFFFFFF))
        ctx.fillEllipse(in: CGRect(x: p.x - 11, y: p.y - 11, width: 22, height: 22))
    }

    // Source.
    radial(ctx, lamp, 170, amber, 0.55)
    radial(ctx, lamp, 60, warmWhite, 0.9)
    ctx.setFillColor(color(0xFFFFFF))
    ctx.fillEllipse(in: CGRect(x: lamp.x - 24, y: lamp.y - 24, width: 48, height: 48))

    // Film grain over everything.
    var grain = LCG(s: 42)
    for _ in 0..<9000 {
        let p = CGPoint(x: 100 + grain.next() * 824, y: 100 + grain.next() * 824)
        ctx.setFillColor(color(0xFFFFFF, 0.015 + grain.next() * 0.035))
        ctx.fill(CGRect(x: p.x, y: p.y, width: 1.5, height: 1.5))
    }

    // Subtle top-edge highlight to read as a physical tile.
    ctx.addPath(body)
    ctx.setStrokeColor(color(0xFFFFFF, 0.08)); ctx.setLineWidth(3); ctx.strokePath()
    ctx.restoreGState()
}

func render(pixels: Int, to url: URL) throws {
    guard let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                              space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw NSError(domain: "make-icon", code: 1, userInfo: [NSLocalizedDescriptionKey: "cannot create context"])
    }
    ctx.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon(ctx)
    guard let image = ctx.makeImage(),
          let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "make-icon", code: 2, userInfo: [NSLocalizedDescriptionKey: "cannot write \(url.path)"])
    }
    CGImageDestinationAddImage(dst, image, nil)
    guard CGImageDestinationFinalize(dst) else {
        throw NSError(domain: "make-icon", code: 3, userInfo: [NSLocalizedDescriptionKey: "cannot write \(url.path)"])
    }
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: swift Scripts/make-icon.swift <output.iconset>\n".data(using: .utf8)!)
    exit(2)
}
let out = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
do {
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    for base in [16, 32, 128, 256, 512] {
        try render(pixels: base, to: out.appendingPathComponent("icon_\(base)x\(base).png"))
        try render(pixels: base * 2, to: out.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
    }
} catch {
    FileHandle.standardError.write("make-icon: \(error.localizedDescription)\n".data(using: .utf8)!)
    exit(1)
}
